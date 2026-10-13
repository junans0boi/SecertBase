# Secret Base 기능 전수 매트릭스

> 마지막 업데이트: 2026-10-13  
> 목적: 전체 기능 현황 파악 + 고도화 우선순위 도출

---

## 목차

1. [활성 기능](#1-활성-기능)
2. [비활성 기능 (재활성화 대기)](#2-비활성-기능-재활성화-대기)
3. [게임 버그 현황](#3-게임-버그-현황)
4. [갭 분석 (서버O / Flutter UI X)](#4-갭-분석-서버o--flutter-ui-x)
5. [고도화 우선순위](#5-고도화-우선순위)

---

## 1. 활성 기능

현재 네비게이션에 노출되어 사용 가능한 기능들.

### 인증 / 계정

| 기능 | Flutter 파일 | 서버 엔드포인트 | 상태 |
|------|-------------|----------------|------|
| 이메일 로그인/회원가입 | `screens/auth/login_screen.dart`, `register_screen.dart` | `POST /api/auth/login`, `/api/auth/register` | ✅ |
| Google OAuth 로그인 | `screens/auth/login_screen.dart` | `POST /api/auth/google` | ✅ |
| 파트너 페어링 (커플 연결) | `screens/auth/partner_screen.dart` | `POST /api/pairing/requests`, `/accept`, `/reject` | ✅ |
| 비밀번호 변경 | `screens/settings/settings_screen.dart` (내 공간) | `PATCH /api/user/password/:userId` | ✅ |
| 계정 삭제 | `screens/settings/settings_screen.dart` (내 공간) | `DELETE /api/user` | ✅ |
| 파트너 연결 해제 | `screens/settings/settings_screen.dart` (내 공간) | `DELETE /api/user/partner` | ✅ |
| 개인 보관함 (미페어링 상태) | `screens/archive/personal_history_screen.dart` | `GET /api/setlog` | ✅ |

### 홈 탭

| 기능 | Flutter 파일 | 서버 엔드포인트 | 상태 |
|------|-------------|----------------|------|
| D-day 카운터 + 기념일 배너 | `screens/home/home_screen.dart` | `GET /api/couple/info` | ✅ |
| 오늘의 루프 상태 카드 | `screens/home/home_screen.dart` | `GET /api/retention/today` | ✅ |
| 오늘의 루프 뷰어 | `screens/home/today_loop_viewer.dart` | `GET /api/retention/today` | ✅ |
| 메모리 카드 (같은 날 N년 전) | `screens/home/home_screen.dart` | `GET /api/retention/memory-card` | ✅ |
| 메모리 카드 목록 | `screens/home/memory_list_screen.dart` | `GET /api/retention/memory-card` | ✅ |
| 기념일 관리 | `screens/home/anniversaries_screen.dart` | `GET/POST/PATCH/DELETE /api/anniversaries` | ✅ |
| 퀵 액션 (지도/비밀기지/운세/타로/사주) | `screens/home/home_screen.dart` | — | ✅ |
| 관계이해 진입 카드 | `screens/home/home_screen.dart` | — | ✅ |

### MomentLoop 탭

| 기능 | Flutter 파일 | 서버 엔드포인트 | 상태 |
|------|-------------|----------------|------|
| 순간 피드 (텍스트+사진/영상) | `screens/archive/moment_loop_screen.dart` | `GET /api/setlog` | ✅ |
| 순간 작성 (사진/영상 업로드, 날짜) | `features/moment_loop/` | `POST /api/setlog` | ✅ |
| 순간 편집 / 삭제 | `features/moment_loop/` | `PATCH /api/setlog/:id`, `DELETE /api/setlog/:id` | ✅ |
| 이모지 반응 | `features/moment_loop/` | `POST /api/setlog/reaction` | ✅ |
| 댓글 | `features/moment_loop/` | `GET/POST/DELETE /api/setlog/:postId/comments` | ✅ |
| 업로드 아웃박스 (오프라인 복원) | `features/moment_loop/upload_outbox.dart` | — | ✅ |
| 순간 순서 재정렬 | `features/moment_loop/` | `PATCH /api/setlog/session/:sessionId/order` | ✅ |
| 오늘의 순간 선택/해제 | `screens/archive/moment_loop_screen.dart` | `PUT/DELETE /api/retention/today/moment` | ✅ |
| 캘린더 시트 + 태그 필터 | `screens/archive/moment_loop_screen.dart` | — | ✅ |

### 비밀 지도 탭

| 기능 | Flutter 파일 | 서버 엔드포인트 | 상태 |
|------|-------------|----------------|------|
| 지도 핀 표시 (OSM/flutter_map) | `screens/archive/map_screen.dart` | `GET /api/map` | ✅ |
| 장소 추가 (카테고리/감정태그/사진) | `screens/archive/map_screen.dart` | `POST /api/map` | ✅ |
| 장소 편집 / 삭제 | `screens/archive/map_screen.dart` | `PATCH/DELETE /api/map/:id` | ✅ |
| 장소 리뷰 | `screens/archive/map_screen.dart` | `GET/POST/DELETE /api/map/:id/reviews` | ✅ |
| 장소 검색 (Google Places 프록시) | `screens/archive/map_screen.dart` | `GET /api/places/search` | ✅ |
| 3패널 바텀 시트 (collapsed/half/expanded) | `screens/archive/map_screen.dart` | — | ✅ |

### 놀이 탭 (아케이드)

| 기능 | Flutter 파일 | 서버 이벤트 | 상태 |
|------|-------------|------------|------|
| 게임 로비 | `screens/arcade/game_lobby_screen.dart` | `game:lobby:*` | ✅ |
| 코인 지갑 + 일일 출석 보너스 | `screens/arcade/arcade_screen.dart` | `POST /api/wallet/daily-bonus` | ✅ |
| 게임 전적 기록 | `screens/arcade/arcade_screen.dart` | `GET /api/arcade/records` | ✅ |
| 블랙잭 | `screens/arcade/blackjack_screen.dart` | `game:blackjack:*` | ⚠️ 버그 |
| 도둑잡기 (고피시) | `screens/arcade/oldmaid_screen.dart` | `game:oldmaid:*` | ✅ |
| 윷놀이 | `screens/arcade/yut_screen.dart` | `game:yut:*` | 🚨 버그 |
| 마블 작전 | `screens/arcade/marble_screen.dart` | `game:marble:*` | 🚨 버그 |
| 가위바위보 (묵찌빠/한아비기) | `screens/arcade/rps_screen.dart` | `game:rps:*` | ✅ |
| 제로 | `screens/arcade/zero_screen.dart` | — | ✅ |
| 원카드 | `screens/arcade/uno_screen.dart` | `game:uno:*` | 🚨 버그 |
| 주사위 | `screens/arcade/dice_screen.dart` | `game:dice:*` | ⚠️ 버그 |
| 텔레파시 | `screens/arcade/telepathy_screen.dart` | `game:telepathy:*` | 🚨 버그 |
| 해적 룰렛 | `screens/arcade/pirate_screen.dart` | `game:pirate:*` | 🚨 버그 |
| 패널티킥 | `screens/arcade/penalty_screen.dart` | `game:penalty:*` | 🚨 버그 |
| 볼링 | `screens/arcade/bowling_screen.dart` | `game:bowling:*` | ⚠️ 버그 |
| 그림 맞히기 | `screens/arcade/catch_screen.dart` | `game:catch:*` | 🚨 버그 |
| 탱크 대작전 | `screens/arcade/tank_screen.dart` | `game:tank:*` | 🚨 버그 |
| 고스톱 | `screens/arcade/gostop_screen.dart` | `game:gostop:*` | ⚠️ 버그 |
| 룰렛 | `screens/arcade/roulette_screen.dart` | `game:roulette:*` | 🚨 버그 |

### 상점

| 기능 | Flutter 파일 | 서버 엔드포인트 | 상태 |
|------|-------------|----------------|------|
| 가차 뽑기 (B/A/S/SS/SSS) | `screens/shop/shop_screen.dart` | `POST /api/shop/gacha` | ✅ |
| 아이템 구매 | `screens/shop/shop_screen.dart` | `POST /api/shop/buy` | ✅ |
| 인벤토리 / 장착 관리 | `screens/shop/inventory_tab.dart` | `GET /api/shop/owned`, `POST /api/shop/equip` | ✅ |
| 미션 (주간/완료) + 클레임 | `screens/shop/shop_screen.dart` | `GET /api/missions`, `POST /api/missions/:id/claim` | ✅ |
| 데이트 쿠폰 발행/수신 | `screens/shop/shop_screen.dart` | `GET/POST /api/shop/coupons` | ✅ |
| 쿠폰 코드 교환 | `screens/shop/shop_screen.dart` | `POST /api/shop/coupons/redeem` | ✅ |

### 더보기 탭

| 기능 | Flutter 파일 | 서버 엔드포인트 | 상태 |
|------|-------------|----------------|------|
| 비밀기지 마일스톤 | `screens/secret_base/secret_base_screen.dart` | `GET /api/retention/secret-base/milestones` | ✅ |
| 마일스톤 리워드 수령 | `screens/secret_base/secret_base_screen.dart` | `POST /api/retention/secret-base/milestones/:type/claim` | ✅ |
| 월간 엽서 | `screens/secret_base/base_postcard_screen.dart` | `GET /api/retention/secret-base/postcard/:year/:month` | ✅ |
| 관계이해 허브 (개인/커플 탭) | `screens/relationship/relationship_understanding_screen.dart` | — | ✅ |
| 출생 프로필 설정 | `screens/relationship/` | `GET/POST /api/relationship/birth-profile` | ✅ |
| 개인 심리검사 | `screens/relationship/assessment_*.dart` | `GET/POST /api/relationship/assessments/:code/*` | ✅ |
| 커플 심리검사 | `screens/relationship/assessment_*.dart` | `GET/POST /api/relationship/couple-assessments/:code/*` | ✅ |
| 검사 이력 비교 | `screens/relationship/assessment_history_screen.dart` | `GET /api/relationship/assessment-results/:code/comparison` | ✅ |
| 궁합 분석 | `screens/relationship/compatibility_screen.dart` | `GET /api/relationship/compatibility/*` | ✅ |
| 사주 (개인/커플) | `screens/relationship/saju_screen.dart` | `GET/POST /api/relationship/saju` | ✅ |
| 타로 (일일 선택) | `screens/relationship/tarot_screen.dart` | `GET /api/relationship/tarot/today`, `POST .../draw` | ✅ |
| 오늘의 운세 (커플) | `screens/relationship/fortune_screen.dart` | `GET /api/relationship/fortune/today` | ✅ |
| 마음관리 채팅 | `screens/relationship/mindcare_screen.dart` | `POST/GET /api/relationship/mindcare/sessions/*` | ✅ |
| AI 관계 상담 (개인/공유) | `screens/relationship/counseling_screen.dart` | `POST/GET /api/relationship/counseling/*` | ✅ |
| AI 설명 생성 | `screens/relationship/` | `POST /api/relationship/explanations/*` | ✅ |
| 안전 안내 (위기 대응) | — | `GET /api/relationship/mindcare/safety-resources` | ✅ |
| 알림 설정 | `screens/settings/notification_settings_screen.dart` | `GET/PUT /api/notifications/notification-prefs` | ✅ |
| 내 공간 (프로필/계정/연결 관리) | `screens/settings/settings_screen.dart` | `GET/PATCH /api/user/profile/:userId` | ✅ |
| 푸시 알림 디바이스 등록 | `core/push/push_service.dart` | `POST /api/notifications/device-token` | ✅ |

---

## 2. 비활성 기능 (재활성화 대기)

코드와 서버 구현이 완료됐지만 comment #32로 네비게이션에서 제거된 기능들.
재활성화 시 `settings_screen.dart` 또는 `home_shell.dart` 라우팅 연결만 필요.

| 기능 | Flutter 파일 | 서버 엔드포인트 | 서버 완성도 | 활성화 난이도 | 우선순위 |
|------|-------------|----------------|------------|--------------|---------|
| **10시의 질문 (Q&A)** | `archive/qa_screen.dart` | `GET /api/qa/today`, `POST /api/qa/answer` | ✅ 완성 | 🟢 낮음 | **P0** |
| **커플 밸런스** | `archive/balance_screen.dart` | `GET /api/balance/today`, `POST /api/balance/answer` | ✅ 완성 | 🟢 낮음 | **P0** |
| **소원 쿠폰** | `archive/wish_ticket_screen.dart` | `GET/POST /api/wish-tickets`, `PATCH .../use`, `.../cancel` | ✅ 완성 | 🟢 낮음 | **P0** |
| **데이트 룰렛** | `date_roulette_screen.dart` | 클라이언트 전용 | — | 🟢 낮음 | **P0** |
| **커플 챌린지** | `archive/challenge_screen.dart` | `GET/POST /api/challenges`, `POST .../log` | ✅ 완성 | 🟢 낮음 | **P1** |
| **주크박스** | `archive/jukebox_screen.dart` | `GET/POST /api/jukebox` | ✅ 완성 | 🟢 낮음 | **P1** |
| **사진 앨범** | `archive/album_screen.dart` | `GET/POST /api/album/folders`, `/api/album/photos` | ✅ 완성 | 🟡 중간 | **P2** |
| **타임캡슐** | `archive/capsule_screen.dart` | `GET/POST /api/capsules`, `PATCH .../open` | ✅ 완성 | 🟡 중간 | **P2** |
| **마음 대피소 (저널)** | `archive/shelter_screen.dart` | `GET/POST/PATCH/DELETE /api/reflections` | ✅ 완성 | 🟡 중간 | **P2** |
| **타임라인** | `archive/timeline_screen.dart` | `GET /api/timeline` | ✅ 완성 | 🟡 중간 | **P2** |
| **월간 리포트** | `archive/monthly_report_screen.dart` | `GET /api/reports/monthly` | ✅ 완성 | 🟡 중간 | **P2** |
| **프리미엄 구독** | `archive/premium_screen.dart` | `GET/POST /api/premium/*` | ✅ 완성 | 🔴 높음 | **P3** |

### HeartExchange 허브 (Q&A + 밸런스 + 소원쿠폰 묶음)
- Flutter: `archive/heart_exchange_screen.dart` 이미 존재
- 더보기 탭 `기록과 이해` 섹션에 항목 추가하면 즉시 활성화 가능

### VaultScreen 허브 (챌린지 + 타임라인 + 월간리포트 + 주크박스 묶음)
- Flutter: `archive/vault_screen.dart` 이미 존재
- 동일하게 라우팅 연결만 필요

---

## 3. 게임 버그 현황

### 🚨🚨 긴급 (보안/조작 가능 + 게임 진행 불가)

| 게임 | 버그 | 영향 |
|------|------|------|
| **폭탄 돌리기** | 타이머 30000초 버그 (ms→s 단위 오류), 재접속 시 필드명 불일치, XP 미지급 | 게임 사실상 불가 |

### 🚨 긴급 (보안/조작 가능 또는 핵심 로직 파손)

| 게임 | 버그 | 영향 |
|------|------|------|
| **그림 맞히기** | timeout/next/reset 권한 없음 (누구나 호출 가능), draw relay 미검증, XP 미지급 | 권한 취약점 |
| **패널티킥** | submissions 서버 응답에 상대 방향 노출 (조작 가능), XP 미지급 | 게임 조작 가능 |
| **텔레파시** | options 미검증 (조작 가능), Redis TTL 60s 만료 시 게임 stuck | 조작 가능 + UX 파손 |
| **해적 룰렛** | reset 권한 없음 (누구나 게임 삭제 가능), 재접속 상태 미복원 | 권한 취약점 |
| **탱크 대작전** | 무기 선택 시 angle/power 상대에게 노출, 상호전멸 시 무한루프 | 조작 가능 + 무한루프 |
| **윷놀이** | `caughtOpponentThisTurn` 리셋 누락 (추가 턴 오귀속), 게임 참가자 검증 미흡 | 로직 오류 |
| **마블 작전** | `winReason` 코드 불일치 (독점 승리 UI 깨짐), HUD 자산 계산 오류, jail/gate 미구현 | UI 파손 + 미완성 |
| **원카드** | Wild 색상 선언 미검증, `drawStack` 미클리어로 드로우 카드 누적 버그 | 게임 조작 가능 |
| **룰렛** | 상대 options 무시하여 결과-UI 불일치 | 결과 표시 오류 |

### ⚠️ 중간 (UX 저하 또는 마이너 버그)

| 게임 | 버그 |
|------|------|
| **블랙잭** | `next_round` 레이스 컨디션 |
| **고스톱** | 양방향 흔들기 UI 불명확, 덱 소진 + 상대 7점 동시 케이스 미처리 |
| **볼링** | pins 서버 미검증 (클라이언트 조작 가능) |
| **주사위** | 로컬/서버 타이밍 불일치 |

---

## 4. 갭 분석 (서버O / Flutter UI X)

서버 구현은 완료됐지만 Flutter 화면이 없거나 부분만 연결된 기능.

| 기능 | 서버 엔드포인트 | 현황 | 메모 |
|------|----------------|------|------|
| 히스토리 & 내보내기 | `GET /api/history`, `GET /api/history/export` | Flutter 미구현 | ZIP 내보내기 포함 |
| 메모리 카드 전체 목록 | `GET /api/retention/memory-card/list` | 부분 연결 | 홈의 단일 카드만 사용 |
| Afterglow (장소 방문 후기) | `GET/POST /api/retention/afterglow/*` | 부분 구현 | MapScreen에 섹션만 있음 |
| 레벨/XP 표시 | `GET /api/user/level` | 부분 연결 | ArcadeScreen에 일부만 노출 |
| 월간 밸런스 프롬프트 | `GET /api/balance/today` | 비활성화됨 | BalanceScreen 존재 |
| 미션 완료 처리 | `POST /api/missions/:instanceId/complete` | 부분 연결 | 클레임만 노출 |
| 커플 리유니언 배너 | `POST /api/couple/reunion-notice/seen` | Flutter 미구현 | 재결합 시 배너 |
| Google Login 계정 연동 | `POST /api/auth/google/link` | 미구현 | 기존 계정에 구글 연동 |

---

## 5. 고도화 우선순위

### P0 — 즉시 (라우팅 연결만, 1-2시간)

> 코드와 서버 모두 완성. 네비게이션 연결만 누락.

1. **HeartExchange 허브 재활성화** (소원 쿠폰 + Q&A + 커플 밸런스)
   - `settings_screen.dart`에 `heart_exchange_screen.dart` 라우팅 추가
2. **데이트 룰렛 재활성화**
   - 더보기 탭 또는 홈 퀵 액션에 추가

### P1 — 단기 (게임 버그 수정, 게임별 1-3시간)

> 보안/조작 가능 버그 먼저. 실제 사용자에게 영향.

1. 폭탄 돌리기 🚨🚨 — 타이머 단위 수정 + XP 지급
2. 패널티킥 🚨 — submissions 응답에서 상대 방향 제거
3. 텔레파시 🚨 — options 서버 검증 + TTL 만료 처리
4. 해적 룰렛 🚨 — reset 호출자 검증
5. 탱크 대작전 🚨 — angle/power 상대 미노출 + 전멸 종료 처리
6. 그림 맞히기 🚨 — timeout/next/reset 권한 검증
7. 나머지 게임들 (윷놀이, 마블, 원카드, 룰렛)

### P2 — 중기 (비활성 기능 재활성화, 기능별 반나절)

> VaultScreen 허브 재활성화 + 개별 화면 QA.

1. VaultScreen 허브 연결 (챌린지 + 주크박스)
2. 앨범 재활성화
3. 타임캡슐 재활성화
4. 마음 대피소 (저널) 재활성화
5. 타임라인 재활성화
6. 월간 리포트 재활성화

### P3 — 장기 (신규 작업 필요)

1. 히스토리 & ZIP 내보내기 Flutter 화면
2. 레벨/XP 상세 화면
3. Afterglow 완성
4. 프리미엄 구독 (결제 연동 필요)
5. Google Login 계정 연동 UI

---

## 참고 링크

- CONTEXT.md — 도메인 용어 정의
- docs/adr/ — 14개 설계 결정 기록
- docs/product/ — 기능별 상세 스펙
- docs/handoff/2026-10-12-codex-handoff.md — 최신 핸드오프 (배포 체크리스트)
- MEMORY.md — 게임별 버그 메모 (Claude 자동 메모리)
