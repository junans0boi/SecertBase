# 11: 패널티킥 2.0 엔진·소켓

**Type:** server

**Blocked by:** 04

**Status:** ready-for-agent

## What to build

패널티킥을 **3방향(선방 33%)** 으로 바꾸고 선공 무작위·20초 타이머를 넣는다.

## Acceptance criteria

- [ ] `DIRECTIONS = 3`(0 왼쪽, 1 가운데, 2 오른쪽), 같으면 선방. 5킥씩 + 서든데스 최대 5쌍 유지
- [ ] `initPenaltyGame(p1, p2, { random })`: 첫 킥커 무작위, `gameId`, `series`, `turnDeadline`(20초)
- [ ] 서버 타이머: 만료 시 아직 안 낸 사람의 선택을 무작위로 채워 라운드 판정. 연속 3회면 AFK가 기권 처리
- [ ] 소켓 선택 검증 `0~2`(기존 `0~8` 제거). 옛 형식 상태(범위 밖 값 포함)는 복원 시 정리
- [ ] 공개 정보: `rounds`(지난 킥 방향·결과)는 공개, 진행 중 `submissions`는 "냈는지"만(현행 유지)
- [ ] 엔진 테스트(TDD): 3방향 판정, 서든데스, 선공 무작위(주입), 타이머 자동 선택. **균형 테스트**: 무작위 시뮬레이션에서 선방률 30~36%, 최종 무승부 < 3%
- [ ] 소켓 회귀: 제출·판정·타이머·재시작·복원
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

웹과 서버를 함께 배포하므로 호환 코드를 두지 않는다.

## Likely files

- `services/realtime-server/src/penalty-engine.js`
- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/`
