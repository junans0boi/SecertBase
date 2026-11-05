# 09: 도둑잡기 서버 (drawn 이벤트·더미·기록)

**Type:** server

**Blocked by:** 04

**Status:** ready-for-agent

## What to build

뽑기 직후 **무슨 카드였는지 알리는 전용 이벤트**와 버린 짝 더미·최근 기록을 서버가 제공한다.

## Acceptance criteria

- [ ] 상태에 `gameId`, `series`, `discards[]`(버려진 짝의 랭크, 공개), `log[]`(최근 6개 `{by, paired, rank|null, at}`; 짝이 아닐 때 랭크는 `null`) 추가
- [ ] 뽑기 처리 후 `game:oldmaid:drawn`을 사용자별로 따로 emit: `{ by, slot, card, paired, pairedRank, jokerMoved, handSize }`. `card`는 항상 그 사용자가 이미 아는 카드(뽑은 사람은 뽑은 카드, 뺏긴 사람은 뺏긴 자기 카드). 상대 손패의 실제 id는 보내지 않는다
- [ ] 서버의 손패 섞기·`slot-N` 별칭은 유지
- [ ] 결과 저장은 `gameId`와 함께 `recordGameOutcome`
- [ ] 복원(`session:restore`)이 `discards`·`log`를 포함해 상태를 보냄
- [ ] 엔진/소켓 테스트: `drawn`이 사용자별로 맞는 카드를 담음, 상대 실제 id 미포함, 짝 판정과 `jokerMoved`, 마지막 조커 판정, `discards` 누적
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

규칙(27/26장 분배, 짝 제거, 조커)은 바꾸지 않는다.

## Likely files

- `services/realtime-server/src/oldmaid-engine.js`
- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/oldmaid-engine.test.js`
