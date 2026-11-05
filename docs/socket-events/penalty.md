# 패널티킥 2.0 소켓 계약 (`penalty`)

서버 모듈: `services/realtime-server/src/games/penalty.js`, 엔진: `src/penalty-engine.js`.
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/penalty/penalty_controller.dart`.

## 규칙 요약

- 칸 수 `cells` ∈ {3, 6}: 로비 옵션 `penalty.cells`(방장이 고름, 기본 3). 로비 없이 만든 판은 3.
  - 3칸: `0` 왼쪽 · `1` 가운데 · `2` 오른쪽
  - 6칸: 3열 × 2행 — `0 1 2` 위, `3 4 5` 아래
- 키커와 키퍼가 동시에 고른다. 같은 칸이면 선방, 아니면 골.
- 5킥씩 찬 뒤 동점이면 서든데스(3칸 최대 5쌍, 6칸 최대 10쌍), 그래도 같으면 무승부.
- 첫 킥커는 서버가 무작위로 정하고 이후 교대. 재대결은 지난 판의 첫 킥커가 아닌 사람이 먼저.
- 한 번 고르는 시간 20초(`turnDeadline`). 지나면 서버가 안 낸 사람의 칸을 무작위로 채워 판정.
  같은 사람이 연속 3번 자동 선택되면 기권패(`reason: "forfeit"`). 둘 다 3번이면 기록 없이 끝(`reason: "abandoned"`).
- 판정 뒤 다음 마감은 `판정 시각 + 2.5초(연출) + 20초`.

## 클라이언트 → 서버

| 이벤트 | payload | ack |
|---|---|---|
| `game:penalty:sync` | `{}` | `{ ok: true, state: PenaltyState \| null }` — 화면이 열릴 때. 상태가 있으면 같은 내용을 `game:penalty:state`로도 보낸다 |
| `game:penalty:submit` | `{ choice: int }` (`0 ≤ choice < cells`) | `{ ok: true, resolved: bool }` 또는 `{ ok: false, reason }` |

`submit` 거부 사유: `not_joined`, `no_game`, `finished`, `not_a_player`, `invalid_choice`, `already_submitted`.

판은 로비 시작(`game:lobby:start`, `metadata.serverStart: true`)과 함께 서버가 만든다. 게임 화면에 시작 이벤트는 없다
(옛 `game:penalty:start`·`game:penalty:updated`는 없어졌다). 재대결은 공용 `game:restart:request/respond`(`gameType: "penalty"`).

## 서버 → 클라이언트

`game:penalty:state` — 방 전체(재접속·sync는 그 소켓에만). 상태가 바뀔 때마다.

```jsonc
{
  "gameId": "uuid",
  "status": "playing" | "finished",
  "cells": 3 | 6,
  "players": ["U1", "U2"],          // 커플 순서
  "firstKicker": "U2",
  "round": 4,                         // 1부터. 지금 차는 킥 번호
  "kicker": "U1", "keeper": "U2",
  "submissions": { "U1": true },      // 판정 전에는 "냈는지"만(방향 비공개)
  "scores": { "U1": 2, "U2": 1 },
  "rounds": [                          // 지난 킥 전부 공개(방향·결과)
    { "round": 1, "kicker": "U2", "keeper": "U1", "kickerDir": 2, "keeperDir": 0,
      "isGoal": true, "autoKicker": false, "autoKeeper": true }
  ],
  "suddenDeath": false,
  "autoPicks": { "U1": 0, "U2": 1 }, // 연속 자동 선택 횟수(3이면 기권)
  "turnDeadline": 1730000000000,      // epoch ms, 끝난 판은 null
  "serverNow": 1729999990000,         // 기기 시계 보정용(GameDeadline.fromServer)
  "series": { "wins": { "U1": 1, "U2": 0 }, "draws": 0, "games": 1 },
  "result": null | { "winner": "U1" | "draw", "loser"?: "U2", "scores": {...},
                     "reason": "score" | "draw" | "forfeit" | "abandoned" }
}
```

공용 이벤트: `game:afk:warning` / `game:afk:forfeit`(안전망, 한 사람만 낸 채 타이머가 사라졌을 때), `game:reaction`.

## Redis

- `game:<room>:penalty` — 상태(1시간). 끝난 판도 남겨 재대결이 칸 수·첫 킥커를 잇는다.
- `series:<room>:penalty` — 이번 방 전적(6시간, `games/series.js`).
- 복원·sync·submit 때 옛 형식(`cells` 없음 또는 범위 밖 선택)을 만나면 지운다.

## 기록

끝나면 `recordGameOutcome({ winner | null, players, gameType: "penalty", gameId })` 한 번(gameId로 멱등) +
`series.record`. `abandoned`는 기록하지 않는다.
