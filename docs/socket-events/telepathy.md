# 텔레파시 2.0 소켓 이벤트 (`game:telepathy:*`)

서버: `services/realtime-server/src/games/telepathy.js` (엔진 `src/telepathy-engine.js`, 문제 은행 `src/data/telepathy-questions.json`).
클라이언트: `apps/secret_base_app/lib/screens/arcade/games/telepathy/` (`TelepathyController`, `TelepathyGameScreen`). 진입점은 `games/telepathy_screen.dart`의 `TelepathyScreen`.
옛 `game:telepathy:select` / `game:telepathy:result` 경로와 `telepathy:<room>:session` 키는 삭제됐다.

## 규칙

- **밸런스 게임**: 문제마다 A·B 두 보기 중 하나를 둘이 몰래 고른다. 둘 다 고르면(또는 마감이 지나면) 함께 공개하고, 같은 쪽이면 **통했다**.
- 한 판 **10문제**(로비 옵션 `rounds` 5 / 10 / 15). 문제당 **15초**(`turnDeadline`). 새 판의 첫 문제만 규칙 안내를 읽도록 **+25초**(`TELEPATHY_FIRST_EXTRA_MS`, 재대결 제외)이고 `turnMs`도 그만큼 늘어 타이머 링이 맞는다. 공개 연출(`revealUntil`, 3.5초) 동안은 다음 문제 시간을 세지 않는다.
- 시간이 지나면 안 고른 사람은 **시간 초과**(`null`) → 그 문제는 불일치.
- **연속 3문제 둘 다 시간 초과**면 판 종료(`both_away`). 한 사람만 연속 3번 시간 초과여도 판 종료(`away`, `awayPlayer`). 직접 고르면 연속 횟수는 0.
- 점수 = 통한 수. 연속으로 통하면 `streak`(🔥 표시), 판의 최고 연속 `bestStreak`.
- 등급(통한 비율, 10문제 기준): 9–10 `soulmate` "텔레파시 커플" · 7–8 `eyes` "눈빛만 봐도" · 4–6 `learning` "알아가는 중" · 0–3 `opposites` "반대가 끌려요".
- 협동 게임: **승패·무승부 기록과 코인 없음**(`recordGameOutcome`을 부르지 않는다). 끝까지 푼 판만 방 시리즈에 더한다.
- 잠수 감시(`game-afk.js`, 90초)는 한 사람만 골랐을 때의 안전망이다(보통 15초 마감이 먼저 동작). 만료되면 `away`로 판을 마친다.

## 문제 은행과 셔플 가방

- `src/data/telepathy-questions.json`: 320문제 = 8분야 × 40. `{ id: "food-001", cat, a, b, emojiA, emojiB, spicy }`.
  분야: `light` 가벼운 취향 · `food` 음식·야식 · `date` 데이트 · `travel` 여행 · `daily` 일상·생활습관 · `romance` 연애·로맨스 · `whatif` 만약에 · `spicy` 살짝 매운맛(`spicy: true`).
- 서버 시작 때 검증(`validateTelepathyBank`): 고유 id(`<분야>-NNN`), 알려진 분야, 보기 한국어만·14자 이내·서로 다름, 이모지, `spicy` = 매운맛 분야, 보기 쌍 중복 없음. 어기면 서버가 뜨지 않는다.
- 방별 가방 `telepathy:<room>:bag` (1년 보관) `{ order: [id...], recent: [최근 50개], refills }`.
  판 시작 때 가방 순서대로 꺼내되 **같은 분야는 판당 2문제까지**(남은 문제가 많은 분야부터 꺼내 분야별로 고르게 줄어든다). 15문제 + 매운맛 끄기처럼 분야가 모자라면 상한을 `ceil(문제 수 / 분야 수)`로 늘린다.
  매운맛 끄기면 매운맛 문제는 건너뛴다(가방에 남는다). 가방에서 다 못 채우면 **전체를 다시 섞되 최근 50개는 맨 뒤로** 보내고 이어서 꺼낸다.
  → 10문제 기준 매운맛 켜기 **32판**, 끄기 28판 동안 한 문제도 반복되지 않는다(테스트로 고정).

## 시작·재대결·복원

| 흐름 | 동작 |
|---|---|
| 로비 | `game:lobby:join` / `game:lobby:set_option`(`rounds`: 10\|5\|15, `spicy`: `'off'`\|`'on'`) / `game:lobby:start`, `gameType: 'telepathy'`. 서버가 판을 만들고(`metadata.serverStart = true`) `game:telepathy:state`를 보낸다. 첫 마감 = 로비 카운트다운 종료(`startsAt`) + 15초. 게임 화면에 시작 버튼 없음. |
| 재대결 | `game:restart:request` / `game:restart:respond` (`gameType: 'telepathy'`). 같은 두 사람·같은 문제 수·매운맛 설정으로 새 판(`gameId` 새로, 가방에서 새 문제). 시리즈는 이어진다. 첫 마감 = 지금 + 1.5초 + 15초. |
| 복원 | `session:restore` → 진행 중이면 그 소켓에 `game:telepathy:state`(내 이번 선택 `myPick` 포함), ack의 `restored`에 `'telepathy'`. 끝난 판도 상태는 보내지만 `restored`에는 넣지 않는다. 서버가 재시작돼 타이머가 없으면 다시 건다. |

## 재대결 동시 요청

두 사람이 거의 동시에 `game:restart:request`를 보내면(또는 상대 요청이 남아 있을 때 내가 요청하면) 서버가 **서로 동의한 것으로 보고** 바로 새 판을 시작한다(ack `{ ok: true, started: true }`).
새 판이 시작되면 방 전체에 `game:restart:started { gameType }`를 보내 열려 있는 재대결 창이 닫히게 한다(공용, 모든 재대결 게임).

## 클라이언트 → 서버

### `game:telepathy:sync` `{}`
화면이 열릴 때. ack `{ ok: true, state: TelepathyState | null }`, 같은 상태를 그 소켓에 `game:telepathy:state`로도 보낸다(`myPick` 포함).

### `game:telepathy:pick` `{ choice: 'A' | 'B', round?, gameId? }`
- `round`(선택): 지금 문제 번호(늦게 도착한 선택 방지). `gameId`(선택): 지금 판 id(지난 판 화면의 선택이 새 판에 섞이지 않게).
- ack:
  - `{ ok: true, round, choice }` — 받음
  - `{ ok: true, already: true, round, choice }` — 이번 문제에 이미 고름(덮어쓰지 않음, 처음 고른 값)
  - `{ ok: false, reason }` — `invalid_payload` · `stale_round`(+ `round`) · `stale_game`(+ `gameId`) · `no_game` · `not_a_player` · `game_over` · `not_joined`

## 서버 → 클라이언트

### `game:telepathy:state` (방 전체, 상태가 바뀔 때마다)

```jsonc
{
  "gameId": "uuid", "gameType": "telepathy",
  "status": "playing" | "finished",
  "players": ["User1Code", "User2Code"],
  "round": 3,                       // 지금 문제 번호(1부터)
  "rounds": 10,
  "spicy": false,
  "question": Question | null,      // 지금 문제(끝나면 null). 앞으로 나올 문제는 보내지 않는다
  "picked": { "<id>": true, "<id>": false },   // 값은 숨기고 고른 여부만("골랐어요")
  "timeouts": { "<id>": 0, "<id>": 1 },         // 연속 시간 초과 수
  "turnDeadline": 1730000000000 | null, "turnMs": 15000,
  "revealUntil": 1729999996500 | null, "revealMs": 3500,
  "score": 2, "streak": 1, "bestStreak": 2,
  "lastRound": RoundRecord | null,
  "history": [RoundRecord, ...],    // 지난 문제 전부(결과 화면의 문제별 요약)
  "result": null | {
    "reason": "complete" | "both_away" | "away",
    "awayPlayer": id | null,
    "matches": 8, "total": 10, "played": 10, "bestStreak": 4,
    "tier": { "id": "eyes", "label": "눈빛만 봐도" }
  },
  "series": { "games": 3, "matches": 21, "questions": 30, "ratio": 70,
              "bestStreak": 5, "bestMatches": 9, "recent": [{ "matches": 7, "total": 10 }] },
  "serverNow": 1729999990000,       // 기기 시계 보정용
  "myPick": "A"                     // sync·복원 응답에서만, 보는 사람 자신의 이번 선택
}
```

`Question` = `{ id, cat, a, b, emojiA, emojiB, spicy }`.

`RoundRecord` = `{ round, question: Question, picks: { "<id>": "A"|"B"|null }, matched, outcome: "match"|"miss"|"timeout", streak, score }`.
새 `lastRound.round`가 오면 클라이언트는 두 카드를 함께 뒤집어 공개하고(`revealMs` 동안), 끝나면 `question`(다음 문제)을 보여 준다.

## Redis 키

| 키 | 내용 | 보관 |
|---|---|---|
| `game:<room>:telepathy` | 판 상태(문제 목록·선택 포함) | 1시간 |
| `telepathy:<room>:bag` | 셔플 가방 | 1년 |
| `telepathy:<room>:series` | 방 시리즈 | 6시간 |
| `telepathy:<room>:last` | 재대결용 설정(두 사람·문제 수·매운맛) | 6시간 |
