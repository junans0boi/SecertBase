# 제로 2.0 소켓 이벤트 (`game:zero:*`)

서버: `services/realtime-server/src/games/zero.js` (엔진 `src/zero-engine.js`).
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/zero/` (`ZeroController`, `ZeroScreen`).
제로는 더 이상 `game:rps:*`(`mode: 'hanabagi'`)를 쓰지 않는다. 클래식 가위바위보(`single`/`rps3`/`mukjippa`)는 그대로 `game:rps:*`.

## 규칙

- 라운드마다 두 사람이 동시에 **손가락 0~5개**와 **합계 예측**을 낸다. 예측은 `[내 숫자, 내 숫자 + 5]`만 허용(밖이면 `invalid_guess`).
- 정확히 맞히면 **2점**(둘 다 맞히면 각 2점). 둘 다 못 맞히면 합계에 **더 가까운 쪽 1점**, 같은 거리면 0점.
- **5라운드 합산**. 동점이면 한 라운드씩 **서든데스**(그 라운드에서 점수가 갈리면 끝). 서든데스 5라운드 동안도 동점이면 무승부.
- 라운드 선택 시간 **20초**(`turnDeadline`). 공개 연출 동안(`revealUntil`, 6초)은 다음 라운드 시간을 세지 않는다.
  시간이 지나면 안 낸 사람은 무작위로 자동 선택(`auto`). **연속 3번 자동 선택이면 기권패**(둘 다면 무승부). 직접 내면 연속 횟수가 0으로 돌아간다.
- 잠수 감시(`game-afk.js`, 90초)는 한 사람만 냈을 때 나머지를 기다리는 안전망이다(보통 라운드 타이머가 먼저 동작).

## 시작·재대결·복원

| 흐름 | 동작 |
|---|---|
| 로비 | `game:lobby:join` / `game:lobby:start`, `gameType: 'zero'`. 서버가 판을 만들고(`metadata.serverStart = true`) 두 사람에게 `game:zero:state`를 보낸다. 첫 마감시각 = 로비 카운트다운 종료(`startsAt`) + 20초. 결과 저장의 `gameId`는 로비가 만든 값. |
| 재대결 | `game:restart:request` / `game:restart:respond` (`gameType: 'zero'`). 같은 두 사람으로 새 판(`gameId` 새로), 전적 `series`는 이어진다. 첫 마감 = 지금 + 1.5초 + 20초. |
| 복원 | `session:restore` → 진행 중이면 그 소켓에 `game:zero:state`(내 이번 라운드 선택 `myPick` 포함), ack의 `restored`에 `'zero'`. 끝난 판도 상태는 다시 보내지만 `restored`에는 넣지 않는다. |

## 클라이언트 → 서버

### `game:zero:sync` `{}`
화면이 열릴 때 보낸다. ack `{ ok: true, state: ZeroState | null }`, 같은 상태를 `game:zero:state`로도 그 소켓에 보낸다(`myPick` 포함).

### `game:zero:pick` `{ fingers, guess, round? }`
- `fingers`: 0~5 정수, `guess`: `fingers..fingers+5` 정수, `round`(선택): 지금 라운드 번호(늦게 도착한 선택 방지).
- ack:
  - `{ ok: true, round }` — 받음
  - `{ ok: true, already: true, round }` — 이번 라운드에 이미 냄(덮어쓰지 않음)
  - `{ ok: false, reason }` — `invalid_payload`(손가락 범위 밖) · `invalid_guess`(+ `range: { min, max }`) · `stale_round`(+ `round`) · `no_game` · `not_a_player` · `game_over` · `not_joined`

## 서버 → 클라이언트

### `game:zero:state` (방 전체, 상태가 바뀔 때마다)

```jsonc
{
  "gameId": "uuid", "gameType": "zero",
  "status": "playing" | "finished",
  "players": ["User1Code", "User2Code"],
  "round": 3,                    // 지금(다음에 낼) 라운드
  "maxRounds": 5,
  "suddenDeath": false,          // 지금 라운드가 서든데스인지
  "suddenDeathRounds": 0, "suddenDeathCap": 5,
  "scores": { "<id>": 2, "<id>": 1 },
  "submitted": { "<id>": true, "<id>": false },   // 값은 숨기고 낸 여부만
  "autoPicks": { "<id>": 0, "<id>": 1 },          // 연속 자동 선택 수
  "turnDeadline": 1730000000000, "turnMs": 20000,
  "revealUntil": 1729999994000 | null,
  "lastRound": RoundRecord | null,
  "history": [RoundRecord, ...],
  "result": null | { "winner": id|null, "loser": id|null, "draw": bool,
                     "reason": "score"|"sudden_death"|"draw_cap"|"forfeit"|"both_away",
                     "scores": {...} },
  "series": { "wins": { "<id>": n }, "draws": n, "games": n },
  "serverNow": 1729999990000,    // 기기 시계 보정용
  "myPick": { "fingers": 3, "guess": 5 }   // sync/restore 응답에서만, 본인 것
}
```

`RoundRecord`:

```jsonc
{
  "round": 1, "suddenDeath": false,
  "fingers": { "<id>": 3, "<id>": 2 },
  "guesses": { "<id>": 5, "<id>": 6 },
  "total": 5,
  "distance": { "<id>": 0, "<id>": 1 },
  "exact": { "<id>": true, "<id>": false },
  "points": { "<id>": 2, "<id>": 0 },
  "auto": { "<id>": false, "<id>": false },
  "roundWinner": "<id>" | "draw",
  "scores": { "<id>": 2, "<id>": 0 }      // 이 라운드까지 합계
}
```

### `game:zero:round_result` (방 전체, 라운드 공개 때)
`RoundRecord` 필드 전부 + `gameId`, `mode: 'zero'`, `maxRounds`, `history`, `gameWinner`(진행 중 `null`, 끝나면 승자 id 또는 `'draw'`), `result`, `series`, `nextRound`, `nextSuddenDeath`, `turnDeadline`, `serverNow`.
화면은 `game:zero:state`의 `lastRound`만으로도 공개 연출을 시작할 수 있다(현재 클라이언트는 `state`만 듣는다).

### 공용
- `game:afk:warning` / `game:afk:forfeit` (`gameType: 'zero'`).
- 결과 저장: `recordGameOutcome({ winner | 'draw', players, gameType: 'zero', gameId })` — `gameId`로 멱등. XP·미션은 기존과 같다.
- Redis: `game:<room>:zero`(1시간), 끝난 판 요약 `zero:<room>:last`, 전적 `series:<room>:zero`(6시간).
