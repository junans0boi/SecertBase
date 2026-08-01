# Shop v3 Handoff — Slices 7–9

작성일: 2026-08-01  
커밋: `7a9eea9` (main)

---

## 완료된 것 (Slices 1–6)

| Slice | 이슈 | 내용 | 상태 |
|-------|------|------|------|
| 1 | #62 | DB Migration 0017: `owned_items.quantity`, ENUM×22, `gacha_tiers` | ✅ Applied |
| 2 | #63 | Item Catalog 0018: 50개 아이템(active=0) + 107 stat rows | ✅ Applied |
| 3 | #64 | Gacha v2 Backend: `/api/shop/gacha` (tier+game), `/api/shop/catalog` | ✅ routes.js |
| 4 | #65 | Flutter 탭 분리: ShopScreen ↔ InventoryTab | ✅ shop_screen.dart |
| 5 | #66 | Gacha UI: 3티어 버튼, 확인 다이얼로그, B/A 결과 다이얼로그 | ✅ inventory_tab.dart |
| 6 | #67 | Compendium: 도감 시트, 실루엣/??? 미공개, 등급 필터 | ✅ inventory_tab.dart |

---

## 남은 것 (Slices 7–9)

### Slice 7 (#68) — 스탯 게임 내 적용

**목표**: `item_stats` DB 값이 실제 yut/onecard 게임 로직에 반영되도록.

**관련 파일**:
- `services/realtime-server/src/game-logic/yut-logic.js` (윷 굴리기 로직)
- `services/realtime-server/src/game-logic/onecard-logic.js` (원카드 드로우/공격 로직)
- `services/realtime-server/src/level-engine.js` (게임 종료 보상)

**적용 스탯 목록**:

| stat_key | 적용 지점 | 로직 |
|----------|-----------|------|
| `yut_mo_rate_pct` | 윷 굴리기 | 모(5칸) 결과 확률 += val |
| `yut_backdo_shield_pct` | 윷 굴리기 | 뒤도(−1) 나오면 val% 확률로 도(1)로 변환 |
| `yut_win_coin_pct` | 윷/모 나올 때 | 추가 코인 지급 (level-engine) |
| `yut_overturn_pct` | 윷 굴리기 | 내 점수 < 상대 점수일 때 윷/모 확률 += val |
| `piece_catch_resist_pct` | 말 잡기 판정 | 잡힐 때 val% 확률로 잡힘 무효 |
| `piece_catch_coin_bonus` | 말 잡기 성공 시 | val만큼 추가 코인 |
| `piece_safe_zone_pct` | 말 이동 | val% 확률로 시작점/모서리 칸에 착지 |
| `piece_group_pct` | 말 이동 | val% 확률로 업힌 말 분리 방지 |
| `card_shield_pct` | +2/스킵 받을 때 | val% 확률로 무효 |
| `card_lucky_draw_pct` | 드로우 시 | val% 확률로 원하는 카드 선택 |
| `card_uno_protect_pct` | 원카드 선언 시 | val% 확률로 다음 공격 무효 |
| `card_reverse_bonus` | 리버스/스킵 사용 | val만큼 추가 코인 |
| `yut_control_pct` | 윷 굴리기 | 기존: 윷/모 확률 += val |
| `yut_catch_bonus` | 말 잡기 | 기존: 추가 코인 |
| `coin_bonus_pct` | 게임 종료 | 기존: 승리 코인 × (1 + val/100) |
| `lose_refund_pct` | 게임 종료 | 기존: 패배 환급 |
| `onecard_draw_reduce` | +2 받을 때 | 기존: 드로우 1장 감소 |
| `win_streak_bonus` | 게임 종료 | 기존: 연승 보너스 |

**구현 방식**:
1. 게임 시작 시 양 플레이어의 장착 아이템 → `item_stats` JOIN → 스탯 딕셔너리 로드
2. 각 로직 함수 파라미터로 `stats: { [stat_key]: value }` 전달
3. 확률 계산: `Math.random() * 100 < stat_value`

**스탯 로드 쿼리 (player_id 기준)**:
```sql
SELECT s.stat_key, s.value
FROM equipped_items e
JOIN item_stats s ON s.item_id = e.item_id
WHERE e.user_id = ? AND e.couple_id = ?;
```

---

### Slice 8 (#69) — 게임 내 상대 아이템 표시

**목표**: 게임 화면 상단에 양쪽 플레이어 장착 아이템 뱃지 표시.

**관련 파일**:
- `services/realtime-server/src/routes.js` — 게임 시작 소켓 이벤트에 아이템 정보 추가
- `apps/secret_base_app/lib/screens/yut/yut_game_screen.dart`
- `apps/secret_base_app/lib/screens/onecard/onecard_screen.dart`

**Backend 변경**:
- 게임 시작(match 생성) 시 소켓 payload에 양 플레이어 장착 아이템 포함:
```json
{
  "game_started": true,
  "player_items": {
    "user_a_id": [{ "slot": "yut_yut", "name": "...", "icon": "...", "grade": "S" }],
    "user_b_id": [{ "slot": "yut_yut", "name": "...", "icon": "...", "grade": "A" }]
  }
}
```

**Flutter 변경**:
- 게임 화면 AppBar 아래 또는 상단 Row에:
  - 내 아이템 (왼쪽): 슬롯별 아이콘/등급 뱃지
  - 상대 아이템 (오른쪽): 동일
- 탭 시: `showDialog` with 스탯 요약

**UI 컴포넌트 아이디어**:
```
[내 아이템] [🎲 A] [🐴 S]     [🃏 SS] [상대 아이템]
```

---

### Slice 9 (#70) — S/SS/SSS 가챠 애니메이션 강화

**목표**: `_GachaAnimOverlay`의 `_GachaBurstPainter`를 등급별로 고도화.

**현재 상태** (`inventory_tab.dart` 내):
- `_GachaAnimOverlay`: PageRoute로 fullscreen 오버레이
- `_GachaBurstPainter`: 기본 버스트 파티클 (등급 무관)

**목표 스펙**:

| 등급 | 효과 | 시간 |
|------|------|------|
| S | 별 파티클 + 파란 빛 버스트 | 1.5초 |
| SS | 보라 빛 + 카드 플립 ×3 + 파티클 | 2.5초 |
| SSS | 황금 + 무지개 글로우 + 카드 플립 ×5 + 폭발 이펙트 | 3.5초 |

**구현 포인트**:
- `_GachaBurstPainter`에 `grade` 파라미터 추가
- `grade == 'S'`: 파란 파티클 원형 방출
- `grade == 'SS'`: 보라 파티클 + 회전 카드 × 3 (TweenSequence)
- `grade == 'SSS'`: 황금+무지개 + 카드 ×5 + 최종 폭발 (3 phase)
- `AnimationController`를 grade별로 다른 duration 설정

---

## 핵심 아키텍처 메모

```
Flutter App (port 7357)
  └─ SocketService.serverUrl → secretbase.cloud:443 (prod) / localhost:4100 (dev)
      └─ Node.js/Express (realtime-server)
          ├─ MariaDB (localhost:3307 via SSH tunnel / secretbase.cloud:3306 prod)
          └─ Redis (localhost:6380 via SSH tunnel / secretbase.cloud:6379 prod)
```

**AuthService**: singleton (`factory AuthService() => _instance`)  
**token**: `_auth.token` — Bearer JWT  
**serverUrl**: `_socket.serverUrl ?? ''`  

**Migration 실행**: `node scripts/migrate.js up` (server에서)  
**이미 적용된 migration**: 0017, 0018

---

## 이슈 레퍼런스

| 이슈 | 제목 | 라벨 |
|------|------|------|
| #68 | Slice 7: Stats Game Apply | `enhancement`, `ready-for-agent` |
| #69 | Slice 8: Opponent Item Display | `enhancement`, `ready-for-agent` |
| #70 | Slice 9: Gacha Animation | `enhancement`, `ready-for-agent` |

---

## 다음 세션에서 시작할 것

1. `Slice 7` 먼저: `equipped_items` → `item_stats` 스탯 로드 함수 작성 → yut-logic.js / onecard-logic.js에 적용
2. `Slice 8`: 게임 시작 소켓 이벤트에 `player_items` 추가 → Flutter UI 뱃지
3. `Slice 9`: `_GachaAnimOverlay` 고도화

권장 작업 순서: 7 → 8 → 9 (의존성 순)
