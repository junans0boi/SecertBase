# 윷놀이 2.0 소켓 계약

서버: `services/realtime-server/src/games/yut.js`(흐름·30초 타이머·정산), `src/yut-engine.js`(규칙, 순수 함수).
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/yut/`(`YutController`), 진입점 `games/yut_screen.dart`의 `YutScreen`.
결정 근거: `docs/plans/game-renewal-2026-11-wave2/01-grilling.md` Q6–Q13, 티켓 21.

## 시작

- 로비 `game:lobby:start { gameType: 'yut' }`가 곧 시작이다. 서버가 `startFromLobby`에서 판을 만들고
  `game:lobby:started.metadata.serverStart = true`를 보낸다. **`game:yut:new`·`roll_start`(주사위 순서)는 없다.**
- 캐릭터(`game:lobby:select_character`로 고른 홍길동·놀부·미호)·배경음(`metadata.yutBgm`)·판돈(로비 `stake`)·말 수(로비 옵션 `yut.pieces`: `4`(기본)｜`3`｜`2`)는 서버 로비 기록만 쓴다. 클라이언트 값은 쓰지 않는다. 두 사람이 같은 캐릭터가 되지 않는다.
- 첫 순서는 서버 무작위. 첫 마감시각 = 로비 카운트다운 끝(`startsAt`) + 30초.

## 클라이언트 → 서버 (모두 ack `{ ok, reason? }`)

| 이벤트 | payload | 성공 ack | 거부 reason |
|---|---|---|---|
| `game:yut:sync` | `{}` | `{ ok, state }` + 이 소켓에 `game:yut:state` | `no_game`, `game_over`, `not_in_game` |
| `game:yut:throw` | `{}` | `{ ok, seq, throw: { result, resultName, sticks, nak, bonus } }` | `not_your_turn`, `must_move_first` |
| `game:yut:move` | `{ pieceId, moveIndex?, backdoDir? }` (`legalMoves`의 한 항목) | `{ ok, seq, won? }` | `invalid_payload`, `must_throw_first`, `not_your_turn`, `invalid_move` |

공통 거부: `not_joined`, `no_game`, 승자가 정해진 뒤에는 **모든** 윷놀이 이벤트가 `game_over`.
재대결은 공용 `game:restart:request/respond { gameType: 'yut' }`만 쓴다(리액션은 공용 `game:reaction`; 옛 `game:yut:chat`은 없어졌다).

## 서버 → 클라이언트

### `game:yut:state` (두 사람에게 같은 내용, 상태가 바뀔 때마다)

```js
{
  gameId, seq, players: [User1, User2], pieceCount, starter,
  phase: 'throwing'|'moving'|'finished', currentTurn,
  pieces: { [user]: [{ id, position, lastPos, finished }] }, // 0=대기, 1–19 바깥길, 20=참먹이, 21–29 지름길
  pendingMoves: [1|2|3|4|5|-1],     // 아직 쓰지 않은 던지기 결과(-1=빽도)
  canThrow, hasBonusThrow, captureBonusThrows,
  lastThrow, turnThrows: [{ result, resultName, sticks, nak, bonus, auto }],
  legalMoves: [{ moveIndex, steps, pieceId, pieceIds, backdoDir, from, to, path, finish, captures, stacks }],
  characters: { [user]: 'honggilldong'|'nolbu'|'miho' }, bgm,
  stake, coinBonus: { [user]: n }, coinBonusCap,
  equippedItems,            // 두 사람 모두: { [user]: { yut_piece: { name, icon, grade, stats }, yut_yut: {...} } }
  effects,                  // 두 사람 모두: 이 판에 실제로 적용되는 효과(상한 적용 후) — 아래 참고
  series: { wins, draws, games }, winner,
  turnDeadline, turnMs: 30000, serverNow,   // GameDeadline.fromServer로 시계 보정
  lastAction,                                // 연출·소리 근거(아래)
}
```

- `legalMoves`는 현재 차례 사람 기준이다. 화면은 규칙을 다시 계산하지 않는다. 대기 말은 하나만, 업힌 말은 무더기로(`pieceIds`) 한 항목이며 `pieceId`를 보내면 된다. 빽도 갈림길(방 23·찌모 15·참먹이 20)은 `backdoDir`(고를 수 있는 앞 칸)별로 항목이 둘이다. `path`는 출발~도착의 칸 번호(붓 경로 애니메이션용).
- `sticks`: 길이 4, `0`=납작한 면, `1`=둥근 면, 0번이 표시 막대. 화면의 막대는 이 모양대로 멈춘다. 서버는 결과와 막대를 항상 맞춘다(아이템으로 결과가 바뀌면 막대도 다시 만든다).

`lastAction.type`:
- `start { by }` — 새 판(by=선).
- `throw { by, auto, throw, itemEffects, turnPassed? }` — 낙(`throw.nak`)이면 `turnPassed`.
- `move { by, auto, move: { moveIndex, steps, pieceIds, from, to, path, finish, backdoDir, captured, capturedPlayer, blocked, blockedAt, stacked }, discardedBackdo, itemEffects, turnPassed? }` — `blocked`가 있으면 방어 성공(움직이던 말은 `blockedAt` 바로 앞 칸에 멈춘다).
- `itemEffects: [{ player, stat, amount }]` — 실제로 적용된 아이템 효과(`yut_win_coin_pct`·`piece_catch_coin_bonus`·`yut_catch_bonus` = 쌓인 코인, `yut_capture_protection` = 막은 말 수, `yut_backdo_bonus_pct`).

### `game:yut:ended`

```js
{ gameId, winner, loser, reason: 'goal'|'forfeit', stake, coinBonus,
  transferred, winnerGain, settlement: 'none'|'settled'|'capped'|'already'|'failed',
  finished: { [user]: n }, pieceCount, pieces, characters, series }
```

영수증: `transferred` = 진 사람에게서 실제로 옮겨진 판돈(잔액이 모자라면 `stake`보다 작다 → `capped`), `winnerGain` = 이긴 사람이 실제로 받은 코인(보너스 포함), 정산이 실패하면 `failed`와 0. 화면은 `stake`가 아니라 이 값을 보여 준다.

판돈은 기존 `wallet:updated`로 반영되고, 실패하면 `wallet:settle_failed`. 정산 ref는 `yut:<gameId>`(멱등), 결과 저장은 `recordGameOutcome(gameId)`.

## 상점 아이템 표시

- `equippedItems[user].yut_piece` — 말 스킨(동물). 있으면 화면이 그 사람의 말 그림을 캐릭터 대신 `icon` 이모지 동물 말(등급 `grade`별 테두리·빛)로 그린다. `yut_yut` — 윷가락 스킨(이름·아이콘·등급으로 윷가락 모양을 고름).
- `effects[user] = { controlPct, moRatePct, overturnPct, backdoBonusPct, defensePct, winCoinPct, catchCoinPer, catchFlat }` — 서버가 합산 상한(throw 계열 3%, 방어 10%)을 적용한 **실제 값**. 화면의 "효과" 칩은 원시 아이템 수치가 아니라 이 값을 보여 준다(판돈이 없는 판에서는 코인 효과를 감춘다).

## 캐릭터

- 로비에서 `game:lobby:select_character { gameType: 'yut', character }`(홍길동 `honggilldong`·놀부 `nolbu`·미호 `miho`)로 고른다. 이미 상대가 고른 캐릭터는 `character_taken`으로 거부된다. 고르지 않은 사람은 서버가 겹치지 않는 캐릭터를 배정한다(`state.characters`).

## 규칙·균형

- 던지기: 막대 4개(납작 0→모, 표시 막대만 납작→빽도, 1→도, 2→개, 3→걸, 4→윷). 윷·모는 한 번 더. 잡기 1회마다 한 번 더(윷·모 보너스와 따로).
- 아이템: 던지기 계열(`yut_control_pct`·`yut_mo_rate_pct`·`yut_overturn_pct`·`yut_backdo_bonus_pct`)은 합이 3%를 넘으면 같은 비율로 줄이고, 걸→윷·도→모만 올린다(**빽도는 올리지 않는다**). 방어(`piece_catch_resist_pct`+`piece_safe_zone_pct`)는 한 번만 굴리고 합 10% 상한. 막히면 움직이던 말이 바로 앞 칸에 멈추고(앞 칸이 대기이거나 앞 칸에도 상대 말이 있으면 방어 실패, 정상 잡기).
- 코인 보너스(`yut_win_coin_pct`·`piece_catch_coin_bonus`·`yut_catch_bonus`)는 판당 판돈의 30%까지 쌓고 정산 때 승자에게만 지급(무료 판은 0).
- 한쪽만 아이템을 최대로 껴도 승률 55% 이하(`test/yut-balance.test.js`, 시드 고정 시뮬레이션).

## 시간·잠수

- 상태가 바뀔 때마다 `turnDeadline`을 30초 뒤로. 만료되면 서버가 던질 차례면 던지고, 남은 이동을 "잡기 > 골인 > 가장 앞선 말"(`autoMove`)로 하나씩 둔다(윷·모로 보너스가 생기면 멈추고 새 30초). `lastAction.auto`로 알린다.
- 같은 사람이 연속 3번 자동 처리되면 기권패(`reason: 'forfeit'`). 손으로 한 행동은 횟수를 지운다. 공용 잠수 감시(60초 경고·90초 기권)도 같은 종료 경로를 쓴다.

## 재대결·복원

- 끝난 판은 `yut:<room>:game`을 지우고 `yut:<room>:last`에 판돈·캐릭터·배경음·말 수·선·전적 요약을 남긴다. 동의된 재대결은 이를 이어 새 판을 만들며 **선을 바꾼다**. 판돈이 걸린 판이 진행 중이면 `game_in_progress`로 거부.
- 재접속(`session:restore`, 로비 이어하기)은 끝나지 않은 판의 `game:yut:state`를 다시 보낸다. 끝난 판은 복원하지 않는다.
