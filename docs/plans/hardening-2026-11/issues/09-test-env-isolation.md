# 09: 테스트와 운영 환경 분리

**What to build:** 테스트 실행 중에는 .env 자동 로딩을 건너뛰어 운영 서버에서도 테스트가 운영 환경에 오염되지 않는다. 운영 동작은 그대로다.

**Blocked by:** None (can start immediately)

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/211

- [x] NODE_ENV=test에서는 .env를 읽지 않는다
- [x] 운영(NODE_ENV 미설정/production)에서는 기존처럼 .env가 적용된다
- [x] 서버 임시 사본에서 전체 테스트가 통과한다
