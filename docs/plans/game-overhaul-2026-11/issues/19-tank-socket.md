# 19: 탱크 2.0 소켓 계층

**What to build:** 소켓 계층이 select/fire(조준 포함)/move를 처리하고, 보는 사람별로 마스킹해 브로드캐스트하며, 서버 턴 타이머·정산(멱등)·재대결·복원을 지원한다.

**Blocked by:** 02, 03, 04, 05, 18

**Status:** ready-for-agent

- [ ] game:tank:select, fire {angle,power,weapon}, aim 본인 응답
- [ ] 마스킹 브로드캐스트
- [ ] 턴 타이머 예약/취소/복원, game:tank:timeout
- [ ] 종료: 정산 → 기록 → 삭제, ended {winner,reason,stats,series}
- [ ] 재대결(재시작 흐름), 복원 재전송
- [ ] 소켓 회귀 테스트
