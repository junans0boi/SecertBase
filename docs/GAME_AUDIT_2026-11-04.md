# 게임 전체 코드 감사 (2026-11-04)

> 범위: 아케이드 게임 16종 + 공통 인프라 (MomentLoop·비밀지도·운세·사주 제외)
> 기준: `main` @ 399a86c. 코드를 직접 읽고 추적한 결과이며, 기존 `GAME_BUG_REPORT.md`(10/13)는 이후 수정이 반영되지 않아 **더 이상 정확하지 않음**.
> 표기: ✅ = 리드가 직접 코드 재확인 / [C] = 리뷰어가 코드 경로 추적 확인 / [S] = 의심(런타임 확인 필요)
> 참고: 이 머신에 Node가 설치되어 있지 않아 서버 테스트는 실행하지 못함.

## 0. 정비 결과 (같은 날, 브랜치 `feat/game-overhaul`)

> Spec #177 · Wayfinder Map #179 · 티켓 #180–#200. 계획 문서: `docs/plans/game-overhaul-2026-11/`.

**해결**

| 영역 | 항목 |
|---|---|
| 공통 | P0-1 서버 권위 판돈 + 비방장 준비 완료 / P0-2 재시작 검증 + 마블·탱크 재시작 / P0-4 gameId 멱등 정산 + 정산 후 삭제 / P0-5 핸들러 예외 안전망 / P1-1 방장 권한 제거(그림 맞히기·가위바위보) / P1-2 거부 사유 안내 / P1-3 비재개형 복원·이어하기 + 유령 게임 정리 + 폭탄 문제 복원 / P1-4 무승부 기록·XP, 가위바위보 기록, 기록 카드 정리 / 이어하기 90초 유예 |
| 고스톱 | 폭탄 후 진행 정지, 고 반복, 피 뺏기, 초단, 4광, 이벤트 안내, 2장 매칭 편향 |
| 원카드 | 벌칙 후 스택 잔존, 재드로우, 도전 후 정리, 뽑은 카드 노출 |
| 도둑잡기 | 위치 별칭으로 조커 노출 차단 |
| 볼링 | 서버 결정론 시뮬레이션 + 손 떨림, 결과 수신 후 연출, 10프레임 표기·누적 점수 |
| 마블 | 1-based 레벨, 파산 판정, 무승부 후 칸 효과, 통행료 감소 스탯, 감옥·게이트, 관광지 0원 업그레이드, 3연속 더블 라운드, 이전 판 결과 창, 캐릭터 검증 |
| 윷 | 빽도 소프트락·성급한 낙, 잡기 보너스 순서 의존, 완주 말 잡기 |
| 그림 맞히기 | 서버 마감 시각, 종료 시 키 삭제, 힌트 1회, stroke 검증·속도 제한, 추측 길이, 이어하기 |
| 가위바위보 | 끊김 시 부당 취소 + 클라이언트 리스너, 리셋 권한, 이어하기 |
| 패널티킥 | 서든데스(최대 5쌍), 중복 제출, 무승부 기록 |
| 텔레파시 | 다른 문제로 답할 때 상대 답 보존 + 같은 문제로 이동 |
| 해적 | pickedSlots 복원, 서버 배열 사용, 폭발 연출 재생 |
| 폭탄(비노출) | 서버 타이머 폭발, 복원 시 문제 포함, 답 길이 제한 |
| 탱크 | **2.0 업그레이드**(전차 4종·무기 9종·보급·낙하·경사·테마 4종·30초 서버 턴 타이머·AFK 기권·서든데스·통계·재대결·마스킹·연출) |

**범위 밖으로 남긴 것**: 탱크 외 게임의 서버 턴 타이머/AFK 기권, socket.js·SocketService 분리(Phase 4), 모바일 오디오, 고스톱 2장 매칭 선택 UI·첫뻑·3뻑, 폭탄·룰렛 재노출과 룰렛 휠 정합, 윷 캐릭터 선택 연결, Redis 어댑터.

---

## 1. 전체 구조

### 1.1 레이어

```
Flutter
  ArcadeScreen (_games 목록, 기록/지갑)  ─┐
  push_game_route (푸시 초대 진입)        ├─> GameLobbyScreen ──(5초 카운트다운 후 방장 클라가 game:X:new emit)──> 각 게임 Screen
                                          ┘                                                  │
  SocketService (싱글턴 ChangeNotifier, 2446줄 / 필드 ~170 / notifyListeners 107곳) <────────────┘
  GameSessionPresence (yut/marble/uno/gostop만 game:session:enter/leave)
  GameMenu / GameMenuListener (나가기·재시작·상대 이탈 다이얼로그)

Node (realtime-server)
  socket.js (4443줄) ── 로비/세션/재시작/16개 게임 핸들러 전부 한 파일
  game-session.js ── 뷰어 룸 추적, 이어하기, 마지막 뷰어 이탈 시 Redis 삭제 (4종만)
  *-engine.js ── 게임 규칙 (rps/telepathy/bomb/penalty는 아주 얇음, pirate/dice/roulette/catch는 socket.js 인라인)
  wallet-engine.js ── transferGameReward (올인 캡, gameRef 멱등성 체크)
  level-engine.js ── XP / 미션
  Redis ── 게임 상태 (키별 TTL)   MySQL ── game_results, wallets, wallet_transactions, missions
  락 ── withRoomLock / withLobbyLock (프로세스 메모리, 단일 인스턴스 전제)
```

### 1.2 게임별 현황표

| 게임 | 서버 규칙 위치 | 상태 저장 (TTL) | 재접속 복원 | 판돈 실제 정산 | 결과·XP | 서버 턴타이머 |
|---|---|---|---|---|---|---|
| 윷놀이 | yut-engine | Redis 1h | O | O (ref=Date.now) | O | X |
| 마블 | marble-engine | Redis 2h | O | **X (UI만 있음)** | O | X |
| 원카드 | uno-engine | Redis 1h | O | O (ref=Date.now) | O | X (클라 15초만) |
| 고스톱 | gostop-engine | Redis 2h | O | O (gameId 안정, pending 재시도) | O | X |
| 블랙잭 | blackjack-engine | Redis 1h | X | X | 승자만 | X |
| 도둑잡기 | oldmaid-engine | Redis | X | X | O | X |
| 패널티킥 | penalty-engine | Redis | X | X | 승자만 | X |
| 볼링 | bowling-engine | Redis 1h | X | X | 승자만 | X |
| 탱크 | fortress-engine | Redis 2h | X | O (정산 전 삭제) | 승자만 | X |
| 가위바위보 / 제로 | rps-engine + 인라인 | Redis 10m | X | X | **X** | X |
| 텔레파시 | telepathy-engine | Redis + 메모리 타이머 | 타이머만 | X | **X** | O (60초) |
| 해적 룰렛 | 인라인 | Redis 30m | join 시 (Flutter가 일부 무시) | X | O | X |
| 그림 맞히기 | 인라인 + catch_words | Redis **24h** | X | X | 승자만 | X (방장 클라) |
| 주사위 | 인라인 | room state | – | X | X | – |
| 룰렛 | 인라인 | – | – | X | X | – |
| 폭탄 돌리기 | bomb-engine | Redis 5m | 부분 (문제 누락) | X | O | **없음** |

> 룰렛·폭탄은 `ArcadeScreen._games`에 없어서 **아케이드에서 진입할 수 없음** ✅. 폭탄은 서버 로비 `gameTypes`에도 없음. `push_game_route.dart`에만 남아 있는 반쯤 지워진 상태임.

---

## 2. 공통(구조적) 결함 — 여러 게임에 동시에 영향

### P0-1. 판돈을 클라이언트가 정하고, 상대 동의 절차가 없음 ✅
- `game:yut:new` / `game:uno:new` / `game:tank:new` / `game:gostop:new`가 **payload에 담긴 stake를 그대로 사용**함 (socket.js:1653, 2846, 4016, 4231~). 로비에서 합의한 `lobby.stake`와 대조하지 않고, 호출자가 방장인지도 확인하지 않음.
- 로비가 시작되면 서버는 로비를 지우고(socket.js:935), **방장 클라이언트가 300ms 뒤에** `new`를 보내는 구조임 (game_lobby_screen.dart:110). 조작한 클라이언트는 로비를 거치지 않고 최대 10000을 걸 수 있음.
- 윷 보드의 "실전형 윷놀이 시작" 버튼은 초기화되지 않은 `lobbyStartedStake`를 재사용함 → 한쪽 혼자서 판돈 걸린 새 판을 열 수 있음 [C].
- 판돈 선택 UI는 **모든 게임**에 노출되지만(game_lobby_screen.dart:274), 실제로 정산하는 게임은 윷·원카드·탱크·고스톱 4개뿐임 ✅. 마블·블랙잭·볼링 등은 "3000코인"을 골라도 아무 일도 일어나지 않음.
- **수정 방향**: 서버가 `lobby:start` 시점에 `{gameType, stake, players, host, gameId}`를 Redis에 "pending game"으로 저장하고, `new`는 그 값만 사용. 판돈을 쓰지 않는 게임에서는 판돈 UI를 숨김. 판돈이 0보다 크면 상대가 "수락"을 눌러야 시작.

### P0-2. `game:restart:respond` 무검증 ✅
- 대기 중인 재시작 요청이 있는지, 응답자가 요청자의 상대인지 확인하지 않고, 락도 잡지 않음 (socket.js:3574~). `{accept:true, gameType:'yut'|'uno'}`만 보내면 **지고 있는 판을 정산 없이 덮어쓸 수 있음**.
- 마블 화면은 재시작을 요청하지만(marble_screen.dart:340) 서버에 마블 분기가 없음 → `accepted:true`만 돌려주고 아무 일도 하지 않음 ✅.
- **수정**: `restart:request` 때 Redis에 `{by, gameType, expiresAt}`를 저장하고, `respond` 시 검증. 처리는 `withRoomLock` 안에서. 지원 게임 목록을 명시.

### P0-3. 이탈 / AFK / 기권 처리가 전혀 없음
- 모든 게임에 서버 턴 타이머가 없음 (텔레파시만 예외). 상대가 앱을 꺼버리면 남은 사람은 **영구 대기**함.
- 이어하기 4종(윷/마블/원카드/고스톱)은 **보는 사람이 0명이 되는 즉시 Redis 삭제** (game-session.js:129, 유예 시간 없음) ✅. 둘이 동시에 백그라운드로 가면 진행 중인 판이 증발하고, 지는 쪽은 나가버려서 정산을 피할 수 있음.
- 나머지 9종은 정리 경로가 없음. 한 명이 나가면 상태가 TTL 동안 남아 `game_in_progress`로 새 게임이 막힘 (블랙잭·패널티·볼링 1시간, 탱크 2시간, **그림 맞히기 24시간**) [C]. 시작 emit에는 ack가 없어서 사용자는 "버튼이 안 먹는" 상태로만 경험함.
- **수정**: 공통 세션 레이어(§5 Phase 2)에 `turnDeadline`, 이탈 시 N초 유예 후 기권승 처리, 유예 시간이 있는 정리를 넣음.

### P0-4. 정산 신뢰성 (윷·원카드·탱크)
- `transferGameReward`는 gameRef 멱등성 체크와 DB UNIQUE 제약(0022 마이그레이션)을 갖추고 있음. 그런데 호출부가 `` `yut:${roomCode}:${Date.now()}` `` 형태로 **매번 새 ref를 만들어서 멱등성이 무력화됨** ✅ (socket.js:1985, 3067, 4134).
- 순서도 "Redis 키 삭제 → 정산"이고, `settleAndEmitWallet`은 오류를 삼킴 (socket.js:414) → 정산이 실패하면 복구할 수 없음.
- 고스톱만 안정적인 `gameId`와 `settlementStatus:'pending'` 재시도를 갖춤 (socket.js:4163~) ✅. **이 패턴을 공통화하면 됨.**

### P0-5. 서버 프로세스 안정성 ✅
- `process.on('unhandledRejection')`가 src 어디에도 없음. 그런데 윷 핸들러 등에서 try/catch 없는 `await query()`가 다수 있음 → DB 오류 한 번이면 Node 프로세스가 종료될 수 있음 [C].
- 락(`roomLocks`, `_lobbyLocks`)과 타이머(텔레파시, 윷·마블 순서 카운트다운 `setTimeout`)가 메모리에만 있음. 카운트다운 3초 사이에 서버가 재시작되면 `order_countdown` 상태에서 영구히 멈춤 [C]. 서버를 여러 대로 늘리는 순간 직렬화가 깨짐.

### P1-1. 방장 정의가 두 갈래
- 서버는 `getOrderedPlayers()[0]` (= Couples.User1) 또는 `Object.keys(scores)[0]`을 방장으로 봄. Flutter는 `lobbyHost`(로비를 먼저 연 사람)를 방장으로 봄 ✅.
- 그림 맞히기는 User2가 로비를 열면 **1라운드 이후 진행이 불가능**함. 가위바위보도 reset이 거부됨 [C].
- **수정**: 서버가 게임 상태에 `host`를 넣어 내려주고, Flutter는 그 값만 사용.

### P1-2. Fire-and-forget emit + 낙관적 로컬 리셋
- 거의 모든 게임 액션 emit이 ack를 확인하지 않음 (socket_service.dart 전반). 서버가 거부해도 UI가 모르고 멈춰 있음.
- reset 계열은 서버 응답 전에 로컬 상태부터 지워서 화면과 서버가 어긋남 (rps / catch).
- **수정**: `emitWithAck` 래퍼를 두고 `{ok:false, reason}`이면 토스트를 띄우고 로컬 상태를 롤백. 이렇게 하면 원카드 진행 정지 같은 증상도 최소한 사용자에게 드러남.

### P1-3. 재접속 복원 불완전 ✅
- `session:restore`는 윷/원카드/고스톱/폭탄/마블만 처리함. 블랙잭·도둑잡기·볼링·패널티·탱크·가위바위보·그림 맞히기는 복원되지 않아 "내 턴인데 상대 턴으로 굳는" 교착이 생김.
- `_restoreGames`(socket_service.dart:2156)는 **응답에 없는 게임을 비활성으로 바꾸지 않음**. 끊긴 동안 끝난 게임이 `yutActive=true`로 남아, 아케이드에서 누르면 유령 게임 화면으로 들어감.
- 폭탄 복원에는 문제 텍스트가 없음 (socket.js:1015, 기존 리포트 #1 아직 남아 있음). 회귀 테스트가 오히려 이 버그 상태를 정답으로 고정하고 있음 (socket-game-regression.test.js:292).

### P1-4. 결과 / XP / 기록
- `game_results` 스키마가 `winner/loser NOT NULL`이라 무승부를 저장할 수 없고, ref UNIQUE도 없음 → 무승부 판은 기록도 XP도 없음 (블랙잭·패널티·볼링·탱크·그림 맞히기).
- 가위바위보·제로·텔레파시는 결과/XP 호출 자체가 없음 ✅. 그런데 아케이드 "기록" 카드는 이 게임들에도 노출되어 항상 "아직 플레이 기록이 없어요"로 보임.
- XP는 게임과 무관하게 승 50 / 패 20 고정이라, 몇 초면 끝나는 해적 룰렛으로 달성 미션(50판 → 2000코인)을 쉽게 파밍할 수 있음.

### P2. 구조 / 품질
- **socket.js 4443줄**에 16개 게임이 섞여 있음. 이미 `modules/moment-loop` 같은 모듈 패턴이 있으니, 게임별로 `modules/games/<game>/`로 분리하는 게 좋음.
- **SocketService 갓 객체**: 어떤 게임 이벤트든 `notifyListeners()` 하나로 모든 화면(아케이드 포함)이 리빌드됨. 게임별 `ChangeNotifier`(또는 `ValueNotifier`)로 분리 권장.
- 대형 위젯: yut_board 3524줄, marble_board 3294줄, rps_screen 2035줄, uno_board 2011줄 (build 메서드 하나가 400~560줄).
- **모바일에서 사운드 없음** ✅: `yut_audio`와 `uno_audio`가 `dart.library.html`일 때만 실제 구현을 쓰고, iOS/Android에서는 stub임.
- 출석 보너스: 서버는 UTC 날짜, 클라이언트는 로컬 날짜로 판단 → KST 기준 오전 9시에 리셋됨.
- 아케이드 기록은 initState에서 한 번만 불러옴 (게임 후 갱신 안 됨).

---

## 3. 게임별 주요 결함

### 고스톱
| 심각도 | 내용 | 위치 |
|---|---|---|
| 치명 ✅ | **폭탄 후 손패가 먼저 바닥난 쪽에도 턴이 넘어감** → `card not in hand`만 반복되며 게임 정지. 폭탄피(더미 턴)가 없음 | gostop-engine.js:443, 474 |
| 높음 ✅ | 7점 이상이면 **점수가 늘지 않아도 매 턴 고 선택**이 가능하고, 고마다 ×2 → 정산액을 무한히 부풀릴 수 있음 (올인 캡까지) | gostop-engine.js:457, 633 |
| 높음 [C] | 바닥에 같은 월이 2장일 때 손패를 내면 선택 없이 3장을 모두 가져감 (스펙과 다름, 따닥 라벨 오표시) | :509-513 |
| 보통 [C] | 고 보너스 공식이 스펙("2고 = +2점")과 다름. 1고부터 ×2 | :631 |
| 보통 [C] | `_nextTurn`이 `lastEvents`를 비워서 쪽/뻑/폭탄 토스트가 일반 턴에 거의 안 보임 | :481 |
| 미구현 | 쪽/따닥/뻑/판쓸이/폭탄의 **피 뺏기 전혀 없음**(코치 문구는 "보너스 얻음"), 초단 없음, 첫뻑·3뻑 없음 | |
| 낮음 | 4광·5광에도 비광 감점 적용(테스트가 이 값을 고정), 판쓸이 판정이 너무 이름, `game:gostop:state`가 락 밖에서 결과를 처리 | |

### 원카드
| 심각도 | 내용 | 위치 |
|---|---|---|
| 높음 ✅ | +2/+4 패널티로 받은 뒤 **마지막 장이 낼 수 있는 카드면 공격 스택이 남음** → "내기"를 누르면 `must_draw_or_defend`로 거부되고 ack가 없어 진행 정지. 그 카드가 +2면 스택이 2배가 됨 | socket.js:3342 |
| 보통 [C] | draw 핸들러에 `drawnCardId` 검사가 없어 선택 대기 중에 다시 draw하면 스택만큼 또 뽑음 / challenge가 `drawnCardId`를 지우지 않아 상대의 play가 막힘 | :3293, :3205 |
| 보통 [C] | 복원 시 상대의 `drawnCardId`(예: `wild_draw4-1`)가 노출되어 뽑은 카드가 드러남 | :997, game-session.js:46 |
| 낮음 | 도전 성공 후 `unoCallNeeded`가 남음, Discard All 묶음의 skip이 짝수 장이면 상쇄됨, 턴 타이머가 skip/reverse 후 리셋되지 않음, 하드코딩된 `currentUser='jun'` | |

### 도둑잡기
- **치명 ✅**: 상대 손패를 `{id}`로만 가리지만, **id가 `card_0…card_51`(♠A부터 순서대로) / `card_joker`로 고정**되어 있음 (oldmaid-engine.js:11,21). 패킷만 보면 조커 위치와 모든 카드를 알 수 있음. → 게임마다, 보는 사람마다 무작위 별칭 id를 써야 함.

### 볼링
- **높음 ✅**: 서버는 `Math.random()`으로 핀 수를 정하는데(socket.js:2793), 클라이언트는 자체 결정론적 시뮬레이션으로 스트라이크 연출을 먼저 보여줌 → "스트라이크 연출인데 점수는 3"처럼 거의 매 투구가 어긋남.
- **보통 ✅**: 조준 0 / 커브 0이 항상 최적이고, 그때 핀 수는 0~10 균등 분포라 실력 요소가 없음.
- **수정**: 서버가 `seed`(또는 물리 파라미터)를 정해 클라이언트에 주고, 양쪽이 같은 시뮬레이션을 돌리거나 서버 결과를 받은 뒤 연출.
- 낮음: 10프레임 3구 표기 오류 (7/3 다음 7이 '/'로 표시), 스트라이크 직후 누적 점수를 미리 표시.

### 마블
| 심각도 | 내용 |
|---|---|
| 높음 ✅ | **땅 레벨 off-by-one**: 땅을 사면 `level:1`로 저장되는데(socket.js:2414), 통행료·인수가·점수 계산은 0을 땅으로 봄(marble-engine.js:128). 땅만 산 칸에서 집 통행료가 나가고, 랜드마크 업그레이드는 통행료가 오르지 않는 순손실. **테스트가 틀린 값을 정답으로 고정**하고 있음 |
| 보통 [C] | 보유금과 정확히 같은 금액으로 사면 잔액 0 → 즉시 파산 패배 (`coins<=0`) |
| 보통 [C] | `timeout_draw` 이후에도 세금·카드·통행료가 처리되고 `land_prompt`까지 뜸 |
| 보통 [C] | 통행료 감소 스탯이 항상 0 (`equippedItems[opp].stats` — 실제 구조는 슬롯별 맵), `piece_skin`도 항상 base |
| 보통 [C] | 다음 판을 시작하면 이전 판 결과 창이 다시 뜸 (`marbleWinner` 미초기화) |
| 보통 ✅ | 재시작 미구현 (P0-2), 판돈 미적용 (P0-1) |
| 미구현 [C] | **감옥(6) / 게이트(18) 칸이 서버에 없음** (상태 필드만 초기화). 카드 'teleport'는 위치만 바꾸고 칸 처리를 하지 않음 |
| 보안 [C] | `payload.characters`를 검증 없이 저장, 유료 캐릭터 소유 여부 확인 없음 |
| UX | 결과 문구는 "20라운드"인데 실제는 30, 색 그룹 라벨 오류, 종료 후 최종 보드 대신 "시작" 버튼, `finalScores`가 코인 칸을 덮어씀 |

### 윷놀이
| 심각도 | 내용 |
|---|---|
| 높음 ✅ | **빽도 낙 판정을 던질 때만 함** (socket.js:1812). `[4, 빽도]` 상태에서 4로 마지막 말을 완주시키면 빽도만 남고 움직일 말이 없는데 건너뛰기 수단이 없어 게임 정지. 반대로 모든 말이 출발점일 때는 빽도를 너무 일찍 버림 |
| 높음 [C] | 잡았을 때의 추가 던지기 횟수가 조작 순서에 따라 1번 또는 2번 (테스트가 한쪽 동작을 고정) |
| 보통~높음 [C] | 완주하는 말이 참먹이(20)에 있는 상대 말을 잡고 추가 던지기까지 얻음 |
| 보통 [C] | 같은 사람이 연속으로 이기면 결과 다이얼로그가 안 뜸, 던지기 버튼 연타로 보너스 던지기 소비, 빽도 막대가 모처럼 그려짐 |
| 미구현 [C] | 로비 캐릭터 선택이 연결되지 않음 → 둘 다 홍길동, 채팅 시트는 p2를 미호로 표시 |

### 그림 맞히기
- **치명 ✅**: 방장 불일치(P1-1)로 진행이 불가능함.
- **높음 [C]**: 게임이 끝나도 키를 지우지 않음 (TTL 24시간). 앱을 다시 켜면 시작이 `game_in_progress`로 막히는데 리셋 버튼도 없음.
- **보통 [C]**:
  - 라운드 타이머가 방장 클라이언트에만 있음
  - 출제자가 앱을 재시작하면 제시어를 다시 받을 수 없음
  - 힌트 횟수 제한이 서버에 없음 (전부 공개 후 정답 가능)
  - stroke 페이로드의 구조·크기·빈도를 검증하지 않음
  - 추측 텍스트 길이 제한 없음

### 폭탄 돌리기 (현재 아케이드 미노출)
- **높음 [C]**:
  - 서버 타이머가 없음. 시간 초과는 차례인 사람이 답을 낼 때만 판정하므로, **답을 안 내면 절대 지지 않음**.
  - 폭발 화면에 버튼이 없어 막다른 화면이 됨.
  - 복원 시 문제가 누락됨.
- kpop / movie 카테고리는 문제 풀이 없고, 문제는 총 8개뿐. `ui/bomb_board.dart`는 쓰이지 않는 코드.
- → 살릴지 제거할지 결정이 필요함.

### 가위바위보 / 제로
- **높음 ✅**: 방 안의 **어떤 소켓이든 끊기면** RPS 판을 삭제하고 `game:rps:cancelled`를 보내는데, **Flutter에는 이 이벤트 리스너가 없음** → 화면이 대기 상태로 영구히 멈춤. 관련 테스트는 실제 코드가 아니라 재구현한 함수를 검증하고 있음.
- **높음 [C]**: reset 권한 불일치 (서버는 User1, Flutter는 lobbyHost) + 낙관적 로컬 리셋 → 이후 `game_in_progress`.
- 결과 / XP 없음.

### 텔레파시
- 보통 [C]: Flutter가 `sessionId`를 보내지 않아 options가 다르면 먼저 낸 답이 버려짐 (기존 리포트 #1이 형태만 바뀌어 남아 있음). 문제 번호와 라운드가 화면 로컬 상태라 두 사람의 진행이 동기화되지 않음.
- 낮음: 같은 options로 연속 출제될 때 만료된 세션을 재사용해 타이머 없이 대기, 만료 결과를 "통하지 않았어요"로 표시.

### 해적 룰렛
- 보통 [C]: 재접속 시 `pickedSlots` 무시 (socket_service.dart:688, 기존 리포트 항목 아직 남아 있음).
- 낮음: 상대가 새 판을 시작하면 폭발 애니메이션이 안 나옴. 턴 제한이 없어 30분 동안 멈출 수 있음.

### 룰렛 (현재 아케이드 미노출)
- 보통 [C]: 휠이 항상 3바퀴 돌아 각도 0에서 멈춰 **서버가 고른 index와 화면 결과가 다름**. SocketService가 notify할 때마다 휠이 다시 돌고 항목이 되돌려짐. `propose` 호출부가 없어 상대 항목이 무시됨.

### 블랙잭
- 높음 [C]: 복원 없음 → 재연결 중 놓친 `updated` 때문에 교착 / 이탈 시 1시간 동안 시작 불가.
- 낮음 [C]: 선턴 플레이어가 내추럴이면 턴이 바로 넘어가서 "상대가 블랙잭"이라는 게 드러남. 다음 라운드를 아무나 넘길 수 있음. 2라운드제라 무승부가 잦은데, 무승부는 기록이 없음.

### 패널티킥
- 보통 [C]: **서든데스 없음**. 10킥 동점이면 draw로 끝나고 기록도 XP도 없음 (선방 확률이 1/9이라 동점이 잦음).
- 낮음: 첫 키커가 항상 User1, 마지막 킥 애니메이션보다 결과 패널이 먼저 뜸.

### 탱크
- 보통 [C]: 무승부를 양쪽 모두 "패배"로 표시함 (tank_screen.dart:264). 기존 리포트 항목이 아직 남아 있음.
- 보통 [C]: 정산 전에 상태부터 삭제함 (P0-4).
- 낮음 [C]: 조준값을 aim/weapon에서는 숨기지만 start/move/fire에서는 전체 브로드캐스트함. 종료 시 최종 `updated`가 없음. 경사 검사 없이 산을 통과함. 슬라이더를 움직일 때마다 emit함.

### 주사위
- 낮음: 소켓이 끊긴 상태에서 굴리면 `_rolling`이 영구히 true로 남음. 응답이 늦으면 이전 값이 잠깐 보임.

---

## 4. 테스트 공백

- **테스트가 버그를 정답으로 고정하고 있음**:
  - marble-engine.test.js:73과 socket-game-regression.test.js:309 (레벨 off-by-one)
  - socket-game-regression.test.js:292 (폭탄 복원 시 question 누락)
  - yut-engine.test.js:360 (잡기 보너스)
  - gostop-engine.test.js:120 (4광 비광)
- **재구현 함수 테스트**: game-reconnect.test.js가 실제 핸들러가 아니라 테스트 안에서 복제한 로직을 검증함.
- **소켓 핸들러 테스트가 전혀 없는 게임**: 원카드, 블랙잭, 도둑잡기, 탱크, 그림 맞히기, 폭탄 answer, 해적, 룰렛, rps pick/reset/disconnect, `restart:respond`, 마블 move/land_act, 판돈·정산.
- **Flutter**: `_restoreGames`(bomb/pirate/marble winner), ack 처리, 결과 다이얼로그 반복 표시 테스트 없음.

---

## 5. 수정 로드맵 (권장 순서)

### Phase 0 — 진행 불가 / 치명 (각각 작은 수정)
1. 고스톱: 손패가 빈 쪽 턴 건너뛰기 (또는 폭탄피 처리)
2. 원카드: 패널티로 받은 뒤 playable이면 `clearDrawStack`. draw / challenge에서 `drawnCardId` 정리
3. 그림 맞히기 / 가위바위보: 방장을 서버 상태로 통일. 그림 맞히기는 종료 시 키 삭제
4. 가위바위보: disconnect 시 남은 소켓 확인 후 취소 + Flutter `game:rps:cancelled` 리스너
5. 윷: 이동할 때마다 남은 pending 중 쓸 수 없는 빽도 제거 (move 후 낙 재판정)
6. 도둑잡기: 상대 시점 카드 id 무작위화
7. `restart:respond` 검증 + 락. 마블은 재시작 구현 또는 버튼 숨김
8. `unhandledRejection` / `uncaughtException` 로깅 핸들러 + 핸들러 공통 try/catch 래퍼

### Phase 1 — 경제 / 무결성
1. 판돈을 서버 pending-game에 보관 (P0-1). 판돈을 안 쓰는 게임은 UI 숨김
2. 안정적인 `gameId` + "정산 성공 후 삭제" 패턴을 고스톱에서 공통 헬퍼로 추출해 윷 / 원카드 / 탱크에 적용
3. 고스톱: 고는 직전 고 시점보다 점수가 올랐을 때만 허용
4. 마블: 레벨 기준 통일 (0=땅) + 테스트 기대값 수정. 잔액 = cost 허용 여부 정리

### Phase 2 — 공통 게임 세션 레이어 (근본 해결)
- 서버에 `GameSession { gameId, type, players, host, stake, phase, turnOwner, turnDeadline, status }` 공통 모듈을 둠. `create / join / restore / leave / forfeit / timeout / settle`을 한 곳에서 처리.
- 모든 게임을 `session:restore`와 이어하기 대상에 포함. 이탈 시 유예 시간 후 기권승. 서버 턴 타이머 (Redis 기반 deadline + 재시작 시 재스케줄).
- Flutter: `_restoreGames`에서 응답에 없는 게임 비활성화, `emitWithAck` 래퍼 + 오류 토스트.
- `game_results`: `game_id UNIQUE`, `is_draw` 컬럼 (winner/loser NULL 허용).

### Phase 3 — 규칙 완성 / UX
- 고스톱: 피 뺏기, 초단, 2장 매칭 선택, 이벤트 노출
- 마블: 감옥 / 게이트 / teleport
- 볼링: 서버 seed 기반 결정론적 시뮬레이션
- 패널티킥: 서든데스
- 무승부 기록 / XP
- 윷: 캐릭터 선택 연결
- 모바일 오디오 (audioplayers 등)
- 폭탄 / 룰렛 살릴지 제거할지 결정

### Phase 4 — 구조 개선
- socket.js를 게임별 모듈로 분리 (`modules/games/<type>/{handlers,engine}.js`)
- SocketService를 게임별 컨트롤러로 분리해 전체 리빌드 제거
- 대형 위젯(보드 / 시트 / 페인터) 파일 분할
- 위 테스트 공백 메우기 + 잘못 고정된 테스트 기대값 수정
