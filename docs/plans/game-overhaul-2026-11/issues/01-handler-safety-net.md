# 01: 서버 핸들러 예외 안전망

**What to build:** 어떤 소켓 핸들러에서 예외(DB 오류 포함)가 나도 프로세스가 죽지 않고, 요청자는 ack `internal_error`를 받는다. 프로세스 수준 rejection/exception은 로그로 남는다.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] 연결마다 socket.on을 감싸 async 예외를 포착하고 ack가 있으면 `{ok:false, reason:'internal_error'}`
- [ ] index.js에 unhandledRejection / uncaughtException 로깅
- [ ] 회귀 테스트: 예외를 던지는 핸들러가 ack internal_error를 받는다
