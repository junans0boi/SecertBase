# 고스톱(2인 맞고) 2.0 소켓 계약

서버: `services/realtime-server/src/games/gostop.js`(흐름·25초 마감·정산), `src/gostop-engine.js`(규칙, 순수 함수).
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/gostop/`(`GostopController`).
근거: `docs/plans/game-renewal-2026-11-wave2/01-grilling.md` Q25–Q29, 티켓 24(#249).

## 규칙(도움말과 같음)

- 7점 이상이면 고/스톱. 고: 1고 +1점, 2고 +2점, 3고부터 +3점에 ×2, 이후 고마다 +1점·×2. 고 이후 점수가 오르지 않으면 다시 묻지 않는다.
- 박: 피박(이긴 쪽이 피로 점수를 냈고 진 쪽 피 7장 이하), 광박(이긴 쪽이 광으로 점수를 냈고 진 쪽 광 0장), 고박(고를 외친 사람이 지면 ×2).
- 흔들기·폭탄: 선언한 사람이 이길 때만 각각 ×2. 흔들기는 같은 월 3장 중 한 장을 낼 때 `shake: true`.
- 쓸: 턴이 끝났을 때 바닥이 비면 상대 피 1장(마지막 턴 제외). 쪽·따닥·폭탄·뻑 가져오기도 피 1장.
- 마지막 턴: 마지막에 점수를 낸 사람만 승리(낼 패가 없으면 자동 스톱). 고를 외치고 더 못 났으면 나가리.
- 손패가 바닥 두 장과 맞으면 직접 선택(`phase: 'choice'`). 폭탄 뒤 도탄 2번. 바닥 같은 월 4장은 다시 나눔. 총통(손에 같은 월 4장) = 10점 즉시 승리(거절 가능, 둘 다면 다시 나눔).
- 국진(9월 열끗)은 열끗 고정, 보너스 피 없음. 나가리 배수 이월은 이번 범위 밖.

## 시작·시간

- 로비 `game:lobby:start { gameType: 'gostop' }`가 곧 시작이다. 서버가 `startFromLobby`에서 판을 만들고 `metadata.serverStart = true`. **`game:gostop:new`는 없다.**
- 1점당 판돈 = 로비 `stake`(0 | 100 | 500 | 1000). 클라이언트 값은 쓰지 않는다. 첫 판 선은 무작위, 첫 마감 = 로비 카운트다운 끝 + 25초.
- 상태가 바뀔 때마다 `turnDeadline`(+`serverNow`)을 25초로 다시 건다. 마감이 지나면 서버가 자동 행동:
  패 = 코치 추천(흔들기 안 함) · 두 장 선택 = 점수가 더 오르는 쪽 · 고/스톱 = **스톱** · 총통 = 선언 · 도탄 가능하고 먹을 패가 없으면 도탄.
  같은 사람이 연속 3번 자동 처리되면 기권패(고/스톱 단계는 예외 — 항상 스톱). 기권 지불은 실제 점수·배수.
- 잠수 감시(90초)는 고/스톱 단계를 기다리지 않는다.

## 클라이언트 → 서버 (모두 ack `{ ok, reason? }`)

| 이벤트 | payload | 비고 |
|---|---|---|
| `game:gostop:sync` | `{}` | `{ ok, state }` + 이 소켓에 `game:gostop:state`. 거부: `no_game`, `game_over`, `not_in_game` |
| `game:gostop:play` | `{ cardId, shake?: bool, targetId? }` | 손패 내기. `targetId`로 두 장 중 바닥 패를 미리 고를 수 있음 |
| `game:gostop:bomb` | `{ month }` | 폭탄(손패 같은 월 3장 + 바닥 1장) |
| `game:gostop:dotan` | `{}` | 도탄(더미만 뒤집기) |
| `game:gostop:choose` | `{ cardId }` | `phase: 'choice'`에서 바닥 패 고르기 |
| `game:gostop:decide` | `{ decision: 'go'｜'stop' }` | `phase: 'go_stop'` |
| `game:gostop:chongtong` | `{ declare: bool }` | `phase: 'chongtong'` |

성공 ack: `{ ok: true, phase }`. 거부 reason(코드만, 문구는 클라이언트): `not_your_turn`, `invalid_phase`, `card_not_in_hand`, `cannot_shake`, `cannot_bomb`, `no_dotan`, `invalid_choice`, `invalid_decision`, `invalid_payload`, `game_over`, `no_game`, `not_in_game`, `not_joined`, `internal_error`.
끝난 판의 모든 동작은 `no_game`/`game_over`. 재대결은 공용 `game:restart:request/respond { gameType: 'gostop' }`만 쓴다(이긴 사람이 선, 판돈·전적 유지, 진행 중 판돈 판은 `game_in_progress`).

## 서버 → 클라이언트

### `game:gostop:state` (한 사람용)

```js
{
  version: 2, gameId, seq, turn, phase,        // 'chongtong'|'playing'|'choice'|'go_stop'|'finished'|'nagari'
  players: [User1, User2], starter, current, perPointBet,
  hand: [/* 내 손패만 */], handCount: { [user]: n }, deckCount,
  field: [card], captures: { [user]: [card] }, scores: { [user]: { total, gwangCount, animCount, ribCount, piTotal, … } },
  goCount, goScore, shakes: { [user]: [month] }, bombs: { [user]: n }, dotan: { [user]: n },
  ppeok: { [month]: user },                     // 바닥 뻑 더미
  pending: { kind: 'hand'|'deck', card, options: [card] } | null,
  chongtong: { player, month|null } | null,     // 상대의 월은 null
  moves: { shakeable: [month], bombable: [month], dotan } | null,   // 내 차례 playing일 때만
  coach: { type: 'play', cardId } | { type: 'bomb', month } | { type: 'dotan' } | null,
  projection: { [user]: { points, multipliers, multiplier, amount } },   // 지금 스톱하면
  goPreview: { stopNow, afterGo } | null,       // 내 go_stop일 때
  lastTurn: { kind: 'play'|'bomb'|'dotan'|'go'|'stop'|…, seq, by, auto, played, flipped, captured, stolen, events, shown, scoreAfter },
  result, turnDeadline, turnMs: 25000, serverNow, autoStreak, series,
}
```

`lastTurn.events`: `shake`, `bomb`, `jjok`(쪽), `ppeok`(뻑), `ppeok_take`, `ttadak`(따닥), `sseul`(쓸), `go`, `auto_stop`. 연출·소리의 근거이며 `seq`가 늘 때만 새 연출이다.

### `game:gostop:ended`

```js
{
  gameId, reason: 'stop'|'auto_stop'|'chongtong'|'forfeit'|'nagari', winner|null, loser|null,
  receipt: {
    reason, winner, loser,
    points: { base, go, total },                    // total = base + go
    multipliers: [{ code: 'go'|'shake'|'bomb'|'pibak'|'gwangbak'|'gobak', count, factor }],
    multiplier,                                     // factor의 곱
    perPointBet, amount,                            // amount = total × multiplier × perPointBet (받아야 할 금액)
    transferred,                                    // 실제로 옮겨진 코인(상대 잔액이 모자라면 amount보다 작음)
    settlement: 'none'|'settled'|'capped'|'already'|'failed',
    auto,                                           // 서버가 대신 스톱/선언했는지
    winnerScore, loserScore, goCount, chongtongMonth?,
  },
  captures, scores, hands /* 끝난 뒤 공개 */, goCount, shakes, bombs, series, stake,
}
```

정산은 `gostop:<gameId>`로 멱등이고 `recordGameOutcome(gameId)`는 한 번. 정산이 실패해도 판은 끝나고(`settlement: 'failed'`, `transferred: 0`, `wallet:settle_failed`) 상태는 삭제된다. 나가리는 코인 이동 없이 무승부로 기록.
