# 03: 재시작 프로토콜 검증

**What to build:** 상대가 실제로 재시작을 요청했고 내가 수락했을 때만 판이 재시작된다. 위조된 respond는 거부된다. 마블·탱크도 재시작된다.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] request가 restart:{room} 레코드(30초) 저장
- [ ] respond: 레코드 존재·만료·gameType·응답자≠요청자 검증, room lock
- [ ] 지원 게임 yut/uno/bomb/marble/tank, 그 외 unsupported_game
- [ ] 소켓 회귀 테스트(위조 respond 거부, 정상 흐름)
