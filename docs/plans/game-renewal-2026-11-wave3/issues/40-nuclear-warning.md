# 40: 핵폭탄 매운맛 경고문 강화

**Type:** client

**Blocked by:** –

**Status:** in-progress (PR #254 — 병합 대기)

## What to build

핵폭탄 매운맛(19+)을 고르면 "진짜 어마어마하게 매운맛이라 각오하고 해야 한다"는 큰 경고가 로비에 먼저 보이게 한다.

## Acceptance criteria

- [x] 경고 상자 맨 위 큰 글씨: "⚠️ 각오하고 시작하세요!" + "진짜 어마어마하게 매운맛이에요. 얼굴이 화끈거려도 책임 못 져요."
- [x] 기존 "🔞 19+ 성인 전용" 안내와 상대 동의 절차 유지, 19+에서만 표시(위젯 테스트)
- [ ] #254 병합·배포

## Likely files
- `apps/secret_base_app/lib/screens/arcade/games/telepathy/telepathy_lobby.dart`, `test/telepathy_lobby_test.dart`
