# 원카드(내부 식별자 `uno`) 2.0 소켓 계약

서버: `services/realtime-server/src/games/onecard.js`(흐름·타이머·정산), `src/uno-engine.js`(규칙, 순수 함수).
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/onecard/`(`OneCardController`).
결정 근거: `docs/plans/game-renewal-2026-11/01-grilling.md` Q49–Q55, 티켓 19·20.

## 시작

- 로비 `game:lobby:start { gameType: 'uno' }`가 곧 시작이다. 서버가 `startFromLobby`에서 판을 만들고
  `game:lobby:started.metadata.serverStart = true`를 보낸다. **`game:uno:new`는 없다.**
- 모드는 로비 옵션 `uno.mode`(`go_wild` 기본 | `classic`), 판돈은 로비 `stake`. 클라이언트 값은 쓰지 않는다.
- 첫 판 선공은 무작위. 첫 마감시각 = 로비 카운트다운 끝(`startsAt`) + 20초.

## 클라이언트 → 서버 (모두 ack `{ ok, reason? }`)

| 이벤트 | payload | 성공 ack | 거부 reason |
|---|---|---|---|
| `game:uno:sync` | `{}` | `{ ok, state }` + 이 소켓에 `game:uno:state` | `no_game`, `game_over`, `not_in_game` |
| `game:uno:play` | `{ cardId, declaredColor? }` (`red｜yellow｜green｜blue`, 와일드·+4만) | `{ ok, won? }` | `cannot_play_card`, `must_draw_or_defend`, `must_choose_drawn_card`, `must_declare_color`, `card_not_found`, `not_your_turn`, `invalid_payload` |
| `game:uno:draw` | `{}` | `{ ok, count, penalty, canPlayDrawn }` | `not_your_turn`, `must_choose_drawn_card` |
| `game:uno:pass` | `{}` (일반 뽑기로 낼 수 있는 카드를 받았을 때 넘기기) | `{ ok }` | `no_draw_choice`, `not_your_turn` |
| `game:uno:call` | `{}` ("원카드!") | `{ ok }` | `not_needed` |
| `game:uno:catch` | `{}` ("잡기!") | `{ ok, count, protected }` | `no_target` |
| `game:uno:challenge` | `{}` (+4 도전) | `{ ok, success }` | `cannot_challenge_during_stack`, `no_challenge_data` |

공통 거부: `not_joined`, `no_game`, 승자가 정해진 뒤에는 **모든** 원카드 이벤트가 `game_over`.
거부 사유의 한국어 문구는 클라이언트(`OneCardController.reasonMessages`)에 있다.
재대결은 공용 `game:restart:request/respond { gameType: 'uno' }`만 쓴다.
리액션은 공용 `game:reaction`(원카드 전용 `game:uno:reaction`·선물은 없어졌다).

## 서버 → 클라이언트

### `game:uno:state` (한 사람용, 상태가 바뀔 때마다 각 참가자에게)

```js
{
  gameId, mode: 'go_wild'|'classic', players: [User1, User2], starter,
  currentPlayer, turn /* = currentPlayer */, direction,
  topCard: { id, color, value }, recentDiscards: [/* 최근 5장, 마지막이 맨 위 */],
  declaredColor,            // 와일드·+4로 고른 색(없으면 null)
  currentColor,             // 지금 맞춰야 하는 색 = declaredColor ?? topCard.color
  drawStack, drawStackType, // 쌓인 벌칙(+N)과 종류('draw2'|'wild_draw4')
  handCount: { [user]: n }, hand: [/* 내 손패만 */], deckCount,
  unoCallNeeded,            // 한 장 남고 아직 안 외친 사람(나면 "원카드!", 상대면 "잡기!")
  drawnCardId,              // 내 차례에 일반 뽑기로 받은, 낼 수 있는 카드(낼지 넘길지 선택 중)
  playable: [cardId],       // 지금 낼 수 있는 내 카드
  canChallenge,             // 내가 +4에 도전할 수 있는지
  turnDeadline, turnMs: 20000, serverNow, // GameDeadline.fromServer로 시계 보정
  autoStreak: { [user]: n },// 연속 자동 처리 횟수
  equippedItems: { [user]: { onecard_cardback: { icon, grade, ... } } },
  stake, series: { wins, draws, games }, seq,
  lastAction: { seq, type, by, ... }, // 연출·소리 근거(아래)
  winner,
}
```

`lastAction.type`:
- `deal { starter }` — 새 판.
- `play { by, card, cards, count, effect: 'skip'|'reverse'|'draw2'|'draw4'|'wild'|'discard_all'|null, declaredColor, colorChanged, previousColor, turnSkipped, bonusDraw }`
- `draw { by, count, penalty, canPlayDrawn, auto, cardIds? }` — `cardIds`는 뽑은 본인에게만.
- `pass { by, auto }`, `call { by }`, `catch { by, target, count, protected, cardIds? }`
- `challenge { by, challenged, success, drawnPlayer, drawnCount, cardIds? }`

### `game:uno:challenged` (방 전체)
`{ by, challenged, success, drawnPlayer, drawnCount, nextPlayer, mode, drawStack: 0, drawStackType: null, declaredColor, handCount, unoCallNeeded }`

### `game:uno:ended` (방 전체, 한 번)
`{ gameId, winner, loser, reason: 'empty_hand'|'forfeit', hands: { [user]: [cards] }, handCount, series, stake, mode }`

### 그 밖
- `game:item_effect { stat, amount }` — 아이템 효과가 발동한 사람에게만(`card_shield_pct`, `card_lucky_draw_pct`, `card_reverse_bonus`, `card_uno_protect_pct`).
- `wallet:updated`, `wallet:settle_failed { gameType: 'uno', reason }` — 판돈 정산.

## 규칙·흐름

- 덱: 클래식 108장, 고와일드 116장(색별 "모두" 2장 추가). 손패 7장. 고와일드 쌓기: +2 위에 +2/+4, +4 위에 +4.
- +2/+4 벌칙을 받으면(뽑으면) **차례가 끝난다**. 일반 뽑기로 낼 수 있는 카드를 받으면 내거나(`play`) 넘긴다(`pass`).
- "모두" 묶음 안의 건너뛰기·방향 바꾸기는 **한 번만** 적용(2인: 한 번 더), 묶음 안의 +2는 공격이 아니다.
- +4를 낼 때 그 직전 색 카드가 손에 있었는지(`hadColorAtDraw4`)를 기록하고, 도전은 그 값으로 판정한다.
  성공: +4를 낸 사람이 4장, 도전한 사람 차례 유지. 실패: 도전한 사람이 6장, 차례는 +4를 낸 사람에게.
- 한 장이 되면 `unoCallNeeded`가 열린다. 상대가 다음 행동을 하기 전 "잡기!"면 2장.

## 마감시각·자동 처리·기권

- 상태가 바뀔 때마다 `turnDeadline = now + 20s`. 만료 시 서버가 안전한 행동만 한다:
  선택 중인 뽑은 카드가 있으면 넘기기, 아니면 쌓인 벌칙 받기 또는 한 장 뽑고 넘기기(무작위 카드를 내지 않는다).
- 같은 사람이 **연속 3번** 자동 처리되면 기권패(`game:uno:ended { reason: 'forfeit' }`). 손으로 한 행동은 그 사람의 횟수를 0으로.
- 공용 잠수 감시(90초)도 같은 종료 경로를 쓴다.

## 종료·정산 (`finishUnoGame`)

승리와 기권 모두: 끝남 저장 → 정산(`settleAndEmitWallet`, ref `uno:<gameId>`로 멱등, 연승·아이템 보너스 포함)
→ 결과 기록(`recordGameOutcome`, 미션 키 `onecard`) → 전적(`series`) → **finally에서 상태 삭제**와
`uno:<room>:last`(1시간) 저장 → `game:uno:ended`. 정산 중 예외가 나도 상태는 지워진다.

## 재대결·복원

- `game:restart:respond` 수락 → `uno:<room>:last { mode, stake, series, lastStarter, players, gameId }`를 이어
  같은 모드·판돈으로 새 판, **선공은 지난 판과 반대**. 새 `gameId`.
- `session:restore` → 진행 중이면 뷰어 방(`game-view:<room>:uno`)에 넣고 `game:uno:state`를 이 소켓에 보낸다
  (`restored`에 `'uno'`). `turnDeadline`이 없던 판은 지금부터 20초로 다시 건다.
- `game:lobby:join` 이어하기(`status: 'resumed'`)의 `state`도 같은 view 모양이다.
