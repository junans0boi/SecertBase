# 13: 해적 룰렛 서버 (선공·짝수·벌칙·정산)

**Type:** server

**Blocked by:** 04

**Status:** ready-for-agent

## What to build

선공을 무작위로 하고 구멍을 짝수 프리셋으로 제한하며, 폭발 뒤 **벌칙 단계**를 서버가 중계하고 결과를 안정적으로 저장한다.

## Acceptance criteria

- [ ] `start { slots: 6|8|10|12 }`(스키마 제한), 누구든 시작, 선공 `random`(주입 가능)
- [ ] 상태: `gameId, slots, bombSlot, pickedSlots, players, currentTurn, phase('playing'|'exploded'), series, penalty{text,by,doneAt}`
- [ ] `pick`: 폭탄이면 상태를 **삭제하지 않고** `phase: 'exploded'`로 보존, `recordGameOutcome({gameId})`, 이벤트 `game:pirate:exploded { loser, winner, bombSlot, gameId }`
- [ ] `slot_picked`에 `remaining`, `riskPct`(= round(100 / 남은 구멍)) 추가
- [ ] 벌칙: `game:pirate:penalty { text }`(이긴 사람만, 한 번, 앞뒤 공백 제거 후 1~30자) → 방에 `{ by, text }`. 진 사람 `game:pirate:penalty_done` → 방에 `{ by }`
- [ ] 방장 전용 `reset` 제거 → 재시작 프로토콜(티켓 04)로 대체. 복원이 `exploded`·벌칙 단계도 되살림
- [ ] 엔진/소켓 테스트: 선공 무작위(주입), `riskPct` 값, 폭발 후 상태 보존, 벌칙 권한·길이·1회, 재시작 시 `series`
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

해적 룰렛은 순수 운 게임이라 규칙은 그대로, 공정성(선공·짝수)만 보정한다.

## Likely files

- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/socket-game-regression.test.js`
