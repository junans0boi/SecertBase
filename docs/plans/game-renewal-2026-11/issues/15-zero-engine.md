# 15: 제로 2.0 엔진·소켓

**Type:** server

**Blocked by:** 04

**Status:** ready-for-agent

## What to build

제로의 득점을 **정확 2점 · 더 가까우면 1점 · 5라운드 합산 + 서든데스**로 바꿔 한 판을 5~7라운드로 줄인다.

## Acceptance criteria

- [ ] `rps-engine.js`: `resolveZeroRound(pick1, pick2)` → `{ total, distance, exact, points, roundWinner }` (정확 2점, 둘 다 못 맞히면 더 가까운 쪽 1점, 같은 거리 0점)
- [ ] 검증: `guess ∈ [fingers, fingers+5]`, 벗어나면 `invalid_guess`로 거부. `rpsPickSchema` 범위는 유지하고 핸들러에서 검증
- [ ] 게임 진행: `maxRounds = 5`, 점수 합산. 5라운드 뒤 동점이면 한 라운드씩 서든데스(`suddenDeath: true`)
- [ ] `round_result`에 `points, distance, exact, maxRounds, suddenDeath, gameWinner` 추가(기존 필드 유지). `gameId`·`series` 추가, 결과 저장 `recordGameOutcome({gameId})`
- [ ] 복원이 라운드·점수·서든데스 상태를 그대로 보냄
- [ ] 엔진 테스트(TDD): 정확/근접/동거리/둘 다 정확 표, 범위 검증, 5라운드 합산, 서든데스. **균형 테스트**: 무작위·합리적 두 정책 각 2만 판에서 라운드 점수 갈림 > 65%, 한 판 평균 ≤ 7라운드
- [ ] 소켓 회귀: 시작·제출·공개·서든데스·재시작·복원·`invalid_guess`
- [ ] `docs/SOCKET_EVENTS.md` 갱신

## Notes

가위바위보(`single`/`rps3`/`mukjippa`)는 건드리지 않는다. `resolveHanabagiRound`는 호출부가 없어질 때까지 지우지 않는다.

## Likely files

- `services/realtime-server/src/rps-engine.js`
- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/rps-engine.test.js`
