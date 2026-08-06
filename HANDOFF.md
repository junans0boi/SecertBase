# Handoff — 2026-08-06

## 이번 세션에서 완료된 작업

### 마블윷 T1~T5 완성 현황 확인

마블윷은 이전 세션들에서 T1~T5 + audit 버그 수정(20건)까지 모두 완료된 상태.
커밋 이력: `b45b32b` → `54e98bb` → `cbf5560` → `0185207` → `e775065` → `09a7f26`

| 파일 | 줄 수 |
|------|-------|
| `apps/secret_base_app/lib/screens/arcade/games/marble_yut_screen.dart` | 957 |
| `apps/secret_base_app/lib/ui/marble_yut_board.dart` | 3,292 |
| `services/realtime-server/src/marble-yut-engine.js` | 456 |

### 마블윷 대기실 버그 수정 (commit `5b8d11c`)

**버그**: `apps/secret_base_app/lib/screens/arcade/game_lobby_screen.dart`의
`_launchGame()` switch 문에 `marble_yut` case가 없었음.

결과: 두 플레이어가 대기실에서 게임을 시작해도 방장이 서버에
`game:marble_yut:new`를 전송하지 않아 서버 게임 상태 자체가 생성되지 않음.

**수정**: `case 'marble_yut': _socket.newMarbleYutGame(); break;` 3줄 추가.

### 프로덕션 배포 완료

- 커밋 `5b8d11c` push → `secretbase.cloud` 배포 완료
- 배포 중 `schema_migrations` 체크섬 불일치 4건 발생 → DB에서 직접 수정:
  - `0016_milestone_rewards.sql` → `5f93d430…`
  - `0017_shop_v3.sql`          → `2353e6ae…`
  - `0019_backdo_bonus.sql`     → `0df0ece0…`
  - `0020_activate_all_items.sql` → `d7f3097d…`
- PM2 재시작 완료, `/health` → `{"ok":true}`

> 원인: 과거에 이미 적용된 migration 파일들이 이후 커밋에서 방어적 SQL로 수정되면서
> 로컬 체크섬과 DB 기록이 불일치. `migrate.js`에 repair 커맨드 없음.
> 앞으로 이미 배포된 migration은 절대 수정하지 말 것.

---

## 다음 세션 작업

### 마블윷 실제 플레이 테스트

배포된 `secretbase.cloud`에서 두 계정으로 마블윷 실제 게임 진행 후
발견되는 버그 수집 및 수정.

확인 포인트:
- 대기실 → 게임 시작 (`game:marble_yut:new` 전송 확인)
- 선공 결정 주사위 roll_start 플로우
- 영지 점령/강화/통행료 팝업 동작
- 잡기 보너스 15초 타이머
- 승리 조건 (bankrupt / shrine / line / timeout)
- 서든데스 점수 계산

---

## 절대 불변 파일 (마블윷 작업 시)

```
apps/secret_base_app/lib/screens/arcade/games/yut_screen.dart
apps/secret_base_app/lib/ui/yut_board.dart
services/realtime-server/src/yut-engine.js
```

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
  S  pos[5,10,15]                  점령비 300  통행료 150
  A  pos[23]                       점령비 200  통행료 100
  B  pos[21,22,24,25,26,27,28,29]  점령비 150  통행료 75
  C  pos[1~4,6~9,11~14,16~19]      점령비 100  통행료 50
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

---

## 아키텍처 메모

```
장착 스킨 플로우:
  DB: equipped_items(user_id, slot, item_id)
  API: GET /api/shop/equipped → {slot: {name, icon, grade, stats}}
  Socket: game:yut:started.yutEquippedItems / game:marble_yut:state.equippedItems
  Flutter: SocketService.{yutEquippedItems, marbleYutEquippedItems}
  Board: MarbleYutBoard(equippedItems) — 각 플레이어 캐릭터 오버레이

스킨 ID 매핑:
  pieceSkin: icon 이모지 문자열 ('⭐', '👑' 등) — 'base'는 기본 캐릭터 렌더
  yutSkin: icon+grade → {fire, cherry, crystal, bamboo, legend, stone, gold, base}
  cardBackSkin: icon 이모지 → {fog, sunset, water, night, autumn, aurora, firefly,
                               stardust, fireworks, eternity, fate, couple_card,
                               cherry_blossom, heart, rainbow, space, gold, base}

migration 주의사항:
  이미 배포된 migration 파일은 절대 수정 금지.
  수정 필요 시 새 migration 파일(0021_...) 생성.
  migrate.js에 repair 커맨드 없음 — 체크섬 불일치는 DB 직접 수정 필요.
```

---

## Suggested Skills

- `/diagnosing-bugs` — 실제 테스트 중 버그 재현 및 수정
- `/tdd` — 마블윷 엔진 로직에 대한 회귀 테스트 추가
