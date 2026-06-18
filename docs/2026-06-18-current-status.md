# 2026-06-18 현재 상황 스냅샷

작성일: 2026-06-18  
기준 프로젝트: Secret Base  
목적: 게임 로직 수정 시작 전 현재 상태와 작업 원칙을 고정 기록한다.

## 작업 원칙

1. 현재 구현된 게임의 전체 흐름과 룰은 임의로 수정하지 않는다.
2. 사용자가 요청한 범위만 최소 단위로 수정한다.
3. 게임 흐름, 서버 이벤트 계약, 룰 해석에 애매한 부분이 있으면 혼자 판단하지 않고 먼저 질문한다.
4. 공통 구조를 추가하더라도 각 게임의 기존 로직은 가능한 한 그대로 감싼다.
5. 게임 파일 수정 전에는 어떤 게임/이벤트/상태를 건드리는지 확인하고 진행한다.

## 현재 앱 구조

### Flutter 앱

- 루트: `apps/secret_base_app`
- 진입점: `lib/main.dart`
- 공통 테마: `lib/core/app_theme.dart`
- 메인 디자인 전용 토큰: `lib/core/main_design.dart`
- Socket.IO 클라이언트 상태 관리: `lib/core/socket_service.dart`
- 메인 탭 셸: `lib/screens/home_shell.dart`
- 접속 화면: `lib/screens/entry_screen.dart`
- 아케이드 게임 선택 화면: `lib/screens/arcade/arcade_screen.dart`
- 아카이브 화면: `lib/screens/archive/archive_screen.dart`
- 설정 화면: `lib/screens/settings/settings_screen.dart`

### 게임 화면

- 주사위: `lib/screens/arcade/games/dice_screen.dart`
- 룰렛: `lib/screens/arcade/games/roulette_screen.dart`
- 가위바위보: `lib/screens/arcade/games/rps_screen.dart`
- 텔레파시: `lib/screens/arcade/games/telepathy_screen.dart`
- 해적 룰렛: `lib/screens/arcade/games/pirate_screen.dart`
- 윷놀이: `lib/screens/arcade/games/yut_screen.dart`
- UNO: `lib/screens/arcade/games/uno_screen.dart`
- 폭탄 돌리기: `lib/screens/arcade/games/bomb_screen.dart`

### 게임 공통 위젯

- 게임 화면 프레임: `lib/widgets/game_scaffold.dart`
- 게임 메뉴/재시작/상대 이탈 다이얼로그: `lib/widgets/game_menu.dart`

### 게임 UI 보드

- 윷놀이 보드: `lib/ui/yut_board.dart`
- UNO 보드: `lib/ui/uno_board.dart`
- 폭탄 보드: `lib/ui/bomb_board.dart`

## 현재 서버 구조

루트: `services/realtime-server`

- 서버 진입점: `src/index.js`
- Socket.IO 이벤트 핸들러: `src/socket.js`
- 설정: `src/config.js`
- Redis 연결: `src/redis.js`
- REST API: `src/routes.js`
- PostgreSQL 연결: `src/db.js`
- 윷놀이 엔진: `src/yut-engine.js`
- UNO 엔진: `src/uno-engine.js`
- 폭탄 돌리기 엔진: `src/bomb-engine.js`

## 현재 공통 흐름

1. 사용자는 `EntryScreen`에서 서버 주소, 방 코드, 비밀번호, 사용자 값을 입력한다.
2. `SocketService.connect()`가 `session:join` 이벤트를 보낸다.
3. 서버는 `roomCode`, `roomSecret`, 허용 사용자, 2인 제한을 검증한다.
4. 접속 성공 시 `HomeShell`로 전환된다.
5. 아케이드 탭에서 게임 카드를 누르면 현재는 별도 대기방 없이 바로 해당 게임 화면으로 이동한다.
6. 게임 시작 또는 액션은 각 게임 화면에서 직접 Socket 이벤트를 보낸다.

## 현재 대기방 상태

현재 별도 게임별 대기방은 없다.

- 아케이드 게임 카드 터치 시 즉시 게임 화면으로 진입한다.
- 먼저 들어온 사람을 게임별 방장으로 기록하는 구조가 아직 없다.
- 방장 전용 게임 시작 버튼 구조가 아직 없다.
- 상대방 입장 여부에 따른 게임 시작 버튼 활성/비활성 구조가 아직 없다.

## 현재 게임별 상태

### 주사위

현재 상태:

- 이벤트: `game:dice:roll`
- 서버는 요청 즉시 1-6 랜덤 값을 생성한다.
- 결과는 `game:dice:result`로 방 전체에 브로드캐스트된다.
- 현재는 단발성 주사위 굴리기이며 2인 턴제 매치 상태가 없다.

요청된 변경 방향:

- 대기방에서 방장이 시작한다.
- 주사위 2개를 사용한다.
- 선공/후공은 랜덤으로 정한다.
- 한 명씩 주사위를 굴린다.
- 각자 3턴씩 굴린 합산 점수가 낮은 사람이 패배한다.
- 내 턴이 아닐 때도 상대방이 굴리는 주사위가 보여야 한다.

### 해적 룰렛

현재 상태:

- 이벤트: `game:pirate:spin`
- 서버는 슬롯 수를 받아 한 번에 벌칙 슬롯을 랜덤 산출한다.
- 결과는 `game:pirate:result`로 전달된다.
- 현재는 실제 해적 룰렛처럼 서로 번갈아 숫자를 선택하는 턴제 구조가 아니다.
- 현재 화면에는 누구 차례인지 강조하는 상단 프로필 영역이 없다.

요청된 변경 방향:

- 방장이 개수를 정한다.
- 최대 슬롯 수는 12개다.
- 서로 한 번씩 번갈아 숫자를 선택한다.
- 벌칙 숫자를 고르면 해적이 튀어나오고 해당 플레이어가 패배한다.
- 상단 프로필 이미지 영역으로 현재 차례 플레이어를 강조한다.

### 윷놀이

현재 상태:

- 이벤트: `game:yut:new`, `game:yut:roll_start`, `game:yut:throw`, `game:yut:move`
- 서버에 `roll_order` 단계와 `startRolls` 상태가 있다.
- 각 플레이어가 시작 순서 결정을 위해 주사위를 굴리는 구조가 있다.
- 두 명이 모두 굴린 뒤 실제 게임 턴이 정해지지만, 숫자 비교 결과를 충분히 보여주고 3초 중앙 카운트다운 후 게임에 진입하는 연출은 아직 없다.

요청된 변경 방향:

- 방장이 게임을 시작한다.
- 선공/후공 결정을 위한 주사위 결과를 둘 다 보여준다.
- 누가 더 높은 숫자로 선공인지 명확히 보여준다.
- 결과 확인 후 화면 가운데 3초 카운트다운을 표시한다.
- 카운트다운 후 실제 윷놀이 게임 화면/상태로 진입한다.

### UNO

현재 상태:

- 이벤트: `game:uno:new`, `game:uno:play`, `game:uno:draw`, `game:uno:call`, `game:uno:catch`
- 서버는 게임 생성 시 7장 손패를 즉시 생성한다.
- 각 클라이언트는 `game:uno:hand_update`로 자기 손패 전체를 한 번에 받는다.
- 현재 화면은 게임 시작 후 카드가 이미 모두 보이는 상태로 시작한다.
- 시작 전 3초 중앙 카운트다운 연출은 아직 없다.
- 딜러가 카드를 한 장씩 빠르게 나눠주는 연출은 아직 없다.

요청된 변경 방향:

- 방장이 게임 시작을 누르면 UNO 게임 화면이 열린다.
- 화면 가운데 3초 카운트다운 후 게임이 시작된다.
- 실제 데이터는 이미 준비되어 있어도, UI에서는 딜러가 카드를 한 장씩 빠르게 부여하는 것처럼 보여준다.

### 룰렛

현재 상태:

- 이벤트: `game:roulette:spin`
- 옵션 목록 중 하나를 랜덤 선택한다.
- 이번 요청에서 구체 변경 사항은 아직 없다.

### 가위바위보

현재 상태:

- 이벤트: `game:rps:select`
- 두 명이 선택하면 결과를 판정한다.
- 이번 요청에서 구체 변경 사항은 아직 없다.

### 텔레파시

현재 상태:

- 이벤트: `game:telepathy:select`
- 두 명이 선택하면 일치 여부를 판정한다.
- 이번 요청에서 구체 변경 사항은 아직 없다.

### 폭탄 돌리기

현재 상태:

- 이벤트: `game:bomb:new`, `game:bomb:answer`
- 타이머, 문제, 정답 판정, 패스, 폭발 처리 구조가 있다.
- 이번 요청에서 구체 변경 사항은 아직 없다.

## 요청된 공통 변경 사항

아케이드 탭에서 게임을 들어가면 게임별 대기방이 먼저 보여야 한다.

대기방 기본 요구:

```text
      (방장 왕관 아이콘)
 [프로필 이미지]   [프로필 이미지]
    [닉네임]          [닉네임]

              [게임 시작]
```

세부 요구:

- 먼저 대기방에 들어온 사람이 방장이 된다.
- 방장에게만 게임 시작 버튼이 보인다.
- 상대방이 들어오기 전에는 게임 시작 버튼이 비활성화된다.
- 상대방이 들어오면 방장의 게임 시작 버튼이 활성화된다.
- 방장이 게임 시작을 누르면 각 게임별 시작 흐름으로 넘어간다.

## 설계상 확인이 필요한 지점

다음 항목은 구현 전에 사용자 확인이 필요하다.

1. 대기방 방장은 “각 게임 대기방에 먼저 들어온 사람” 기준이다.
2. 대기방은 모든 아케이드 게임에 공통으로 붙인다.
3. 프로필 이미지는 설정 탭에서 고를 수 있게 한다.
4. 프로필 이미지는 기본값을 제공한다.
5. 닉네임 표시가 현재 `jun`, `gf` 그대로인지, 별도 표시명 매핑이 필요한지 확인 필요.

## 현재 검증 기준

- `flutter test` 통과 기록 있음.
- 수정 파일 대상 `dart analyze` 통과 기록 있음.
- 전체 `flutter analyze --no-fatal-infos`는 통과 가능.
- 전체 `flutter analyze`에는 기존 게임 파일의 `withOpacity` deprecation info가 남아 있다.

## 다음 작업 후보

권장 순서:

1. 공통 게임 대기방 구조 추가
2. 방장/참가자 상태 이벤트 설계
3. 윷놀이 시작 순서 결과 + 3초 카운트다운
4. UNO 시작 카운트다운 + 딜링 연출
5. 해적 룰렛 턴제 선택 구조
6. 주사위 2인 3턴 매치 구조

단, 실제 진행 순서는 사용자 지시에 따른다.

## 2026-06-18 추가 구현 기록

사용자 확인 사항 반영:

- 방장은 각 게임 대기방에 먼저 들어온 사람 기준으로 결정한다.
- 모든 아케이드 게임에 공통 대기방을 적용한다.
- 프로필 이미지는 설정 탭에서 선택한다.
- 프로필 이미지는 기본값을 제공한다.

구현 내용:

- 서버 Socket.IO에 `game:lobby:join`, `game:lobby:leave`, `game:lobby:start` 이벤트를 추가했다.
- 서버가 게임별 대기방 상태를 Redis에 저장한다.
- 대기방 입장 순서에 따라 `host`를 정한다.
- 방장이 나가면 남아 있는 첫 번째 플레이어가 새 방장이 된다.
- 대기방에 2명이 있어야 `game:lobby:start`가 성공한다.
- `room:presence`에 `profileEmojis`를 포함하도록 확장했다.
- 설정 탭에서 `profile:update`로 프로필 이모지를 동기화하도록 추가했다.
- Flutter에 공통 `GameLobbyScreen`을 추가했다.
- 아케이드의 모든 게임 카드가 직접 게임 화면이 아닌 대기방으로 이동하도록 바꿨다.
- 방장에게만 `게임 시작` 버튼이 보인다.
- 상대방이 없으면 방장 버튼이 비활성화된다.
- 상대방이 들어오면 방장 버튼이 활성화된다.
- 방장이 시작하면 대기방에 있는 두 사용자가 같은 게임 화면으로 전환된다.
- 설정 탭에서 프로필 이모지를 고르고 로컬 저장소에 저장한다.

아직 의도적으로 미수정한 항목:

- 윷놀이 선공 결과 3초 카운트다운
- UNO 시작 3초 카운트다운
- UNO 카드 딜링 연출
- 해적 룰렛 턴제 선택 구조
- 주사위 2인 3턴 매치 구조

검증:

- Flutter 수정 파일 대상 `dart analyze` 통과
- `flutter test` 통과
- 서버 `npm test` 통과
- 서버 `src/socket.js` 문법 확인 통과
- 서버 Socket 모듈 import 확인 통과

## 2026-06-18 윷놀이 시작 흐름 수정 기록

사용자 요청:

- 방장이 게임을 시작하면 주사위를 굴려 선공/후공을 정한다.
- 두 명이 모두 주사위를 굴리면 누가 더 높은 숫자로 선공인지 보여준다.
- 결과 표시 후 화면 가운데 3초 카운트다운을 보여준다.
- 카운트다운 후 실제 윷놀이 게임으로 진입한다.

구현 내용:

- 윷놀이 서버 상태에 `orderCountdownUntil`을 추가했다.
- 두 플레이어의 선공 주사위가 모두 나온 뒤 동점이 아니면 `phase`를 `order_countdown`으로 전환한다.
- `order_countdown` 단계에서 `currentTurn`은 선공 플레이어로 설정한다.
- 서버가 3초 후 같은 게임 상태를 `throwing` 단계로 바꾸고 방 전체에 갱신 이벤트를 보낸다.
- Flutter `SocketService`가 `orderCountdownUntil`을 수신하도록 추가했다.
- 윷놀이 화면에서 방장이 대기방 시작 후 자동으로 `game:yut:new`을 호출하도록 연결했다.
- `YutBoard`에 선공 결과 화면을 추가했다.
- 선공 플레이어 주사위 영역을 강조하고 중앙에 3초 카운트다운을 표시한다.
- 카운트다운이 끝나면 기존 윷놀이 보드와 턴 진행 화면으로 넘어간다.

검증:

- 윷놀이 관련 Flutter 파일 대상 `dart analyze` 통과
- `flutter test` 통과
- `flutter build web --no-wasm-dry-run` 통과
- 서버 `node --check src/socket.js` 통과
- 서버 `npm test` 통과
- 로컬 백엔드 재시작 완료
