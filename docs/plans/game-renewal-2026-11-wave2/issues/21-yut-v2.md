# 21: 윷놀이 2.0

**Type:** server+client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

윷놀이를 공용 기반 위의 2.0으로 다시 만든다. 규칙 뼈대는 유지하고 아이템 밸런스·버그를 고치며, 서버 시작·30초 턴·서버 이동 후보·한지 마당 테마를 넣는다(00 §1, 01 Q6–Q13, 02 윷놀이).

## Acceptance criteria

- [ ] 엔진 TDD: 빽도에는 "도→모" 미발동 + `sticks`가 결과와 항상 일치, 방어는 한 번(상한 10%)·막히면 한 칸 앞 정지(앞 칸에 상대 말이면 정상 잡기), 던지기 아이템 효과 합산 상한, 코인 보너스 판당 판돈 30% 상한(정산 때만), `legalMoves`·`autoMove`
- [ ] 균형 테스트: 한쪽만 아이템 최대 장착 시 승률 ≤55%(시뮬레이션, 시드 고정), 기존 규칙 테스트 유지
- [ ] 모듈 `src/games/yut.js`: `startFromLobby`(캐릭터·배경음·판돈·`pieces`는 서버 로비 기록, 첫 순서 무작위), 30초 마감 + 자동 던지기/이동, 3회 자동이면 기권, 승자 가드, 정산 try/finally + `recordGameOutcome(gameId)`(지갑 ref `yut:<gameId>` 유지), `yut:<room>:last` 재대결(판돈·캐릭터·배경음·시리즈 유지, 선 교대), 순서 타이머 `timerApi`+gameId, `restore`(끝난 판 제외), `afk`, `dispose`. 옛 socket.js 윷 코드 삭제
- [ ] 로비 옵션 `yut.pieces` 4|3|2(서버 `lobby-options.js` + 앱 `lobby_options.dart`)
- [ ] 소켓 테스트 `test/yut-socket.test.js`: 서버 시작·캐릭터 유지, 마감 자동 행동, 끝난 판 거부, 정산 예외에도 상태 삭제, 재대결 유지·선 교대, 복원
- [ ] 화면(`games/yut/`): 한지 마당 테마(`GameTheme.hanji`), 큰 판(먹선·오방색·모/뒷모/방/찌모/참먹이 표시), 나무 윷가락 던지기 애니메이션(서버 `sticks`대로 착지, 윷·모 슬로모션), 던지기 칩 트레이 → 말 → 단일 목적지 미리보기(서버 `legalMoves`), 빽도 갈림길 화살표, 잡기·업기·골인 연출, `GameSfx` 레시피, 캐릭터 음성 유지, `TurnTimerRing`, `GameResultOverlay`, 리액션, 처음 한 번 규칙 안내. 12px 이상 글자, 사용자 코드 노출 없음, 시작 버튼 없음
- [ ] 위젯 테스트(360·430·데스크톱 넘침 없음, 칩→말→확정, 결과)
- [ ] `docs/socket-events/yut.md`

## Likely files
- `services/realtime-server/src/yut-engine.js`, `src/games/yut.js`, `src/socket.js`, `src/game-session.js`, `src/lobby-options.js`, tests
- `apps/secret_base_app/lib/screens/arcade/games/yut/`, `games/yut_screen.dart`, `lib/screens/arcade/lobby_options.dart`, `lib/core/game_sfx/game_sounds.dart`(레시피 추가), `lib/widgets/play_kit/game_theme.dart`(hanji)
