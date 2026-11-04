# 01: 기능 게이트 대소문자 우회 차단

**What to build:** MVP에서 비활성화된 기능은 경로의 대소문자나 슬래시 변형과 무관하게 항상 FEATURE_DISABLED로 응답한다.

**Blocked by:** None (can start immediately)

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/203

- [x] 대문자·혼합 대소문자 경로가 비활성 기능으로 판정된다
- [x] 기존 소문자 경로 동작은 그대로다
- [x] legacy 기능 세트에서는 모든 경로가 통과한다
