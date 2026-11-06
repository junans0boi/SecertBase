# 34: 텔레파시·재대결 버그 3종

**Type:** server+client

**Blocked by:** –

**Status:** done (PR #253)

## What to build

실제 플레이에서 찾은 문제 3가지를 고친다.

## Acceptance criteria

- [x] 첫 문제에 25초를 더 줘 규칙을 읽는 동안 시간 초과가 나지 않게 한다(`turnDeadline`·`turnMs`에 포함)
- [x] 두 사람이 동시에 "한 판 더"를 누르면 상호 동의로 보고 새 판을 시작(`game:restart:started`), 열려 있던 수락 창은 새 판이 시작되면 닫는다(공용 재대결 코드)
- [x] `Semantics(button)`에 `onTap`이 없어 접근성 환경에서 탭이 먹지 않던 버튼 3곳 수정
- [x] 놀이 목록의 게임 설명 문구를 현재 게임에 맞게 수정

## Likely files
- `services/realtime-server/src/socket.js`(공용 재대결), `src/games/telepathy.js`
- `apps/secret_base_app/lib/core/socket_service.dart`, `lib/screens/arcade/games/telepathy/`
