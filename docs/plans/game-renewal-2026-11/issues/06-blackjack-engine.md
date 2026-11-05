# 06: 블랙잭 2.0 엔진·소켓

**Type:** server

**Blocked by:** 04

**Status:** ready-for-agent

## What to build

블랙잭을 **먼저 2승 · 업카드 공개 · 버스트 즉시 종료 · 30초 자동 스탠드**로 바꾼다. 최종 무승부를 약 39%에서 1% 안팎으로 낮춘다.

## Acceptance criteria

- [ ] 엔진 상태·규칙: `02-spec.md` "블랙잭 / 엔진" 그대로(2승·최대 5라운드, 무승부 라운드는 승수 불변, 업카드/홀카드, 히트 공개, 블랙잭 비공개, 버스트 즉시 종료, 라운드마다 새 덱)
- [ ] 선후공: 1라운드 `random`, 이후 직전 패배자가 후공, 무승부 라운드는 교대
- [ ] `serializeFor`: 상대 손 = 업카드 + 히트 카드 공개 + 홀카드 `{hidden:true}`, 점수는 공개 카드 합만, 상대 `blackjack` 상태는 `playing`으로 표기(라운드 종료 시 공개)
- [ ] 다음 라운드: 양쪽 `next_round`(`ready`)가 모여야 시작
- [ ] 타이머: `turnDeadline`(30초), 서버 타이머가 자동 `stand`, 3회 시간 초과는 기권
- [ ] AFK 어댑터를 새 상태에 맞게 수정(`waitingOn`, `forfeit`), 복원(`session:restore`)이 새 상태를 보냄
- [ ] 엔진 테스트(TDD): 위 규칙 각각 + 시리즈 이어받기. **균형 테스트**: 스탠드 15·16·17 전략 각 2만 판에서 최종 무승부 < 3%
- [ ] 소켓 회귀: 시작·히트·스탠드·준비·타이머·재시작·복원
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

감사 문서의 "내추럴 노출" 문제를 이 티켓에서 함께 해결한다(블랙잭 보유자의 턴 건너뛰기가 정보를 드러내지 않게).

## Likely files

- `services/realtime-server/src/blackjack-engine.js`
- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/blackjack-engine.test.js`
