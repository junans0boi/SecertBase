# 04: 서버 권위 판돈과 로비 준비 완료

**What to build:** 판돈은 로비에서 방장이 정하고 비방장이 준비 완료로 동의한 값만 쓰인다. 생성 이벤트 payload의 판돈은 무시된다. 판돈 대상이 아닌 게임에는 판돈 UI가 없다.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] lobby:start가 pending game 저장(gameId·stake·host·players, TTL 120초)
- [ ] yut/uno/tank/gostop new가 pending에서 판돈 소비, 없으면 0
- [ ] game:lobby:ready, stake>0이면 비방장 ready 필수, 판돈 변경 시 초기화
- [ ] Flutter 로비: 대상 게임만 판돈 표시, 비방장 준비 버튼, 방장 시작 버튼 조건
- [ ] 소켓 회귀 테스트(payload 판돈 무시, ready 요구)
