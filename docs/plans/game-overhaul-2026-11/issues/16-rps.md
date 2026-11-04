# 16: 가위바위보 끊김·리셋·기록

**What to build:** 잠깐 끊겨도 판이 부당하게 취소되지 않고, 취소되면 화면이 대기에서 풀리며, 누구나 리셋할 수 있고, 승패가 기록된다.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] disconnect: 사용자의 남은 소켓 없고 판 있을 때만 취소
- [ ] Flutter game:rps:cancelled 리스너
- [ ] reset 참가자 누구나, 클라이언트 방장 조건 제거
- [ ] 결과·XP 기록
