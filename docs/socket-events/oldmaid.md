# 도둑잡기(oldmaid) 2.0 소켓 계약

서버: `services/realtime-server/src/games/oldmaid.js` (규칙: `src/oldmaid-engine.js`)
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/oldmaid/oldmaid_controller.dart`

규칙은 그대로다. 52장 + 조커 1장을 번갈아 나눠(27/26장) 각자 같은 숫자 짝을 버린다.
번갈아 상대 손패에서 한 장씩 뽑고, 짝이 맞으면 버린다. 마지막에 조커를 든 사람이 진다.

## 시작·재대결

- **시작**: 로비 `game:lobby:start` 때 서버가 판을 만든다(`metadata.serverStart: true`). 선공은 무작위.
  첫 마감은 로비 카운트다운이 끝나는 시각 + 25초. 게임 화면에 시작 버튼은 없다.
- **재대결**: 공용 `game:restart:request` / `game:restart:respond` (`gameType: 'oldmaid'`).
  새 `gameId`, 같은 방 전적(`series`) 유지, 선공은 지난 판과 반대.
- **복원**: `session:restore`가 진행 중인 판이면 그 소켓에 `game:oldmaid:state`를 다시 보내고 `restored`에 `'oldmaid'`를 넣는다.
- Redis 키: `oldmaid:<roomCode>:game` (1시간). 끝난 판도 결과 화면·재대결을 위해 남겨 둔다.

## 클라이언트 → 서버

| 이벤트 | payload | ack |
|---|---|---|
| `game:oldmaid:sync` | `{}` | `{ ok, gameId, status }` 또는 `{ ok:false, reason:'no_game' }`. 성공하면 이 소켓에 `state`를 보낸다 |
| `game:oldmaid:draw` | `{ slot: n }` 또는 `{ cardId: 'slot-N' }`, 선택 `gameId` | `{ ok:true }` 또는 `{ ok:false, reason }` |

`draw`의 거부 사유: `not_joined`, `invalid_payload`(별칭이 아님 — 실제 카드 id `card_…`는 받지 않는다),
`no_game`, `stale_game`(gameId 불일치), `not_a_player`, `not_your_turn`, `invalid_slot`, `game_over`.

## 서버 → 클라이언트

### `game:oldmaid:state` (사용자별)

```jsonc
{
  "gameId": "uuid",
  "status": "playing",            // | "finished"
  "players": ["U1", "U2"],        // 커플 순서
  "turn": "U2",                   // 뽑을 차례(끝나면 null)
  "firstTurn": "U2",
  "hands": {
    "U1": [{ "id": "card_7", "rank": "7", "suit": "♠", "isJoker": false }], // 나: 실제 카드(서버 순서)
    "U2": [{ "id": "slot-0" }, { "id": "slot-1" }]                          // 상대: 위치 별칭만
  },
  "handCounts": { "U1": 12, "U2": 13 },
  "discards": ["3", "Q", "7"],    // 버려진 짝의 랭크(공개, 분배 때 버린 짝 포함)
  "discardedPairsCount": 3,
  "log": [{ "by": "U1", "paired": true, "rank": "7", "at": 1730000000000 }], // 최근 6개, 짝이 아니면 rank=null
  "drawCount": 5,
  "timeouts": { "U1": 0, "U2": 1 }, // 연속 시간 초과 횟수
  "result": null,                 // 끝나면 { winner, loser, reason: 'joker'|'timeout'|'afk' }
  "series": { "wins": { "U1": 1, "U2": 0 }, "draws": 0, "games": 1 },
  "turnDeadline": 1730000025000,  // epoch ms(끝나면 null)
  "turnMs": 25000,
  "serverNow": 1730000000000      // GameDeadline.fromServer 시계 보정용
}
```

- 서버는 뽑은 사람의 손패를 뽑을 때마다 다시 섞는다. 상대가 고르는 `slot-N`은 위치일 뿐 카드·조커 위치를 드러내지 않는다.
  화면은 내 손패를 각자 정렬해서 보여 준다.
- 판이 끝나면 남은 카드(조커)는 양쪽 모두에게 공개된다.

### `game:oldmaid:drawn` (사용자별, 같은 뽑기의 `state`보다 먼저)

```jsonc
{
  "gameId": "uuid",
  "role": "drawer",               // "drawer" | "victim" | "spectator"
  "by": "U1", "from": "U2", "slot": 3,
  "card": { "id": "card_20", "rank": "7", "suit": "♥", "isJoker": false },
  "matched": { "id": "card_7", "rank": "7", "suit": "♠", "isJoker": false }, // 뽑은 사람만: 짝이 된 내 카드
  "paired": true, "pairedRank": "7",
  "jokerMoved": false,            // 뽑힌 카드가 조커였나
  "auto": false,                  // 시간 초과로 서버가 대신 뽑았나
  "handSize": 11,                 // 받는 사람의 뽑기 후 손패 수
  "drawCount": 6,
  "finished": false,              // 이 뽑기로 판이 끝났나
  "at": 1730000000000
}
```

- `card`는 언제나 **받는 사람이 이미 아는 카드**다. 뽑은 사람 = 뽑은 카드, 뺏긴 사람 = 뺏긴 자기 카드.
  상대 손패의 다른 실제 id는 어디에도 보내지 않는다. 구경꾼은 `card: null`.
- 문구 예: 뽑은 쪽 "♥7을 뽑았어요 · 짝!" / 뺏긴 쪽 "♥7을 뺏겼어요". 뺏긴 쪽에 "짝이 맞춰졌습니다"를 띄우지 않는다.

## 시간 제한·잠수

- 한 차례 25초(`turnDeadline`). 뽑은 뒤 다음 마감에는 연출 시간 1.8초를 더한다. 재대결 첫 마감에는 분배 연출 2초를 더한다.
- 마감이 지나면 서버가 상대 손패에서 무작위로 한 장을 대신 뽑는다(`drawn.auto: true`).
- 같은 사람이 연속 3번 시간을 넘기면 기권패(`result.reason: 'timeout'`). 직접 뽑으면 횟수가 0으로 돌아간다.
- 공용 잠수 감시(`game-afk.js`) 어댑터도 등록돼 있다(`reason: 'afk'`). 자체 타이머가 먼저 동작한다.

## 결과 기록

판이 끝나는 순간 한 번만: `series.record(room, 'oldmaid', players, winner)` → `recordGameOutcome(room, { winner, players, gameType:'oldmaid', gameId })`.
`gameId`로 멱등이다.
