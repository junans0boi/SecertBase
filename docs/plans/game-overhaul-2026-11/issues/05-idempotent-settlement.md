# 05: gameId 기반 멱등 정산

**What to build:** 윷·원카드 판은 gameId를 갖고, 승리 정산이 정확히 한 번만 일어나며 정산 이후에 상태가 지워진다.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] 생성·재시작 시 gameId 부여
- [ ] 정산 ref = <type>:<gameId>
- [ ] 정산 → 결과 기록 → 키 삭제 순서, 실패 시 wallet:settle_failed
