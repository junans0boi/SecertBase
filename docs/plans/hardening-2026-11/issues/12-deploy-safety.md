# 12: 배포 안전장치와 워크플로 정리

**What to build:** 배포는 마이그레이션 후 웹을 교체하고, 직전 웹 빌드를 보관하며, 헬스체크를 더 오래 기다린다. 서버 배포 워크플로는 동시 실행되지 않고, Pages 빌드는 구글 클라이언트 ID를 받는다.

**Blocked by:** 09

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/213

- [x] 마이그레이션이 웹 rsync보다 먼저 실행된다
- [x] 직전 웹 빌드가 최근 5개까지 보관된다
- [x] 헬스체크가 30회 시도한다
- [x] bash -n 문법 검사를 통과한다
- [x] deploy-to-server에 concurrency가 있다
- [x] Pages 빌드에 GOOGLE_CLIENT_ID가 전달된다
