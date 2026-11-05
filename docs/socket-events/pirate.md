# 해적 룰렛 2.0 소켓 계약 (`game:pirate:*`)

서버: `services/realtime-server/src/games/pirate.js`(모듈), 규칙 `src/pirate-engine.js`.
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/pirate/pirate_controller.dart`.
Redis 키: `pirate:<room>:game`(TTL 1시간). 폭발 뒤에도 지우지 않는다(벌칙 단계·복원·재대결).

## 규칙 요약

- 구멍 수 `slots`는 로비 옵션 `pirate.holes` ∈ {6, 8, 12}(기본 8). 짝수만 허용해 선공·후공의 패배 확률이 정확히 50%다.
- 폭탄 구멍 하나, 선공은 서버가 무작위(재대결은 지난 판 선공의 상대).
- 차례 제한 20초(`turnMs`). 마감이 지나면 서버가 남은 구멍 하나를 무작위로 대신 찌른다(`auto: true`). 같은 사람이 **연속 3번** 시간을 넘기면 그 사람이 기권패(`reason: 'timeout'`).
- 폭탄 구멍을 찌른 사람이 진다(`reason: 'bomb'`). 잠수 감시(90초) 기권은 `reason: 'afk'`.
- 폭발 뒤 **벌칙 단계**: 이긴 사람이 벌칙 문구를 한 번 정하고, 진 사람이 "했어요!"를 한 번 보낸다.

## 시작·재대결

- 게임 화면에는 시작 버튼이 없다. 방장이 로비에서 `game:lobby:start { gameType: 'pirate' }` → 서버가 판을 만들고 방 전체에 `game:pirate:state`를 보낸다. 첫 마감 = 로비 카운트다운 끝(`startsAt`) + 20초.
- 재대결: 공용 `game:restart:request/respond { gameType: 'pirate' }`. 수락되면 같은 구멍 수, 새 `gameId`, `round + 1`, 선공 교대, 전적(`series`) 유지. 첫 마감 = 지금 + 1.5초 + 20초.
- 옛 `game:pirate:start`, `game:pirate:reset`, `game:pirate:started`, `game:pirate:reset_done`은 **없어졌다**.

## 클라이언트 → 서버 (모두 ack)

| 이벤트 | payload | 성공 ack | 실패 `reason` |
|---|---|---|---|
| `game:pirate:sync` | `{}` | `{ ok: true, state }` (판이 없거나 참가자가 아니면 `state: null`). 같은 상태를 이 소켓에 `game:pirate:state`로도 보낸다 | `not_joined` |
| `game:pirate:pick` | `{ slot: int, gameId?: string }` | `{ ok: true, exploded: bool }` | `invalid_payload`, `no_game`, `stale_game`(gameId 불일치), `not_playing`, `not_a_player`, `not_your_turn`, `invalid_slot`, `slot_taken` |
| `game:pirate:penalty` | `{ text: string }` | `{ ok: true, text }`(정리된 문구) | `no_game`, `not_exploded`, `not_winner`, `penalty_already_set`, `invalid_payload`(문자열 아님), `penalty_empty`, `penalty_too_long` |
| `game:pirate:penalty_done` | `{}` | `{ ok: true }` | `no_game`, `not_exploded`, `not_loser`, `no_penalty`, `penalty_already_done` |

벌칙 문구 정리: 제어 문자·줄바꿈 → 공백, 연속 공백 → 하나, 앞뒤 공백 제거. 길이는 **코드 포인트 1~30자**(이모지 하나 = 1자).
프리셋 10개(클라이언트 칩): 어깨 주물러 주기 / 칭찬 3가지 / 노래 한 소절 / 오늘 설거지 / 딱밤 한 대 / 사진 한 장 찍어 주기 / 소원 하나 들어주기 / 애교 한 번 / 아이스크림 사기 / 10분 안마. 서버는 프리셋 여부를 따지지 않는다.

## 서버 → 클라이언트

### `game:pirate:state` — 전체 공개 상태(진실의 원천)

판 생성·재대결·찌르기·폭발·벌칙·완료 뒤 방 전체에, `sync`·`session:restore` 때 그 소켓에만 보낸다. 두 사람이 같은 내용을 본다.

```jsonc
{
  "gameId": "uuid", "round": 1,
  "slots": 8,
  "pickedSlots": [0, 3],
  "stabs": [{ "slot": 0, "by": "<userCode>", "auto": false }],
  "players": ["<p1>", "<p2>"],          // 커플 순서
  "firstTurn": "<userCode>",
  "currentTurn": "<userCode>" | null,   // 폭발 뒤 null
  "phase": "playing" | "exploded",
  "remaining": 6, "riskPct": 17,         // round(100 / remaining)
  "timeouts": { "<p1>": 0, "<p2>": 1 },  // 연속 시간 초과 횟수
  "turnDeadline": 1730000000000 | null,  // epoch ms
  "turnMs": 20000,
  "serverNow": 1729999990000,            // GameDeadline.fromServer 보정용
  "bombSlot": null,                      // 폭발 전에는 항상 null
  "winner": null, "loser": null,
  "reason": null | "bomb" | "timeout" | "afk",
  "penalty": null | { "text": "...", "by": "<winner>", "at": 0, "doneAt": null | 0 },
  "seq": 2,                              // 판 안에서 단조 증가(늦게 온 옛 상태 무시용)
  "series": { "wins": { "<p1>": 1, "<p2>": 0 }, "draws": 0, "games": 1 }
}
```

### 연출·알림용 이벤트(방 전체)

| 이벤트 | payload |
|---|---|
| `game:pirate:slot_picked` | `{ gameId, slot, by, auto, nextTurn, pickedSlots, remaining, riskPct, turnDeadline, serverNow }` |
| `game:pirate:exploded` | `{ gameId, loser, winner, bombSlot, slot, by, auto, reason, forfeit, series, at }` — `slot`은 찌른 구멍(기권이면 `null`), `forfeit = reason !== 'bomb'` |
| `game:pirate:penalty` | `{ gameId, by, text }` |
| `game:pirate:penalty_done` | `{ gameId, by }` |

각 이벤트 바로 뒤에 같은 내용이 반영된 `game:pirate:state`가 온다. 새 화면 컨트롤러는 `state`만 듣고, 이전 상태와 비교해 칼 떨어뜨리기·폭발·벌칙 카드 연출을 결정한다.

## 정산·전적

- 폭발(또는 기권) 때 한 번: `kit.series.record(room, 'pirate', players, winner)` → `exploded.series`·`state.series`.
- `recordGameOutcome(room, { winner, players, gameType: 'pirate', gameId })` — `game_results.game_id`로 멱등, XP·미션 포함(옛 `saveGameResult` 직접 호출과 await 없는 XP 제거).

## 복원·잠수

- `session:restore`: 상태가 있고 그 소켓 사용자가 참가자면 `game:pirate:state`를 보낸다(진행 중·폭발·벌칙 단계 모두).
- 잠수 어댑터(`game-afk.js`): `waitingOn` = `phase === 'playing'`일 때 `currentTurn`, 아니면 없음. 보통은 20초 자동 찌르기가 먼저 동작한다.
