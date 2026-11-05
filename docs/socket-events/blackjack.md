# 블랙잭 2.0 소켓 이벤트

> 서버: `services/realtime-server/src/games/blackjack.js`(모듈) + `src/blackjack-engine.js`(규칙).
> 클라이언트: `apps/secret_base_app/lib/screens/arcade/games/blackjack/blackjack_controller.dart`.

## 규칙 요약

- 한 판 = **먼저 2승**, 최대 5라운드. 무승부 라운드는 승수 불변. 5라운드 뒤 2승이 없으면 판 무승부(`winner: 'tie'`).
- 라운드마다 새 52장. 각자 2장: `hands[id][0]` = 업카드(공개), `hands[id][1]` = 홀카드(비공개). 히트 카드는 공개.
- 차례대로 행동. **버스트하면 즉시 라운드 종료**(상대 승). 둘 다 스탠드하면 비교: 블랙잭(처음 2장 21) > 일반 21 > 높은 합. 같으면 무승부 라운드.
- 블랙잭 보유자도 평소처럼 자기 차례에 스탠드한다(자동 진행 없음 → 정보 노출 없음). 21이 되면 히트 불가(`already_21`), 자동 스탠드도 없다.
- 선후공: 1라운드 무작위. 이후 **직전 라운드 패배자가 후공**(승자가 먼저 행동), 무승부 라운드는 교대. 재대결은 이전 판의 첫 선공과 반대 사람이 연다.
- 시간: 결정마다 30초(`turnDeadline`). 라운드 첫 결정은 딜 연출 1.5초를 더한다. 넘기면 서버가 자동 스탠드, **연속 3회**면 기권패(`reason: 'timeout'`). 직접 행동하면 연속 횟수가 0으로 돌아간다.
- 판돈 없음. 결과는 `recordGameOutcome(gameId)`로 한 번만 기록되고 방 전적(`series`)에 더해진다.

## 클라이언트 → 서버

모든 이벤트는 ack `{ ok: true }` 또는 `{ ok: false, reason }`을 돌려준다. payload는 비워 보낸다(`{}`).

| 이벤트 | 설명 | 거부 사유 |
|---|---|---|
| `game:blackjack:sync` | 현재 상태를 이 소켓에 `game:blackjack:updated`로 다시 보낸다. ack `{ ok, state }`(판이 없으면 `state: null`) | `not_joined` |
| `game:blackjack:hit` | 카드 한 장 | `not_joined`, `no_game`, `not_a_player`, `wrong phase`, `not_your_turn`, `already_21` |
| `game:blackjack:stand` | 멈추기. 상대가 행동 전이면 차례를 넘기고, 아니면 라운드를 끝낸다 | 위와 같음(`already_21` 제외) |
| `game:blackjack:next_round` | 라운드 결과에서 "다음 라운드" 준비. 둘 다 준비되면 새 라운드 | `not_joined`, `no_game`, `not_a_player`, `wrong phase` |

시작 이벤트는 없다. 로비 `game:lobby:start`가 성공하면 서버가 판을 만들고(`metadata.serverStart: true`)
바로 `game:blackjack:updated`를 보낸다. 재대결은 공용 `game:restart:request/respond { gameType: 'blackjack' }`.

## 서버 → 클라이언트: `game:blackjack:updated`

상태가 바뀔 때마다 방의 각 소켓에 **그 사람용 투영**을 보낸다. 덱은 보내지 않는다.

```jsonc
{
  "gameId": "uuid",
  "status": "playing" | "finished",
  "phase": "player_turn" | "round_result" | "finished",
  "players": ["U1", "U2"],            // 커플 순서
  "round": 1, "maxRounds": 5, "winsNeeded": 2,
  "wins": { "U1": 0, "U2": 0 },
  "firstPlayer": "U2",                // 이번 라운드 선공
  "currentTurn": "U2" | null,
  "turnDeadline": 1730790000000 | null, // epoch ms
  "turnMs": 30000,
  "serverNow": 1730789968500,         // GameDeadline.fromServer 보정용
  "hands": {
    "U1": [{ "suit": "♠", "rank": "10", "value": 10 }, { "suit": "♥", "rank": "7", "value": 7 }],
    "U2": [{ "suit": "♦", "rank": "K", "value": 10 }, { "hidden": true }, { "suit": "♣", "rank": "3", "value": 3 }]
  },
  "statuses": { "U1": "playing" | "stand" | "bust" },  // "blackjack"은 쓰지 않는다
  "scores": { "U1": 17 },             // 진행 중에는 내 것만, 라운드가 끝나면 둘 다
  "visibleScores": { "U1": 10, "U2": 13 }, // 공개 카드(홀카드 제외) 합
  "timeouts": { "U1": 0, "U2": 1 },   // 연속 시간 초과 수
  "ready": { "U1": false, "U2": true },
  "rounds": [{ "round": 1, "winner": "U1" | "tie", "reason": "bust" | "blackjack" | "score" | "tie",
               "scores": {}, "naturals": {} }],
  "lastRoundResult": {                // 끝난 라운드 전체 공개(손패 포함)
    "round": 1, "winner": "U1", "reason": "bust", "firstPlayer": "U2",
    "scores": {}, "naturals": { "U1": false, "U2": true }, "statuses": {}, "hands": {}, "wins": {}
  } | null,
  "result": {                         // 판이 끝났을 때만
    "winner": "U1" | "tie", "loser": "U2" | null,
    "reason": "wins" | "max_rounds" | "timeout" | "afk",
    "wins": { "U1": 2, "U2": 1 }
  } | null,
  "series": { "wins": { "U1": 3, "U2": 2 }, "draws": 1, "games": 6 } | null
}
```

- 진행 중(`player_turn`) 상대의 `hands[opp][1]`은 `{ "hidden": true }`이고 `scores[opp]`는 없다.
- 판을 끝낸 라운드는 `round_result`를 거치지 않고 곧바로 `finished`가 된다(`lastRoundResult`에 그 라운드가 남는다). 클라이언트는 공개 연출 뒤 결과 화면을 띄운다.

## 복원·잠수

- `session:restore`: 진행 중인 판이 있으면 그 소켓에 `game:blackjack:updated`를 보내고 `restored`에 `blackjack`을 넣는다.
- 잠수(`game:afk:*`, 60초 경고 · 90초 기권): 차례인 사람, 또는 라운드 결과에서 한 사람만 준비했을 때 준비하지 않은 사람을 기다린다. 기권 시 `result.reason: 'afk'`.
