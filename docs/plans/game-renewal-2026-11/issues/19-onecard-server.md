# 19: 원카드 2.0 서버 (흐름 수정·승리 가드·서버 타이머·재대결)

**Type:** server

**Blocked by:** 04, 18 · 외부: PR #219(시작 실패 핫픽스)

**Status:** ready-for-agent

## What to build

원카드의 규칙 뼈대는 유지하고, 판이 꼬이거나 끝나지 않는 서버 흐름을 고친다. 시간 제한을 서버가 맡고, 재대결이 같은 설정으로 선공만 바꿔 이어지게 한다(00-analysis §6b U2·U4·U5·U6·U10, 01-grilling Q49–Q55).

## Acceptance criteria

- [ ] 모든 `game:uno:*` 핸들러가 `winner`가 있으면 `game_over`로 거부
- [ ] 승리·몰수를 `finishUnoGame(roomCode, state, reason)` 하나로: 끝남 저장 → 정산·기록(try/finally) → 상태 삭제 → `game:uno:ended { winner, reason: 'empty_hand'|'forfeit', hands, series }`
- [ ] +2/+4 벌칙으로 뽑은 뒤에는 차례 종료(뽑은 카드 내기 선택 없음)
- [ ] 모두 버리기 묶음 안의 스킵·리버스는 한 번만 적용
- [ ] +4를 낼 때 `hadColorAtDraw4`를 기록하고 도전은 그 값으로 판정
- [ ] 선공 무작위(첫 판), 재대결마다 교대. `uno:<room>:last`(1시간)에 `{ mode, stake, series, lastStarter }`를 남기고 `game:restart:*` 재시작이 이를 이어받음
- [ ] `turnDeadline`(20초): 상태 변경마다 갱신. 만료 시 서버가 \"한 장 뽑고 넘김\"(쌓인 벌칙이 있으면 받기). 연속 3회 자동 처리면 기권
- [ ] `challenged` 페이로드에 `unoCallNeeded`, `session:restore` 원카드 페이로드에 `players`·`equippedItems`·`turnDeadline`
- [ ] 엔진·소켓 테스트(TDD): 위 항목 각각 + 승리 뒤 내기·뽑기 거부 + 정산 중 예외에도 상태 삭제 + 재대결 모드·판돈 유지·선공 교대
- [ ] 시뮬레이션 테스트: 두 모드 평균 턴 25~55, 덱 고갈 없음
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

웹과 함께 배포하므로 옛 클라이언트 호환 코드는 두지 않는다. 진행 중이던 판은 복원 시 `turnDeadline`이 없으면 지금 시각 기준으로 새로 건다.

## Likely files

- `services/realtime-server/src/uno-engine.js`
- `services/realtime-server/src/socket.js`
- `services/realtime-server/src/game-session.js`
- `services/realtime-server/test/`
