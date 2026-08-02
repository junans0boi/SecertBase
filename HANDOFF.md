# Handoff — 2026-08-02

## 완료된 작업 (commit 62f4d84)

### 버그 수정

| # | 버그 | 파일 |
|---|------|------|
| 1 | **윷 스킨 상대 동기화** — YutBoard에 `opponentPieceSkin`/`opponentYutSkin` prop 추가, `isP2` 플래그로 p1/p2 스킨 올바르게 배정 | `yut_board.dart`, `yut_screen.dart` |
| 2 | **윷 던지기 이펙트 상대 스킨** — `_isOpponentThrow` 플래그 추가, 상대 던지기 시 상대 yutSkin 파티클 사용 | `yut_board.dart` |
| 3 | **원카드 카드뒷면 스킨 매핑** — `_nameToSkin` → `_iconToCardBackSkin` (아이콘 이모지 기반) | `uno_screen.dart`, `uno_board.dart` |
| 4 | **원카드 스킨 소켓 동기화** — `game:uno:started`에 `equippedItems` 포함, `SocketService.unoEquippedItems` 필드 추가 | `socket.js`, `socket_service.dart` |
| 5 | **인벤토리 기본 아이템 미표시** — `_defaultItems` 합성 리스트, unequip 버튼 | `inventory_tab.dart` |
| 6 | **백엔드 unequip 엔드포인트** — `POST /api/shop/unequip` | `routes.js` |

### 개선사항

| # | 개선 | 파일 |
|---|------|------|
| 7 | **캐릭터 선택 제거** — 로비에서 홍길동/구미호/놀부 선택 UI 삭제, YutAudio 시그니처 단순화 | `game_lobby_screen.dart`, `yut_audio.dart` |
| 8 | **자동 말 선택** — pendingMoves 도착 시 대기 말(pos==0) 자동 선택 | `yut_board.dart` |
| 9 | **스마트 가이드** — 자동 선택 후 가이드 즉시 표시, "이동 위치 선택" 상태 텍스트 | `yut_board.dart` |
| 10 | **원카드 뒷면 스킨 17종** — 기존 6 → 17 테마 추가 | `uno_board.dart` |

## 다음 세션 작업

### 미커밋 변경 (이전 세션)
- `shop_screen.dart` — 상점/인벤토리 탭 분리 리디자인 (Issue #65)
- `home_screen.dart` — 홈 화면 관련 변경
- `dev.sh` — auto-migration 개선
- `migrations/0020_activate_all_items.sql` — 신규 마이그레이션 (미스테이징)

### 열린 Issues (우선순위순)
- **#65** Slice 4: Flutter 상점/인벤토리 탭 분리 — `shop_screen.dart` 변경과 연관
- **#66** Slice 5: Flutter 인벤토리 가챠 UI
- **#64** Slice 3: Gacha v2 백엔드
- **#70** Slice 9: 가챠 S/SS/SSS 등급 애니메이션

### 배포
- 서버: `git pull && pm2 restart all` on secretbase.cloud
- Flutter: `flutter build web --release` + deploy to web root

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
