# 04. 게임 2.0 공용 기반 사용법 (구현자용)

> 기반 브랜치: `feat/games-v2-foundation`. 게임별 구현은 이 문서의 규칙을 따른다.
> 근거: `02-spec.md`, `01-grilling.md`, 티켓 `issues/NN-*.md`.

## 1. 서버: 게임 모듈

게임마다 `services/realtime-server/src/games/<game>.js` 한 파일이 서버 동작 전부를 가진다.
`src/games/index.js`의 `GAME_MODULES`에 이미 import되어 있으니, 파일의 `export default`만 채우면 된다.
(`gameType`이 비어 있으면 등록되지 않는다.)

```js
export default {
  gameType: 'blackjack',          // 소켓 이벤트 접두사(game:blackjack:*)이자 잠수 감시 키
  lobbyType: 'blackjack',         // (선택) 로비 gameType이 다르면. 기본 = gameType
  register(socket, kit) {},       // 연결마다 이벤트 등록. socket.on은 안전망이 감싸 예외 → internal_error
  async startFromLobby(roomCode, kit, ctx) {}, // 로비 시작과 함께 서버가 판을 만든다
  async restart(roomCode, kit, ctx) {},        // 동의된 재대결
  async restore(roomCode, socket, kit) {},     // 재접속 소켓에 상태를 다시 보냄 → true면 복원됨
  afk(kit) { return { key, playersOf, waitingOn, forfeit } }, // game-afk.js 어댑터
  dispose() {},                   // 서버 종료 시 타이머 정리
};
```

- `startFromLobby` ctx: `{ players: [p1, p2], options, gameId, stake, host, lobbyType, startsAt }`.
  `players`는 커플 순서(User1, User2). **선공은 반드시 무작위**(`Math.random` 주입 가능하게).
  `startsAt`은 로비 카운트다운이 끝나는 시각(ms). 첫 턴 마감시각은 `startsAt + 턴 시간`으로 잡는다.
  `options`는 로비 옵션(`src/lobby-options.js`, 서버 검증 완료). 클라이언트 payload 값은 믿지 않는다.
- `restart` ctx: `{ p1, p2, orderedPlayers, requestedBy }`. 끝난 판 설정(모드·옵션·판돈)과 `series`를 잇고 선공을 바꾼다.
  끝난 판을 Redis에서 지웠다면 `<type>:<room>:last` 같은 키에 요약을 남겨 둔다.
- `kit`: `io, redis, timerApi, withRoomLock, normalizeAck, getPresence(room), getOrderedPlayers(room, presence),
  consumePendingGame, recordGameOutcome, presenceProfiles(room), presenceNicknames(room), series, randomUUID`.
  - 상태를 바꾸는 핸들러는 전부 `kit.withRoomLock(roomCode, ...)` 안에서.
  - 결과 저장: `kit.recordGameOutcome(roomCode, { winner|'draw', players, gameType, gameId })` — `gameId`로 멱등.
  - 전적: `const series = await kit.series.record(roomCode, gameType, players, winnerOrNull)` → 결과 이벤트에 `series` 포함.
    판 진행 중에는 `kit.series.get(roomCode, gameType, players)`.
  - 타이머: `kit.timerApi.setTimeout/clearTimeout`(테스트가 시계를 돌린다). 핸들은 모듈 안 Map에 두고 `dispose`에서 정리.
- **마감시각**: 상태에 `turnDeadline`(epoch ms)과 함께 **`serverNow: Date.now()`**를 실어 보낸다. 클라이언트 `GameDeadline.fromServer`가 기기 시계 차이를 보정한다.
- **잠수**: `afk(kit)`의 `waitingOn(state)`가 기다리는 사람을 돌려주면 60초 경고·90초 기권. 자체 턴 타이머(20~30초 자동 행동)가 있으면 그게 먼저 동작한다. 연속 자동 행동 3회면 기권 처리.
- **옛 코드 정리**: 자기 게임의 옛 코드를 `socket.js`에서 지운다 — `socket.on("game:<type>:...")` 핸들러, `afkAdapters`의 해당 항목, `session:restore`의 해당 복원 블록, 재시작 분기, 그 게임만 쓰는 스키마·헬퍼·import. **다른 게임 코드는 건드리지 않는다.**
- 엔진은 `src/<game>-engine.js`(순수 함수, `random` 주입)로 두고 TDD.

## 2. 서버 테스트

- 엔진: `test/<game>-engine.test.js`.
- 소켓: 새 파일 `test/<game>-socket.test.js`에서 `import { fixture, flush, boundary } from './support/socket-harness.js'`.
  `fixture(t)`가 실제 socket.js + 메모리 Redis/DB로 두 클라이언트(`ALPHA-code`, `BETA-code`)를 붙여 준다.
  `f.call(index, event, payload)` → ack. 로비 흐름: `game:lobby:join`(둘 다) → `game:lobby:set_option` → `game:lobby:start`.
  시계: `t.mock.timers.enable({ apis: ['Date'], now })` + `f.tick(ms)`.
- `test/socket-game-regression.test.js`의 자기 게임 옛 테스트가 새 규칙과 안 맞으면 고치거나 새 파일로 옮긴다.
- 실행: `cd services/realtime-server && node --test`(이 머신의 node: `/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node`).

## 3. 클라이언트: 컨트롤러 + 화면

- 폴더: `apps/secret_base_app/lib/screens/arcade/games/<game>/`.
  - `<game>_controller.dart`: `GameController`(`games/game_controller.dart`) 상속 싱글톤.
    생성자에서 `on('game:<type>:state', (data) {...})`로 받고, 조작은 `emit('game:<type>:act', {...})`.
    `reset()`에서 상태를 비운다. 화면은 `ListenableBuilder(listenable: XController.instance, ...)`.
  - 화면 위젯들(테이블, 손패, 연출 등)을 파일 몇 개로 나눈다.
- **진입점 유지**: 기존 `games/<game>_screen.dart`의 클래스 이름(`BlackjackScreen` 등)을 그대로 두고 새 화면을 감싸거나 내보낸다. `arcade_screen.dart`·`game_lobby_screen.dart`는 건드리지 않는다(설명 문구는 통합 때 한꺼번에 바꾼다).
- **SocketService(`core/socket_service.dart`)는 수정하지 않는다.** 옛 필드·핸들러는 통합 때 정리한다. 필요한 공용 값: `userId`, `partnerId`, `nameOf(id)`, `profileEmojis`, `presenceNicknames`, `restartWaiting`, `requestRestart(type)`, `lastReaction`, `sendReaction`.
- 시작: 서버가 로비 시작 때 판을 만든다(`metadata.serverStart`). **게임 화면에 "시작" 버튼을 두지 않는다.** 화면이 열리면 컨트롤러가 `game:<type>:sync`를 보내 현재 상태를 받는다(서버 모듈이 `register`에서 처리). 상태가 아직 없으면 "판을 준비하는 중" 표시.
- 재대결: `SocketService().requestRestart(gameType)`만 쓴다(상대에게 수락 창이 뜨는 건 `GameMenuListener`가 처리). 결과 화면의 버튼도 이것.
- 화면 뼈대:
  ```dart
  Scaffold(
    backgroundColor: theme.backdrop.last,
    body: GameMenuListener(        // 재대결 수락 창·상대 나감·게임별 안내
      gameType: 'blackjack',
      child: GameBackdrop(theme: theme, child: SafeArea(child: Stack(children: [...]))),
    ),
  )
  ```

## 4. 공용 부품 (`lib/widgets/play_kit/play_kit.dart`)

| 부품 | 쓰임 |
|---|---|
| `GameTheme.lounge / storybook / showtime / pirateNight / sunsetStadium / salon` | 블랙잭 / 도둑잡기 / 제로 / 해적 / 패널티킥 / 원카드 테마. 색·서체는 여기서만 가져온다 |
| `GameBackdrop` | 테마 배경(질감·조명·비네트) |
| `GameTopBar` | 뒤로·제목·도움말·소리·메뉴(재대결 요청) |
| `PlayerBadge` | 프로필 이모지 아바타 + 이름 + 보조 문구 + 차례 빛 |
| `TurnTimerRing` + `GameDeadline.fromServer` | 서버 마감시각 링(마지막 5초 틱) |
| `GamePrimaryButton` / `GameSecondaryButton` / `GameChip` / `GamePanel` | 버튼·칩·패널 |
| `GameTurnBanner` | id가 바뀔 때 가로지르는 배너("내 차례!") |
| `GameToast` | 위쪽 짧은 안내 |
| `ConfettiBurst` | 색종이 |
| `ReactionButton` / `ReactionBubble` | 공용 이모지 리액션(서버 `game:reaction`) |
| `GameResultOverlay` + `GameOutcome` | 승/패/무 + 이유 + 이번 방 전적 + 한 판 더 |
| `showGameHowTo` / `showHowToOnce` | 규칙 요약(처음 한 번) |
| `PlayingCard` / `PlayingCard.fromMap` / `SuitIcon` / `CardBackStyle` | 벡터 트럼프 카드 |

효과음: `GameSfx.instance.init([...쓰는 소리])`를 화면 `initState`에서, `GameSfx.instance.play(GameSound.x)`로 재생. 목록은 `core/game_sfx/game_sounds.dart`(공통·카드·해적·축구·제로·원카드). 필요한 소리가 없으면 그 파일에 레시피를 추가해도 된다(다른 게임 레시피는 건드리지 말 것).

## 5. 품질 기준

- 탱크 대작전 2.0 이상의 완성도: 테마 배경, 금박·조명, 카드/공/칼의 실제 움직임(AnimationController), 상태 변화마다 소리, 결과 연출.
- 폭 360~430에서 넘침 없음, 터치 영역 44px 이상, 의미 있는 `Semantics` 라벨.
- 사용자 코드(`JHMWP3` 같은 값)를 화면에 그대로 쓰지 않는다 — `nameOf`.
- UI 문구는 한국어, 영어·상표풍 글자 금지(UNO, WILD, SKIP 등).
- `dart format`, `flutter analyze`(이슈 0), `flutter test`, `node --test` 통과.
- Flutter: `/Volumes/WorkSpace/flutter_sdk/flutter/bin`. lint는 flutter_lints 6(`curly_braces_in_flow_control_structures`, `unnecessary_const` 주의). int 상수를 double 인자에 넘기면 웹 빌드가 깨질 수 있다(`.toDouble()`).
- 소켓 계약은 `docs/socket-events/<game>.md` 새 파일에 적는다(공용 `docs/SOCKET_EVENTS.md`는 통합 때 링크).
