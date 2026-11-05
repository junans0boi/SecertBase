# 18: 로비 옵션 (방장 선택 → 서버 저장 → 게임 생성에 사용)

**Type:** server+client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

게임별 설정을 **방장이 로비에서 고르고 상대도 실시간으로 보는** 공용 장치. 서버가 로비에 저장했다가 게임을 만들 때 그 값을 쓴다(판돈과 같은 방식, 생성 payload 값은 무시). 게임 화면 안의 시작 화면·설정 화면을 없애기 위한 기반이다.

## Acceptance criteria

- [ ] 서버: `game:lobby:set_option { gameType, key, value }`(방장만). 허용 목록 `LOBBY_OPTIONS` — `penalty.cells ∈ {3, 6}`(기본 3), `pirate.holes ∈ {6, 8, 12}`(기본 8), `uno.mode ∈ {go_wild, classic}`(기본 go_wild). 그 외는 `invalid_option`
- [ ] 로비 상태(`game:lobby:updated`·join ack)에 `options` 포함. 옵션을 바꾸면 상대의 ready를 초기화(판돈과 같음)
- [ ] `game:lobby:start`가 pending 게임 기록에 `options`를 저장하고 `consumePendingGame`이 돌려준다. 각 게임 생성 핸들러는 이 값만 쓴다
- [ ] 클라이언트: `GameLobbyScreen`에 옵션 카드 영역. 방장은 선택 가능, 상대는 읽기 전용 + \"방장이 고른 설정\" 표시. 게임별 라벨·설명은 한 곳(`lobby_options.dart`)에 정의
- [ ] 원카드: 지금 방장 기기에만 있던 `selectedUnoMode`를 로비 옵션으로 옮긴다(상대도 모드를 봄)
- [ ] 소켓 회귀: 방장 아닌 사람의 변경 거부, 잘못된 값 거부, 옵션 변경 시 ready 초기화, 생성 payload 무시
- [ ] 위젯 테스트: 방장/비방장 화면, 폭 360에서 오버플로 없음
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

사용자 요구 \"패널티킥 3칸/6칸 방장이 골라서 시작\"에서 출발했고, 해적 구멍 수와 원카드 모드도 같은 장치로 옮긴다. 다음 파도(윷 캐릭터, 마블 등)도 이 장치를 쓴다.

## Likely files

- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/socket-game-regression.test.js`
- `apps/secret_base_app/lib/screens/arcade/game_lobby_screen.dart`
- `apps/secret_base_app/lib/screens/arcade/lobby_options.dart`
- `apps/secret_base_app/lib/core/socket_service.dart`
