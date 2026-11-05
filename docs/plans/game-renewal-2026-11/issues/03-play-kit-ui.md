# 03: 공용 연출 부품 (턴 배너·결과 시트·토스트·색종이·리액션 바)

**Type:** client

**Blocked by:** 02

**Status:** ready-for-agent

## What to build

탱크에서 검증한 연출 부품을 **게임 색을 인자로 받는 공용 위젯**으로 만든다. 다섯 게임이 같은 부품을 쓴다.

## Acceptance criteria

- [ ] `game_turn_banner.dart`: 화면을 가로지르는 "내 차례!" 배너(id가 바뀔 때마다 재생, 지난 알림은 건너뜀)
- [ ] `game_result_sheet.dart`: 승/패/무 + 이유 한 줄 + **이번 방 전적** + 재대결 버튼(대기 중 표시) + 나가기. 승리 시 색종이
- [ ] `game_toast.dart`: 조작부를 가리지 않는 짧은 안내
- [ ] `confetti_burst.dart`: 색종이(재사용 가능, 성능 부담 작게)
- [ ] `reaction_bar.dart`: 이모지 6종(😏 😅 😱 🤞 😭 😎) 가로 줄 + 상대가 보낸 말풍선 표시(3초). 서버 연동은 티켓 05
- [ ] 색은 `kMain*` 토큰 + 인자로 받은 포인트 색만 사용(하드코딩 남색 금지)
- [ ] 위젯 테스트: 각 부품이 렌더되고 id 변경 시 재생, 결과 시트가 승/패/무 문구를 올바르게 표시
- [ ] 화면 폭 360~430에서 오버플로 없음

## Notes

탱크의 `TankTurnBanner`/`TankResultOverlay`/`TankToast`를 참고해 새로 작성한다(탱크 쪽은 이번에 건드리지 않는다).

## Likely files

- `apps/secret_base_app/lib/widgets/play_kit/`
- `apps/secret_base_app/test/play_kit_ui_test.dart`
