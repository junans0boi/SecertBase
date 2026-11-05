# 08: (보류) 블랙잭 판돈 지원

**Type:** server+client

**Blocked by:** 06, 07

**Status:** needs-decision (D1)

## What to build

블랙잭에 판돈을 붙인다. **승인 때 포함 여부를 정한다(D1).** 기본 추천은 이번 파도에서 제외.

## Acceptance criteria

- [ ] `STAKE_GAME_TYPES`에 `blackjack` 추가, 로비 판돈 선택/준비 완료 절차 적용(`kStakeGameTypes` 클라이언트도)
- [ ] 서버 pending game + 정산을 윷·원카드·탱크와 같은 경로로 처리(멱등, 정산 후 삭제)
- [ ] 무승부는 판돈 반환
- [ ] 소켓 회귀 테스트: 판돈 합의 없는 시작 거부, 정산 한 번, 무승부 반환

## Notes

포함하기로 하면 06·07 이후에 진행한다. 제외하면 이 티켓은 닫는다.

## Likely files

- `services/realtime-server/src/socket.js`
- `apps/secret_base_app/lib/screens/arcade/game_lobby_screen.dart`
