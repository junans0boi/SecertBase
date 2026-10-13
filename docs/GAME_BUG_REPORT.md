# 게임 버그 리포트

> 마지막 업데이트: 2026-10-13 (코드 직접 확인 버전)
> 게임 14종 · 버그 26개

---

## 심각도 기준

| 심각도 | 기준 |
|--------|------|
| 🚨🚨 긴급 | 게임 진행 불가 수준의 버그 |
| 🚨 높음 | 보안/조작 가능, 핵심 로직 파손, UI 깨짐 |
| ⚠️ 보통 | UX 저하, 마이너 버그 |

---

## 🚨🚨 긴급

### 폭탄 돌리기 (`game:bomb:*`)

#### 1. 재접속 시 필드명 불일치 + 문제(question) 미포함
- **파일**: `services/realtime-server/src/socket.js` lines 1015–1018
- **문제 코드**:
  ```js
  activeGames.bomb = {
    currentPlayer: game.currentPlayer,
    timer: remaining,                     // "timer" ≠ "duration" (started 이벤트 키)
    category: game.currentQuiz?.category, // question 텍스트 자체가 없음
  };
  ```
  `game:bomb:started`는 `{ duration, startTime, quiz: { category, question } }` 형태로 보내는데, `session:restore`는 `{ timer, category }`만 전송. 문제 텍스트가 복원 안 됨.
- **Flutter 측**: `socket_service.dart` lines 2196–2202 `_restoreGames`에서 `bomb['timer']` → `bombDuration`은 읽히지만 `bombQuestion`, `bombCategory`는 null 유지.
- **서버 수정**: line 1017에 `question: game.currentQuiz?.question` 추가.
- **Flutter 수정** (`socket_service.dart` ~line 2200):
  ```dart
  bombQuestion = bomb['question'] as String?;
  bombCategory = bomb['category'] as String?;
  ```

#### 2. 타임아웃 시 XP 미지급 + 결과 미처리
- **파일**: `services/realtime-server/src/socket.js` line 3475
- **문제**: 서버 측 독립 타이머가 없음. 양쪽이 응답을 안 하면 Redis 키가 300초 후 만료되는데, 이때 `saveGameResult`도 `grantGameXpAndMissions`도 호출되지 않음. 승자 broadcast도 없음.
  - 답변 제출 시 time-up 체크는 있음 (line 3530) — 하지만 무응답 만료 경로는 완전히 미처리.
- **수정**: line 3475 `redis.set` 이후 `setTimeout`을 `(gameState.duration + 여유시간)`으로 걸어서, 만료 시 게임 상태 조회 → 진행 중이면 `game:bomb:exploded` emit + 결과 저장.

---

## 🚨 높음

### 그림 맞히기 (`game:catch:*`)

#### 1. timeout / next / reset 권한 없음
- **문제**: 출제자·진행자가 아닌 누구나 라운드를 강제 종료하거나 단어를 넘기고 게임을 리셋할 수 있음.
- **수정**: `socket.js` catch 핸들러에서 호출자 `socket.userId`가 현재 게임의 출제자 또는 호스트인지 검증하는 가드 추가. 불일치 시 에러 emit.

#### 2. draw relay 미검증
- **문제**: 클라이언트가 보내는 드로잉 stroke 데이터를 서버가 검증 없이 상대방에게 그대로 중계.
- **수정**: emit 전 stroke 데이터 스키마 최소 검증 (숫자 범위, 배열 길이 상한). 발신자가 출제자가 맞는지 확인.

#### 3. 게임 종료 시 XP 미지급
- **수정**: 정답 처리 분기에 `grantXp` 호출 추가.

---

### 패널티킥 (`game:penalty:*`)

#### 1. allSubmitted 로직 버그 → 방향 노출
- **파일**: `services/realtime-server/src/socket.js` lines 2734–2741
- **문제 코드**:
  ```js
  const allSubmitted = Object.keys(nextGameState.submissions).length >= 2;
  ```
  `resolvePenaltyRound`가 호출되면 `nextGameState.submissions`는 이미 `{}`가 됨 → `allSubmitted` 항상 `false` → "두 선택 보여주기" 분기는 dead code.
  
  실제 방향 노출 경로: `rounds` 배열에 `{ kickerDir, keeperDir, isGoal }` 포함되어 있고, `nextGameState` 전체가 `emitState`에 spread되어 양쪽에 전송됨.
- **수정**:
  ```js
  // resolvePenaltyRound 호출 전에 체크
  const allSubmitted = gameState.submissions[kickerId] !== undefined &&
                       gameState.submissions[keeperId] !== undefined;
  ```
  `rounds` 항목에서 `status !== 'finished'`일 때 `kickerDir`/`keeperDir` 제거 후 emit.

#### 2. 게임 종료 시 XP 미지급
- **문제**: `nextGameState.result.winner !== 'draw'` 조건 — 동점 종료 시 양쪽 모두 XP 없음.
- **수정**: 게임 종료 분기에 `grantXp` 호출 추가. 무승부도 참여 XP 지급 검토.

---

### 텔레파시 (`game:telepathy:*`)

#### 1. 두 번째 플레이어가 options 덮어쓰기 가능
- **파일**: `services/realtime-server/src/socket.js` lines 1430–1433
- **문제 코드**:
  ```js
  if (!sameOptions) session = null;   // sessionId 없이 다른 options 보내면 기존 세션 초기화
  ```
  sessionId 없이 다른 options를 보내면 이미 1번 플레이어의 선택이 저장된 세션이 null로 초기화됨. 2번 플레이어가 정답이 포함된 options로 게임 조작 가능.
- **수정**:
  ```js
  if (session && !session.revealed && !session.expired && !sameOptions) {
    return ack({ ok: false, reason: "invalid_options" });
  }
  ```

#### 2. 만료된 세션이 null 처리 안 됨 → 게임 stuck
- **파일**: `services/realtime-server/src/socket.js` line 1461
- **문제**: 60초 타이머 만료 후 `session.expired = true` 저장됨. 이후 플레이어가 제출하면 만료된 세션에 저장은 되지만 `!session.expired = false`라서 재스케줄이 안 됨. 두 번째 플레이어가 응답 안 하면 영구 stuck.
- **수정**: session 재사용 전 만료 세션 null 처리:
  ```js
  if (session?.expired) session = null;
  ```

---

### 해적 룰렛 (`game:pirate:*`)

> ⚠️ 정정: `game:pirate:reset`은 `game.players.includes(userId)` 체크가 **이미 구현됨**. 권한 없음 버그는 없음.

#### 1. 재접속 시 pickedSlots Flutter에서 무시
- **파일**: `apps/secret_base_app/lib/core/socket_service.dart` line 688
- **문제 코드**:
  ```dart
  piratePickedSlots = [];  // 항상 빈 리스트 — map['pickedSlots'] 무시
  ```
  서버는 `pickedSlots`를 reconnect emit에 포함하지만 Flutter가 읽지 않음. 재접속 후 이미 선택된 슬롯들이 UI에서 미선택으로 보임.
- **수정**:
  ```dart
  final rawSlots = map['pickedSlots'];
  piratePickedSlots = rawSlots is List
      ? rawSlots.map((e) => (e as num).toInt()).toList()
      : [];
  ```

---

### 탱크 대작전 (`game:tank:*`)

#### 1. game:tank:move가 상대에게 angle/power 노출
- **파일**: `services/realtime-server/src/socket.js` line 4044
- **문제 코드**:
  ```js
  io.to(roomCode).emit("game:tank:updated", result.state);  // 전체 state 브로드캐스트
  ```
  `game:tank:weapon`은 per-socket 마스킹을 하지만 (`angle: undefined, power: undefined`), `game:tank:move`는 full state를 그대로 전송.
- **수정**: `game:tank:weapon`의 per-socket 루프 패턴을 `game:tank:move`에도 동일하게 적용.

#### 2. 상호전멸 시 Flutter UI에서 둘 다 "패배" 표시
- **파일**: `apps/secret_base_app/lib/screens/arcade/games/tank_screen.dart` lines 263–264
- **문제 코드**:
  ```dart
  final isWin = winner == _socket.userId;  // winner=='draw'이면 양쪽 false → "패배"
  ```
  서버는 `winner: 'draw'`를 정상 emit함. Flutter가 draw 케이스를 처리 안 함.
- **수정**:
  ```dart
  if (winner == 'draw') { /* 무승부 오버레이 표시 */ return ...; }
  ```

---

### 윷놀이 (`game:yut:*`)

#### 1. caughtOpponentThisTurn 리셋 누락 → 추가 턴 오귀속
- **문제**: `caughtOpponentThisTurn` 플래그가 턴 전환 시 초기화되지 않음.
- **수정**: `yut-engine.js` 턴 전환 함수에서 `caughtOpponentThisTurn = false` 리셋 추가.

#### 2. 게임 참가자 검증 미흡
- **수정**: yut 이벤트 핸들러 앞단에 `game.players.includes(socket.userId)` 가드 추가.

---

### 마블 작전 (`game:marble:*`)

#### 1. winReason 코드 불일치 → 독점 승리 UI 깨짐
- **문제**: 서버 `winReason` 값과 Flutter `marble_screen.dart` 처리 분기 키가 다름.
- **수정**: `marble-engine.js`와 `marble_screen.dart` winReason 상수 맞춤.

#### 2. HUD 자산 계산 오류
- **수정**: `marble_screen.dart` HUD 계산 로직 재검토, 서버 emit 값 직접 사용 고려.

#### 3. 감옥(jail) / 입구(gate) 칸 미구현
- **수정**: `marble-engine.js` `landAct`에 jail(턴 스킵), gate 처리 추가.

---

### 원카드 (`game:uno:*`)

> ⚠️ 정정: Wild 색상 선언은 이미 검증됨 (lines 2932–2935, Zod schema line 308).

#### 1. drawStack 미클리어 → 뽑은 카드 플레이 불가
- **파일**: `services/realtime-server/src/socket.js` lines 3333–3348
- **문제 코드**:
  ```js
  const drawnCardIsPlayable = canPlayCard(drawnCard, topCard, declaredColor,
    0,    // ← drawStack을 0으로 체크하지만 실제 state는 그대로
    null, { mode }
  );
  if (drawnCardIsPlayable) {
    gameState.drawnCardId = drawnCard.id;
    // clearDrawStack 호출 없음!
  }
  ```
  카드 플레이 가능성을 `drawStack=0` 기준으로 판단하지만 실제 state의 `drawStack`은 그대로 남음. 이후 `game:uno:play` 시 `hasStack=true`라서 "must_draw_or_defend" 에러 발생 → 이미 패널티 draw를 완료했는데 카드를 낼 수 없음.
- **수정**: `drawnCardIsPlayable = true` 분기에 `clearDrawStack(gameState)` 추가:
  ```js
  if (drawnCardIsPlayable) {
    gameState.drawnCardId = drawnCard.id;
    clearDrawStack(gameState);  // 추가
  }
  ```

---

### 룰렛 (`game:roulette:*`)

#### 1. Flutter가 propose 미호출 → 상대 options 항상 무시
- **파일**: `apps/secret_base_app/lib/screens/arcade/games/roulette_screen.dart` line 74  
  `apps/secret_base_app/lib/core/socket_service.dart` lines 1701–1702
- **문제**: Flutter는 `game:roulette:spin`만 호출하고 `game:roulette:propose`를 전혀 호출하지 않음. 서버는 `proposals`를 merge하는데, propose 없이 spin만 오면 spinner의 options만 사용됨. 상대의 options는 무조건 무시.
- **수정**: `roulette_screen.dart` 화면 진입 시 및 `_options` 변경 시 `game:roulette:propose` emit 추가:
  ```dart
  _socket?.emit('game:roulette:propose', {'options': _options});
  ```

---

## ⚠️ 보통

### 블랙잭 (`game:blackjack:*`)

#### 1. next_round 레이스 컨디션
- **문제**: `game:blackjack:next_round`가 동시에 오면 라운드 중복 시작.
- **수정**: Redis SET NX로 처리 중 플래그 원자적 획득, 또는 in-flight 플래그로 중복 요청 무시.

---

### 고스톱 (`game:gostop:*`)

#### 1. 양방향 흔들기 UI 불명확
- **수정**: 흔들기 선언자/수락자 UI 분리. 선언자 "흔들기 선언 완료", 상대 "상대가 흔들기를 선언했어요".

#### 2. 덱 소진 + 상대 7점 동시 케이스 미처리
- **수정**: `gostop-engine.js` 덱 소진 분기에 점수 기준 자동 종료 조건 추가.

---

### 볼링 (`game:bowling:*`)

#### 1. 서버에서 pins 미검증 — 클라이언트 조작 가능
- **수정**: pins 값 범위(0–10) 검증 + 이전 프레임 핀 수와 정합성 체크. 또는 서버 독립 계산.

---

### 주사위 (`game:dice:*`)

#### 1. 로컬/서버 타이밍 불일치
- **수정**: 서버 결과 수신 후 최소 N초 애니메이션 재생 보장, 또는 고정 딜레이 방식 통일.

---

## 수정 우선순위 요약

| 순위 | 게임 | 수정 파일 | 핵심 작업 |
|------|------|-----------|-----------|
| 1 | 폭탄 돌리기 | `socket.js` | 타임아웃 setTimeout + question 복원 |
| 2 | 패널티킥 | `socket.js` | allSubmitted 순서 수정 + rounds 마스킹 |
| 3 | 텔레파시 | `socket.js` | options 재사용 가드 + 만료 세션 null 처리 |
| 4 | 탱크 대작전 | `socket.js`, `tank_screen.dart` | move 마스킹 + draw UI |
| 5 | 원카드 | `socket.js` | clearDrawStack 추가 (1줄) |
| 6 | 룰렛 | `roulette_screen.dart` | propose emit 추가 |
| 7 | 해적 룰렛 | `socket_service.dart` | pickedSlots 복원 |
| 8 | 그림 맞히기 | `socket.js` | 권한 가드 |
| 9 | 윷놀이 | `yut-engine.js` | 플래그 리셋 |
| 10 | 마블 | `marble-engine.js`, `marble_screen.dart` | winReason 맞춤 |
