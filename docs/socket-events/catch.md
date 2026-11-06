# 그림 맞히기 2.0 소켓 이벤트 (`game:catch:*`)

서버: `services/realtime-server/src/games/catch.js` (엔진 `src/catch-engine.js`, 제시어 `src/data/catch-words.json`).
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/catch/` (`CatchController`, `CatchScreen`).
옛 이벤트(`start` `draw` `clear`(인자 없음) `guess_log` `correct` `timeout` `timeout_result` `next` `reset` `hint_req` `round_start` `started` `word` `gameover`)는 모두 사라졌다.

## 규칙

- 두 사람이 번갈아 한 라운드씩 **그리는 사람 / 맞히는 사람**이 된다. 첫 그리는 사람은 서버가 무작위로, 재대결은 반대쪽이 먼저.
- 라운드 수는 로비 옵션 `catch.rounds` 6(기본)|4|8. 라운드 **60초**는 서버 타이머(`turnDeadline`)로 끝난다.
- 제시어는 방별 `catch:<room>:seen`(90일, 최근 600개)에 기록해 약 100판 동안 반복하지 않는다. 난이도는 라운드가 갈수록 오른다(앞 1/3 쉬움 · 가운데 보통 · 마지막 어려움). 분야(`category`)는 처음부터 공개.
- 점수: 맞힌 사람 **3 + 남은 20초당 1**(직접 힌트를 썼으면 -1, 최소 1), 그린 사람 **2**. 시간 초과는 0점. 마지막 라운드 뒤 점수가 높은 쪽이 승리(동점 무승부).
- 힌트: 3글자 이상 제시어는 남은 시간 **30초·15초**에 글자 한 칸씩 자동으로 열린다. 맞히는 사람은 직접 힌트(`hint`)를 라운드당 1번 쓸 수 있고 점수 -1. 한 칸은 항상 가려 둔다. 1~2글자 제시어는 힌트 없음.
- 정답 판정: 공백·구두점 제거, NFC, 소문자, 동의어(`aliases`). 세 글자 이상 제시어에서 한 글자 차이면 `close`(아까워요). 추측은 한 사람이 0.7초에 한 번.
- 라운드가 끝나면 **6초**(`revealUntil`) 동안 정답과 그림을 보여 주고 다음 라운드가 자동으로 시작한다(시작 버튼·다음 버튼 없음).
- **자리 비움**: 자기 차례에 한 획도 안 그린 라운드가 연속 2번이면 기권패(둘 다면 무승부).
- 결과 저장은 `recordGameOutcome(gameId)` 한 번, 전적 `series`는 방에서 이어진다.

## 시작·재대결·복원

| 흐름 | 동작 |
|---|---|
| 로비 | `game:lobby:join` / `set_option(rounds)` / `start`, `gameType: 'catch'`. 서버가 판을 만들고(`metadata.serverStart = true`) 각자에게 `game:catch:state`를 보낸다. 1라운드 마감 = 로비 카운트다운 종료 + 60초. |
| 재대결 | `game:restart:request` / `respond` (`gameType: 'catch'`). 라운드 수·전적 유지, 첫 그리는 사람 교대. |
| 복원 | `session:restore` 또는 `game:catch:sync` → 그 소켓에 `game:catch:state` + `game:catch:replay`(지금까지의 획). 끝난 판은 `gallery`가 든 상태만(복원 목록 `restored`에는 안 넣음). |

## 획 프로토콜 v2

> 획·취소·지우기와 추측의 `round_over` `stale_round` `too_fast` 거부는 사유를 `reason`이 아니라 **`why`**에 담는다. 라운드 끝 무렵의 늦은 묶음처럼 정상 동작 중에도 생기는 거부라서, 공용 안내창(`reason`을 보여 줌)이 뜨지 않게 하려는 것이다.

좌표는 **고정 4:3 보드를 0~1로 정규화**한 값(x는 보드 너비, y는 보드 높이 기준), 굵기 `w`는 **보드 너비 대비 비율**(0.002~0.12; 화면은 3단계 약 0.008 / 0.016 / 0.030). 색은 팔레트 번호 0~11(서버 검증), 지우개(`eraser`)는 색 없이 같은 굵기로 흰 종이를 칠하듯 지운다.

### `game:catch:stroke` (그리는 사람 → 서버 → 상대)

```jsonc
{ "round": 1, "id": "k3f9a", "seq": 0, "tool": "pen" | "marker" | "eraser",
  "color": 3, "w": 0.016, "pts": [[0.12, 0.40], [0.13, 0.41]], "end": false }
```
- 한 획 = `id`(영문·숫자·-_ 24자 이하) 하나. 손가락이 닿는 동안 **33ms마다 묶음(`seq` 0,1,2…)**을 보내고, 손을 떼면 **즉시** 마지막 묶음을 `end: true`로 보낸다. 탭(점)은 점 하나짜리 획.
- 첫 묶음(`seq` 0)이 `tool` `color` `w`를 정한다(뒤 묶음의 값은 무시). 묶음당 점 80개 이하.
- 서버는 좌표를 0~1로 자르고 소수 4자리로 줄여 상대에게 그대로 전달한다(`end` 포함, 보낸 사람에겐 안 돌려줌). `end: true`마다 Redis(`game:<room>:catch:art`)에 저장.
- ack(안 받아도 됨): `{ ok: true }` · `{ ok: true, duplicate: true }`(같은 `seq` 재전송) · `{ ok: false, why }` — `not_drawer` · `round_over` · `stale_round`(+`round`) · `invalid_payload` · `unknown_stroke`(취소·지우기 뒤에 늦게 온 묶음) · `rate_limited` · `stroke_limit` · `no_game` · `not_joined`
- 제한: 소켓당 1초에 묶음 60개·점 1,500개, 라운드당 획 400·점 12,000, 획 하나 4,000점.

### `game:catch:undo` `{ round, id? }` → 상대에게 `game:catch:undo { round, id }`
`id`가 없으면 마지막 획. 서버 기록에서도 빠진다. ack `{ ok: true, id }` · `no_stroke` 등.

### `game:catch:clear` `{ round }` → 상대에게 `game:catch:clear { round }`
보드 전체 지우기(화면에서 확인을 받은 뒤 보낸다).

### `game:catch:replay` `{ round, strokes: [{ id, tool, color, w, pts }] }` (서버 → 요청한 소켓)
`sync`/`session:restore`에 대한 응답. 받은 쪽은 그 라운드의 획을 이것으로 **통째로 바꾼다**.

## 그 밖의 이벤트

### `game:catch:sync` `{}`
ack `{ ok: true, state: CatchState | null }`.

### `game:catch:guess` (클라이언트 → 서버) `{ round, text }`
`text` 20자까지. ack `{ ok: true, verdict: 'wrong' | 'close' | 'correct' }` 또는 `{ ok: false, reason }` — `invalid_payload`(round 없음 포함) · `stale_round` · `drawer_cannot_guess` · `too_fast`(0.7초) · `round_over` · `game_over` · `no_game` · `not_a_player`.

### `game:catch:guess` (서버 → 방 전체) `{ id, round, userId, text, verdict }`
추측 말풍선. **그리는 사람도 받는다**(`verdict`가 `close`면 "아까워요"). 정답이면 이어서 `round_result`.

### `game:catch:hint` `{ round? }`
맞히는 사람만. ack `{ ok: true, penalty: 1 }` · `hint_used` · `no_more_hints` · `drawer_cannot_hint` · `stale_round` 등. 열린 글자는 `state.hint`에 반영(방 전체).

### `game:catch:round_result` (방 전체)
`{ gameId, round, drawer, word, category, outcome: 'correct'|'timeout', guesser, points:{[user]:n}, timeLeftMs, usedHint, scores, maxRounds, last, revealUntil, serverNow }` — 연출 시작 신호.

### `game:catch:state` (사람마다 따로, 상태가 바뀔 때마다)
```jsonc
{ "gameId", "status": "playing"|"finished", "phase": "drawing"|"reveal"|"over",
  "players": [A, B], "round", "maxRounds", "drawer", "category", "wordLen", "difficulty",
  "hint": ["", "양", ""],          // 열린 글자 칸(닫힌 칸은 빈 문자열)
  "canHint", "directHint",
  "word": "고양이",                 // 그리는 사람, 또는 reveal/over 단계에서만 (맞히는 사람에게는 정답 공개 전까지 없음)
  "roundStartsAt", "turnDeadline", "roundMs": 60000, "revealUntil", "revealMs": 6000,
  "scores", "guesses": [최근 12개 말풍선], "history": [라운드 기록], "result", "series", "serverNow",
  "gallery": [{ round, drawer, word, category, outcome, guesser, strokes }]   // status 'finished'일 때만
}
```
`result`: `{ winner|null, loser|null, draw, reason: 'score'|'forfeit'|'both_away', scores }`.
