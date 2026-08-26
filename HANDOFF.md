# Handoff — 2026-08-26

## 마블 작전 현재 상태

마블 작전은 2인이 주사위를 굴려 24칸 보드의 도시를 구매하고, 건물을 건설하며, 통행료 경쟁을 벌이는 게임이다.

핵심 흐름:

- 선공 주사위 → 3초 카운트다운 → 턴 주사위
- 말 1개 이동, 출발지 통과 시 급여 지급
- 빈 도시 구매, 내 도시 건설, 상대 도시 통행료 지불 및 도시 인수
- 컬러/라인/관광지 독점, 파산, 제한 라운드 자산 비교로 승부 결정
- 게임 상태는 Redis에 저장되고, 게임 화면을 보고 있는 사용자가 있으면 재접속 시 복구

주요 파일:

```text
apps/secret_base_app/lib/screens/arcade/arcade_screen.dart
apps/secret_base_app/lib/screens/arcade/games/marble_screen.dart
apps/secret_base_app/lib/ui/marble_board.dart
apps/secret_base_app/lib/ui/marble_map_data.dart
services/realtime-server/src/marble-engine.js
services/realtime-server/src/socket.js
services/realtime-server/src/game-session.js
```

검증 명령:

```text
cd services/realtime-server && npm test
cd apps/secret_base_app && flutter analyze
cd apps/secret_base_app && flutter test
```

마블 기능을 수정할 때는 다른 게임 모듈과 이벤트를 변경하지 않는다. 배포된 데이터베이스 마이그레이션 파일도 수정하지 말고, 필요한 경우 새 마이그레이션을 추가한다.
