# 37: 패널티킥 로비·결과 디자인

**Type:** client

**Blocked by:** –

**Status:** done (PR #253)

## What to build

경기 화면은 그대로 두고 로비와 최종 결과만 목업(야간 방송 안)으로 바꾼다.

## Acceptance criteria

- [x] 패널티킥 전용 로비(3칸/6칸 선택, 방장만 변경, 상대는 읽기 전용)
- [x] 최종 결과(킥 기록표, 이번 방 전적), 공용 결과 오버레이는 다른 게임용으로 유지
- [x] 경기 화면(피치·선택·애니메이션·HUD) 변경 없음
- [x] 위젯 테스트

## Likely files
- `apps/secret_base_app/lib/screens/arcade/games/penalty/penalty_lobby.dart`, `penalty_result.dart`
