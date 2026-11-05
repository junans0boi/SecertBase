# 08: 고스톱 진행 정지·규칙 수정

**What to build:** 폭탄 후에도 판이 끝까지 진행되고, 고 반복으로 배수를 부풀릴 수 없으며, 피 뺏기·초단·4광 규칙과 이벤트 안내가 정상 동작한다.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] 손패 빈 플레이어 턴 건너뛰기
- [ ] lastGoScore 초과일 때만 go_stop_choice
- [ ] 쪽·따닥·판쓸이·뻑회수·폭탄 시 피 1장 뺏기
- [ ] 초단 3점, 4광 이상 비광 감점 없음
- [ ] 다음 턴에도 lastEvents 보존, 바닥 2장 매칭 시 1장만 획득
- [ ] 엔진 테스트
