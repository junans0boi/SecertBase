# Handoff — 2026-08-05

## 완료된 작업

### 마블윷 T1 Foundation (commit b45b32b)

| 파일 | 상태 | 내용 |
|------|------|------|
| `marble-yut-engine.js` | 신규 | 말 2개, 영지 상수, 승리 조건 4종, calcToll/calcScore |
| `marble_yut_screen.dart` | 신규 | MarbleYutScreen 뼈대 + 소켓 연동 |
| `marble_yut_board.dart` | 신규 | 29칸 보드 UI, 신수 구역 라벨, 영지 오버레이 |
| `socket_service.dart` | 수정 | marbleYut* 필드 23개 + 이벤트 핸들러 4개 |
| `arcade_screen.dart` | 수정 | 마블윷 버튼·라우팅·isActive 연결 |
| 원본 파일 3개 | **변경 0줄** ✅ | yut_screen/yut_board/yut-engine 불변 |

### 이전 세션 버그 수정 (commit 62f4d84 → c254db9)

| # | 내용 | 파일 |
|---|------|------|
| 1 | 윷 스킨 상대 동기화 | `yut_board.dart`, `yut_screen.dart` |
| 2 | 윷 던지기 이펙트 상대 스킨 | `yut_board.dart` |
| 3 | 원카드 카드뒷면 스킨 매핑 | `uno_screen.dart`, `uno_board.dart` |
| 4 | 원카드 스킨 소켓 동기화 | `socket.js`, `socket_service.dart` |
| 5 | 인벤토리 기본 아이템 미표시 | `inventory_tab.dart` |
| 6 | 백엔드 unequip 엔드포인트 | `routes.js` |

---

## 다음 세션 작업

### 마블윷 T2 — 영지 점령·강화 + 자금 HUD (최우선)

**서버** (`services/realtime-server/src/socket.js`):
- `game:marble_yut:start` → `createMarbleYutGameState`
- `game:marble_yut:throw` → `throwYut` 재사용
- `game:marble_yut:move` → `movePiece` → 영지 액션 결정 후 emit
- `game:marble_yut:land_act` → `{action: claim|upgrade|skip, pos}`

말 이동 후 영지 처리 분기:
- 출발지(0/20) 통과 → coins +200, emit `marble_coin_update`
- 빈 칸 → emit `marble_land_prompt {type:'claim', pos, cost}`
- 내 영지 재방문 → emit `marble_land_prompt {type:'upgrade', pos, cost}` (L4 → skip)
- 상대 영지 → T3 범위 (통행료+인수)

**Flutter** (`marble_yut_screen.dart`):
- `marble_land_prompt` 수신 → claim/upgrade 팝업
- 상단 HUD: `marbleYutCoins` 양측 + `marbleYutRound`/20

**Flutter** (`marble_yut_board.dart`):
- `landData` prop 추가: `Map<String, dynamic>` (posStr → {owner, level})
- 소유자 색상 + 레벨 아이콘(★/🛡️) 오버레이

### 미커밋 WIP (stash에 보관 중)
- `uno_board.dart` — 관련 개선
- `uno-engine.js` + `uno-engine.test.js` — 관련 수정
- `docs/UNO_COMPARISON.md`

---

## 마블윷 확정 수치

```
gameType         = 'marble_yut'
말               = 플레이어당 2개 (id: 0, 1), 완주 승리 없음
초기 자금         = 1,500
월급 (출발지 통과) = 200
최대 라운드        = 20
소켓 prefix      = 'marble_'

영지 티어:
  S  pos[5,10,15]             점령비 300  통행료 150
  A  pos[23]                  점령비 200  통행료 100
  B  pos[21,22,24,25,26,27,28,29]  점령비 150  통행료 75
  C  pos[1~4,6~9,11~14,16~19]     점령비 100  통행료 50
  불가 pos[0,20]

강화 레벨 → 통행료 배율:
  L1: 1.0×   L2: 1.5×(강화비=점령비×1)
  L3: 2.5×(×2)   L4: 2.5×(×3) + 인수 불가(보호막)

업기 보너스: 빈영지 → 2배 비용→레벨2직행 / 인수 → 50% 할인
잡기 보너스: 보너스 던지기 + 15초 내 상대영지 인수기회(레벨4 제외)
서든데스 점수 = 보유 자금 + Σ(통행료 × 레벨배율 × 10)

승리 조건:
  bankrupt : 상대 자금 ≤ 0
  shrine   : pos 5,10,15 모두 동일 플레이어
  line     : 한 변의 claimable 칸 전부 동일 플레이어
  timeout  : 20라운드 후 점수 비교 (동점 → 공동 우승)
```

## 절대 불변 파일 (마블윷 작업 시)

```
apps/secret_base_app/lib/screens/arcade/games/yut_screen.dart
apps/secret_base_app/lib/ui/yut_board.dart
services/realtime-server/src/yut-engine.js
```

---

## 아키텍처 메모

```
장착 스킨 플로우:
  DB: equipped_items(user_id, slot, item_id)
  API: GET /api/shop/equipped → {slot: {name, icon, grade, stats}}
  Socket: game:yut:started.yutEquippedItems / game:uno:started.equippedItems
  Flutter: SocketService.{yutEquippedItems, unoEquippedItems}
  Board: YutBoard(opponentPieceSkin, opponentYutSkin) / UnoBoard(opponentCardBackSkin)

스킨 ID 매핑:
  pieceSkin: icon 이모지 문자열 ('⭐', '👑' 등) — 'base'는 기본 캐릭터 렌더
  yutSkin: icon+grade → {fire, cherry, crystal, bamboo, legend, stone, gold, base}
  cardBackSkin: icon 이모지 → {fog, sunset, water, night, autumn, aurora, firefly,
                               stardust, fireworks, eternity, fate, couple_card,
                               cherry_blossom, heart, rainbow, space, gold, base}
```
