# Secret Base 전체 프론트엔드 디자인 개편 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Secret Base의 모든 사용자 노출 프론트엔드를 같은 정보 계층과 상태 표현으로 정리해, 사용자가 각 화면의 목적과 다음 행동을 즉시 이해하도록 개선한다. 운세·사주·타로·관계 이해의 도메인 계약과 개인정보 범위는 유지하고, 홈·기록·지도·놀이·더보기·인증·보조 화면까지 단계적으로 시각 QA와 함께 배포한다.

**Architecture:** 기존 Flutter 화면과 `main_design.dart`/`app_theme.dart`를 중심으로 점진적으로 정리한다. 메인 하단 탭은 유지하고, 공통 UI는 이미 존재하는 `CozyPage`, `MainCard`, `IconBadge`, `BrandLogo`, `CozyMascot`, `GameScaffold`를 우선 재사용한다. 실제로 세 화면 이상에서 반복되는 구조만 공통 위젯으로 추출한다. API, 저장 범위, 게임 규칙, 하단 탭 계약은 변경하지 않는다.

**Tech Stack:** Flutter/Dart, Material 3, `google_fonts`, 기존 REST API 클라이언트, `flutter_test`, `flutter_map`, GitHub Actions 배포, Chrome 기반 실제 화면 QA.

**Spec:** `docs/superpowers/specs/2026-09-14-frontend-design-overhaul-design.md`

## Global Constraints

- [ ] 모든 작업은 기존 `apps/secret_base_app`의 현재 API와 테스트를 기준으로 한다.
- [ ] 새 디자인 토큰 파일, 새 상태관리 라이브러리, 새 UI 프레임워크, 새 폰트/아이콘 패키지를 추가하지 않는다.
- [ ] 공통 위젯을 만들기 전에 기존 `main_design.dart`, `app_theme.dart`, `GameScaffold`, `GameMenu`를 먼저 재사용한다.
- [ ] 개인 결과는 소유자만, 커플 결과는 활성 Couple 구성원만 볼 수 있다는 경계를 UI에서도 유지한다.
- [ ] 운세·사주·타로·마음관리는 예언·진단·치료를 약속하지 않는 자기성찰 콘텐츠 문구를 유지한다.
- [ ] 타로는 사용자가 고른 메이저 아르카나 22장 중 하루 한 장을 범위별로 고정하는 ADR 0014 계약을 유지한다. 재추첨·스프레드·자동 선택을 추가하지 않는다.
- [ ] 사주는 출생 입력이 부족할 때 조용히 기본값으로 채우지 않고, 제한 결과 또는 출생정보 수정 행동을 보여준다.
- [ ] 내부 예외, API 키, 좌표, 토큰, 데이터베이스 필드명을 일반 사용자에게 출력하지 않는다.
- [ ] 버튼·아이콘·캐러셀의 터치 영역은 최소 44×44 logical px을 목표로 하고, semantics label을 제공한다.
- [ ] 390×844와 440×880 기준에서 가로 잘림, 무한한 빈 공간, 하단 버튼 가림을 확인한다.
- [ ] 각 구현 작업은 관련 위젯/API 테스트를 먼저 추가하거나 갱신한 뒤 구현하고, 작업 단위로 커밋한다.
- [ ] 작업 중 기존 `test-results/` untracked 파일은 삭제하거나 스테이징하지 않는다.
- [ ] 구현 완료 전 `flutter analyze --no-pub`, 관련 테스트, 전체 테스트, 프로덕션 health check를 다시 실행한다.

## Page Coverage Map

| 영역 | 화면/파일 | 이번 계획의 처리 |
|---|---|---|
| 인증/진입 | `entry_screen.dart`, `auth/auth_layout.dart`, `auth/login_screen.dart`, `auth/register_screen.dart`, `auth/partner_screen.dart` | 마지막 제품 표면 단계에서 동일한 브랜드·폼·오류·뒤로가기 규칙 적용 |
| 앱 셸 | `home_shell.dart` | 5개 탭 유지, 선택 상태·safe area·전환·접근성 정리 |
| 홈 | `home/home_screen.dart`, `home/today_card.dart`, `home/today_loop_viewer.dart`, `home/memory_list_screen.dart` | 오늘의 주 행동과 이어보기 우선 구조 |
| MomentLoop | `archive/moment_loop_screen.dart`, `home/today_loop_viewer.dart` | 날짜/주간 맥락과 기록 CTA 재정리 |
| 지도 | `archive/map_screen.dart`, `archive/afterglow_section.dart` | 지도 설정 오류 제거, 검색/필터/빈 상태 정리 |
| 놀이 | `arcade/arcade_screen.dart`, `arcade/game_lobby_screen.dart`, `widgets/game_scaffold.dart`, `widgets/game_menu.dart` | 게임 선택 발견성·재개 상태·공통 헤더 정리 |
| 관계 허브 | `relationship/relationship_understanding_screen.dart` | 개인/커플 정보 계층 재구성 |
| 검사 | `relationship/assessment_catalog_screen.dart`, `assessment_attempt_screen.dart`, `assessment_history_screen.dart`, `compatibility_screen.dart` | 진행·완료·기록·비교 상태 통일 |
| 운세/사주/타로 | `relationship/fortune_screen.dart`, `saju_screen.dart`, `tarot_screen.dart` | 읽는 순서, 기준 설명, 결과/선택 상태 개선 |
| 마음관리/상담 | `relationship/mindcare_screen.dart`, `mindcare_safety_screen.dart`, `counseling_screen.dart` | 선택 중심 흐름과 안전 상태 우선 |
| 더보기/내 공간 | `settings/settings_screen.dart`, `secret_base/secret_base_screen.dart`, `base_postcard_screen.dart` | 현재 그룹형 목록을 기준으로 보조 기능 계층 정리 |
| 상점/인벤토리 | `shop/shop_screen.dart`, `shop/inventory_tab.dart` | 잔액·구매·보유 상태와 빈 상태 정리 |
| 인증/파트너 | 위 auth 파일과 파트너 연결 흐름 | 민감 정보 최소 노출, 폼 오류/완료 상태 개선 |
| 보조 기록 | `afterglow_section.dart`, `album_screen.dart`, `capsule_screen.dart`, `challenge_screen.dart`, `heart_exchange_screen.dart`, `jukebox_screen.dart`, `monthly_report_screen.dart`, `personal_history_screen.dart`, `shelter_screen.dart`, `timeline_screen.dart`, `vault_screen.dart`, `wish_ticket_screen.dart` | 현재 메인 진입점에서 노출되는 화면만 공통 규칙 적용; 숨겨진 레거시는 재노출하지 않음 |
| 게임 내부 | `arcade/games/*.dart`, `ui/*.dart` | 규칙 변경 없이 공통 헤더·나가기·재개·결과 상태만 확인 |

## Execution Protocol

각 태스크는 다음 순서로 진행한다.

1. 현재 화면과 호출 경로를 읽고, 기존 테스트/ADR을 확인한다.
2. 실패하는 최소 위젯 테스트 또는 회귀 테스트를 추가한다.
3. 기존 공통 토큰/위젯을 재사용해 가장 작은 구현을 한다.
4. 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
5. Chrome에서 390px 전후 폭으로 loading/ready/empty/error를 확인하고, 필요한 경우 화면 캡처를 `test-results/` 아래에 남긴다.
6. 한 가지 제품 표면만 포함하는 커밋을 만든다.

다음 태스크로 넘어가기 위한 최소 조건은 해당 태스크의 테스트 통과, 분석 통과, 핵심 화면 시각 확인이다.

---

## Task 1: 기준선 고정과 공통 표면 정리

**Files:**

- Modify: `apps/secret_base_app/lib/core/main_design.dart`
- Modify: `apps/secret_base_app/lib/core/app_theme.dart`
- Add: `apps/secret_base_app/test/design_system_test.dart`
- Add: `apps/secret_base_app/test/home_shell_navigation_test.dart`

**Purpose:** 모든 다음 화면이 같은 제목·본문·카드·버튼·입력·하단 탭 규칙을 쓰도록 현재 중복 팔레트와 표면 규칙을 정리한다. 이 태스크에서는 개별 페이지의 정보 구조를 바꾸지 않는다.

### Steps

- [ ] `main_design.dart`의 `kMain*` 토큰과 `app_theme.dart`의 `k*` 토큰을 대조해 같은 의미의 색상이 서로 다른 값으로 사용되는 곳을 기록한다.
- [ ] 이미 `main_design.dart`를 사용하는 화면을 우선 기준으로 삼고, `app_theme.dart`가 제공하는 `ThemeData`의 색상·입력·NavigationBar가 동일한 의미의 토큰을 사용하도록 최소 수정한다.
- [ ] `mainTitle`, `mainBody`, `MainCard`, `CozyPage`, `IconBadge`의 기존 호출 호환성을 유지한다. 호출부 전체를 일괄 교체하는 새 래퍼는 만들지 않는다.
- [ ] `MainCard`의 패딩·모서리·그림자와 버튼의 최소 높이를 좁은 화면에서도 확인한다. 변경이 필요한 경우 기존 매개변수의 기본값만 조정한다.
- [ ] `design_system_test.dart`에서 테마의 배경/주색/입력 포커스 스타일과 공통 위젯의 기본 렌더링을 검증한다.
- [ ] `home_shell_navigation_test.dart`에서 홈, MomentLoop, 지도, 놀이, 더보기 탭 semantics와 화면 전환을 검증한다.
- [ ] `flutter test test/design_system_test.dart test/home_shell_navigation_test.dart`를 실행한다.
- [ ] `flutter analyze --no-pub`를 실행한다.
- [ ] 커밋: `chore(ui): align shared design surfaces`

**Acceptance:** 공통 토큰이 한 곳을 기준으로 동작하고, 기존 화면의 API 호출과 테스트를 깨지 않으며, 하단 5개 탭이 같은 순서와 의미로 노출된다.

## Task 2: 앱 셸·홈·더보기의 정보 계층 개선

**Files:**

- Modify: `apps/secret_base_app/lib/screens/home_shell.dart`
- Modify: `apps/secret_base_app/lib/screens/home/home_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/home/today_card.dart`
- Modify: `apps/secret_base_app/lib/screens/home/today_loop_viewer.dart`
- Modify: `apps/secret_base_app/lib/screens/home/memory_list_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/settings/settings_screen.dart`
- Modify: `apps/secret_base_app/test/home_screen_test.dart`
- Modify: `apps/secret_base_app/test/today_home_widgets_test.dart`
- Modify: `apps/secret_base_app/test/more_navigation_test.dart`
- Add: `apps/secret_base_app/test/home_shell_navigation_test.dart` if Task 1 did not need to create it

**Purpose:** 앱을 열었을 때 커플 정체성, 오늘의 상태, 바로 할 행동이 먼저 보이게 한다. 더보기는 현재의 그룹형 목록을 기준선으로 보존한다.

### Steps

- [ ] 홈의 첫 viewport를 `커플 정체성 → 오늘의 한 문장/이어보기 → 주 행동` 순서로 정리한다.
- [ ] 기존 quick action 다섯 항목이 화면 오른쪽에서 잘린 것처럼 보이지 않도록 2열 또는 명확한 가로 스크롤 구조를 적용한다. 구현 시 가장 작은 변경으로 탭 semantics와 기존 route를 유지한다.
- [ ] 각 quick action에 아이콘, 짧은 설명, 접근 가능한 label을 유지하고, 장식 텍스트를 추가해 정보 밀도를 높이지 않는다.
- [ ] 관계 이해 이어보기 카드는 진행 중일 때만 주 행동으로 보여주고, 진행 데이터가 없을 때는 짧은 설명과 진입 버튼을 제공한다.
- [ ] memory/today 카드에서 제목·날짜·주 행동의 대비를 높이고, 카드가 연속으로 쌓일 때 같은 레벨의 제목이 반복되지 않게 한다.
- [ ] home shell의 앱바/하단 NavigationBar safe area, 선택 상태, 탭 label의 긴 텍스트를 390px에서 확인한다.
- [ ] 더보기의 `내 공간`, `우리의 공간`, `기록과 이해` 그룹과 현재 route를 유지하면서 행 높이·아이콘·설명을 통일한다.
- [ ] 홈 테스트에서 quick action 전체 접근, 이어보기 상태, 빈 상태 CTA, refresh 상태를 검증한다.
- [ ] 더보기 테스트에서 모든 노출 행이 올바른 route로 이동하는지 검증한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] Chrome에서 로그인 사용자 홈과 더보기 화면을 390px/440px로 확인한다.
- [ ] 커밋: `feat(ui): clarify home shell and daily entry points`

**Acceptance:** 사용자가 홈에서 설명 없이 오늘의 핵심 상태와 다음 행동을 찾고, 모든 quick action과 더보기 행에 접근할 수 있다.

## Task 3: 관계 이해 허브와 검사 흐름 재구성

**Files:**

- Modify: `apps/secret_base_app/lib/screens/relationship/relationship_understanding_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/assessment_catalog_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/assessment_attempt_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/assessment_history_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/compatibility_screen.dart`
- Modify: `apps/secret_base_app/test/relationship_understanding_screen_test.dart`
- Modify: `apps/secret_base_app/test/assessment_catalog_screen_test.dart`
- Modify: `apps/secret_base_app/test/assessment_attempt_screen_test.dart`
- Modify: `apps/secret_base_app/test/assessment_history_screen_test.dart`
- Modify: `apps/secret_base_app/test/compatibility_screen_test.dart`

**Purpose:** 관계 이해 허브의 개인·커플·검사·궁합을 같은 카드 밀도로 쌓지 않고, 현재 상태와 진행 가능한 행동을 먼저 보여준다.

### Steps

- [ ] 허브 상단에 현재 탭의 목적을 한 줄로 표시하고 `개인`/`커플` 탭의 선택 상태 semantics를 명확히 한다.
- [ ] 개인 탭은 `진행 중인 검사 → 최근 결과 → 나의 사주/타로 → 마음관리` 순서로, 커플 탭은 `진행 중인 커플 검사 → 궁합 → 관계 사주/타로` 순서로 정리한다.
- [ ] 기존 assessment catalog가 제공하는 개인검사 4개/커플검사 3개의 수와 route를 유지한다.
- [ ] 검사 카드에 `시작`, `이어하기`, `결과 보기`, `다시 하기` 중 실제 상태에 맞는 하나의 주 행동만 노출한다.
- [ ] 진행률, 완료일, 기록 수, 최근 2회 비교 진입을 같은 메타 영역에 배치하고, 점수 자체를 새로 해석하거나 변경하지 않는다.
- [ ] 커플이 없거나 개인/커플 권한이 제한된 경우 기존 API 오류를 사용자용 설명과 연결 CTA로 변환한다.
- [ ] assessment attempt의 문항 화면은 질문과 선택지의 대비, 현재 진행률, 이전/다음 버튼의 고정 위치를 정리한다. 답변 저장 계약은 변경하지 않는다.
- [ ] history/comparison 화면은 현재 기록과 과거 기록의 날짜·상태·변화 비교 진입을 먼저 보여준다.
- [ ] 위젯 테스트에서 탭별 섹션 순서, 진행 상태별 CTA, 권한 제한 상태, 검사 제출/결과 route를 검증한다.
- [ ] 기존 API mock/fixture를 재사용하고, 새 fixture는 기존 응답 계약을 벗어나지 않는 최소 케이스만 추가한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] Chrome에서 개인/커플 탭, 검사 시작·이어하기·완료 상태를 확인한다.
- [ ] 커밋: `feat(ui): simplify relationship understanding flows`

**Acceptance:** 관계 이해 허브에서 사용자가 현재 범위와 다음 행동을 구분하고, 검사 진행·완료·기록을 한 번에 찾을 수 있다. 개인 데이터가 커플 탭에 섞이지 않는다.

## Task 4: 운세·사주·타로·마음관리·상담의 읽기 경험 개선

**Files:**

- Modify: `apps/secret_base_app/lib/screens/relationship/fortune_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/saju_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/tarot_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/mindcare_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/relationship/counseling_screen.dart`
- Modify: `apps/secret_base_app/test/fortune_screen_test.dart`
- Modify: `apps/secret_base_app/test/saju_screen_test.dart`
- Modify: `apps/secret_base_app/test/tarot_screen_test.dart`
- Modify: `apps/secret_base_app/test/mindcare_screen_test.dart`
- Modify: `apps/secret_base_app/test/mindcare_safety_screen_test.dart`
- Add or modify: `apps/secret_base_app/test/counseling_screen_test.dart`

**Purpose:** 사용자가 결과를 읽으며 `오늘은 무엇이 좋고, 무엇을 조심하고, 무엇이 힘이 되는지`를 알도록 만든다. 운세와 마음관리의 경계를 유지하고, 타로 선택 경험을 명확하게 한다.

### Fortune steps

- [ ] 개인/관계 scope를 제목과 범위 라벨에서 반복 설명하지 않고, 한 번에 인지할 수 있는 범위 배지로 표시한다.
- [ ] 결과의 읽는 순서를 `오늘의 한 줄 → 좋은 흐름 → 조심할 흐름 → 힘이 되는 행동 → 기준/안내`로 재배치한다.
- [ ] 기존 상단·하단 콘텐츠의 의미가 불명확한 경우 임의로 이름을 유지하지 말고, API content type에 맞춰 `오늘의 전체 흐름`, `마음의 날씨`, `우리 사이의 흐름`처럼 목적을 설명하는 섹션 제목을 사용한다.
- [ ] 각 섹션에 짧은 설명과 행동 가능한 한 문장을 배치하고, 같은 내용의 긴 문장을 여러 카드에 반복하지 않는다.
- [ ] 날짜, 사용한 입력 범위, 콘텐츠 버전/기준 설명은 결과 본문보다 낮은 시각 계층의 안내 영역에 둔다.
- [ ] 결과가 없거나 커플이 없거나 네트워크가 실패한 상태에는 원인과 재시도/파트너 연결/출생 프로필 수정 CTA를 제공한다.
- [ ] 운세는 예언·진단·치료가 아니라 자기성찰 콘텐츠라는 안내를 유지한다.

### Saju steps

- [ ] `쉽게 읽기`를 기본 결과로 두고, 전문 용어·천간·지지·오행·십신·계산 버전은 접을 수 있는 세부 영역으로 정리한다.
- [ ] 출생정보가 부족한 경우 `제한된 정보로 보기`와 `출생정보 수정하기`의 의미를 분리하고, 없는 시간을 기본값으로 표시하지 않는다.
- [ ] 개인 사주와 관계 사주를 같은 화면에 섞지 않고, 활성 Couple이 있을 때만 관계 결과를 별도 섹션으로 보인다.
- [ ] 기존 한국 표준시·지원 범위·입력 fingerprint/계산 버전 표시 계약을 유지한다.

### Tarot steps

- [ ] 개인/관계 섹션을 `나의 타로`와 `우리의 관계 타로`로 분리하고, 각 섹션의 범위를 카드 상단에 표시한다.
- [ ] 선택 전 22장 목록은 현재 구현된 `PageView` 캐러셀을 기반으로 유지한다. 모든 카드를 한 화면에 눌러 겹치는 부채꼴로 만들지 않는다.
- [ ] 중앙 카드는 주변 카드보다 크게, 양옆 카드는 일부만 보이게 하며, 현재 카드 위치·전체 수·좌우 이동 방법을 텍스트와 semantics로 알린다.
- [ ] 양옆 카드 탭은 중앙으로 이동만 하고 서버 draw를 호출하지 않는다. 중앙 카드 탭 또는 명시적 `이 카드로 보기` 버튼만 `_draw`를 호출한다.
- [ ] 선택 중에는 해당 캐러셀만 로딩 상태로 보여주고, 개인 선택 중 관계 섹션을 막지 않는다.
- [ ] 선택 후에는 카드 이미지/이름/한 줄 메시지/오늘의 질문/해석/기준 안내 순서로 보여주며, 같은 날짜의 재추첨 CTA를 만들지 않는다.
- [ ] 선택 전 카드 본문을 숨기고, 카드 key·position만 사용한다는 API 계약을 테스트로 고정한다.

### Mindcare and counseling steps

- [ ] 마음관리 첫 화면은 감정·상황·필요·작은 행동 선택의 순서로 구성하고, 자유 입력은 선택적 보조 기능으로 둔다.
- [ ] 위험 신호가 선택되면 일반 추천보다 안전 안내가 먼저 보이고, 현재 안전 확인·신뢰할 사람 연락·지역 전문/응급 리소스 연결을 제공한다.
- [ ] 자동 신고, 자동 통보, 진단/위험도 판정 문구를 추가하지 않는다.
- [ ] private/shared 상담 세션과 명시적 공유 힌트의 범위를 화면에서 구분하고, private 원문을 shared 카드에 자동 표시하지 않는다.

### Tests and delivery

- [ ] fortune 테스트에서 섹션 key, 날짜, 개인/커플 scope, 빈 상태 CTA, 오류 상태를 검증한다.
- [ ] saju 테스트에서 easy/professional 전환, 제한 결과, 출생정보 수정 CTA, 관계 결과 분리를 검증한다.
- [ ] tarot 테스트에서 22장 중앙 선택, 주변 카드 이동, 명시적 draw, 선택 후 재선택 차단, 개인/관계 독립 로딩을 검증한다.
- [ ] mindcare/safety/counseling 테스트에서 선택 단계, 위험 안내 우선순위, private/shared 범위를 검증한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] Chrome에서 운세·사주·타로의 loading/empty/ready/error를 확인하고, 타로 선택은 실제 서버에서 하루 한 장 계약을 소비할 수 있으므로 테스트 계정/fixture로 검증한다.
- [ ] 커밋: `feat(ui): make reflection surfaces readable and intentional`

**Acceptance:** 사용자가 운세 결과의 각 섹션 의미를 이해하고, 사주 전문 정보와 제한 범위를 구분하며, 타로에서 원하는 카드로 이동·확정하는 차이를 알 수 있다.

## Task 5: MomentLoop·홈 기록·공동 기록 상태 개선

**Files:**

- Modify: `apps/secret_base_app/lib/screens/archive/moment_loop_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/home/today_loop_viewer.dart`
- Modify: `apps/secret_base_app/lib/screens/home/memory_list_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/home/today_card.dart`
- Modify: `apps/secret_base_app/test/archive_screen_test.dart`
- Modify: `apps/secret_base_app/test/today_home_widgets_test.dart`
- Add or modify: `apps/secret_base_app/test/moment_loop_screen_test.dart`

**Purpose:** 현재 비어 있는 MomentLoop 화면에서도 사용자가 날짜 맥락과 `순간 남기기` 행동을 즉시 찾게 한다.

### Steps

- [ ] 주간 선택기와 현재 선택 날짜의 관계를 제목 영역에서 설명하고, 선택된 날짜가 색상만으로 구분되지 않게 한다.
- [ ] empty state를 `이번 주 첫 순간을 남겨보세요` 문장 하나에서 `현재 주간 상태 + 남길 수 있는 기록의 예 + 순간 남기기 CTA` 구조로 바꾼다.
- [ ] floating action button과 화면 내 CTA가 중복되면 주 CTA 하나를 우선하고, FAB에는 semantics label을 명시한다.
- [ ] 기록이 있을 때는 최신순/날짜순 규칙을 유지하면서 사진·텍스트·작성자·시간의 시각 계층을 통일한다.
- [ ] today loop viewer와 memory list에서 상세 보기/뒤로가기와 빈 상태가 동일한 언어를 쓰게 한다.
- [ ] refresh 중 콘텐츠 위치가 갑자기 초기화되지 않는지 확인한다.
- [ ] 테스트에서 주간 날짜 선택, 빈 상태 CTA, 기록 존재 상태, refresh와 route를 검증한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] Chrome에서 기록 없음/기록 있음/새 기록 진입을 확인한다.
- [ ] 커밋: `feat(ui): make moment loop actionable`

**Acceptance:** 데이터가 없는 사용자가 화면을 보고 무엇을 기록할지와 어디를 눌러야 하는지 즉시 알며, 데이터가 있는 사용자는 날짜와 기록을 빠르게 탐색한다.

## Task 6: 우리 지도의 운영 오류와 탐색 구조 개선

**Files:**

- Modify: `apps/secret_base_app/lib/screens/archive/map_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/archive/afterglow_section.dart`
- Modify: `apps/secret_base_app/test/map_screen_test.dart`
- Modify: `apps/secret_base_app/test/afterglow_section_test.dart`
- Inspect and modify only if required by the existing map configuration: `apps/secret_base_app/pubspec.yaml`, platform web/index configuration, deployment environment configuration referenced by the current map widget

**Purpose:** 운영 화면에 반복되는 `API KEY REQUIRED`를 제거하고, 지도·검색·필터·장소 카드·빈 상태를 한 흐름으로 이해하게 한다.

### Steps

- [ ] 현재 `flutter_map` 타일 레이어와 타일 URL/configuration 경로를 추적해 어떤 설정이 운영에서 오류 문자열을 만드는지 확인한다.
- [ ] 기존 설정 주입 방식이 있으면 그 경로를 고치고, 새 비밀값을 코드나 저장소에 하드코딩하지 않는다.
- [ ] 지도 공급자 설정이 없는 환경에서는 내부 타일 오류를 노출하지 않고, `지도를 불러올 수 없어요`와 검색/목록 기반 대체 행동을 제공한다.
- [ ] 검색 입력, 검색 결과, 카테고리 필터, 방문/위시리스트 상태의 선택 스타일을 같은 규칙으로 정리한다.
- [ ] 핀 데이터가 없을 때 지도 중심부의 큰 빈 공간 대신 `아직 우리 지도가 비어 있어요`와 장소 추가 CTA, 검색 CTA, 위치 권한 설명을 함께 제공한다.
- [ ] 위치 권한 거부와 네트워크 실패를 서로 다른 사용자 문구로 구분하되, 좌표나 내부 예외를 출력하지 않는다.
- [ ] 장소 상세/afterglow 입력 흐름은 기존 API payload와 사진 업로드 동작을 유지한다.
- [ ] 테스트에서 지도 데이터 없음, 핀 존재, 필터, 검색 실패, 위치 거부, 공급자 설정 오류 대체 상태를 검증한다.
- [ ] 실제 배포 환경에서 지도에 설정 오류 텍스트가 없는지 Chrome으로 확인한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] 커밋: `fix(ui): make map fallback safe and useful`

**Acceptance:** 프로덕션 지도에서 공급자 내부 오류가 반복되지 않고, 데이터/권한/네트워크 상태별로 사용자가 다음 행동을 찾을 수 있다.

## Task 7: 놀이 로비와 게임 공통 흐름 개선

**Files:**

- Modify: `apps/secret_base_app/lib/screens/arcade/arcade_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/arcade/game_lobby_screen.dart`
- Modify: `apps/secret_base_app/lib/widgets/game_scaffold.dart`
- Modify: `apps/secret_base_app/lib/widgets/game_menu.dart`
- Modify: `apps/secret_base_app/lib/widgets/game_session_presence.dart`
- Modify: `apps/secret_base_app/lib/screens/arcade/games/*.dart` only where shared scaffold integration is needed
- Modify: `apps/secret_base_app/test/game_session_resume_test.dart`
- Modify: `apps/secret_base_app/test/dice_screen_test.dart`
- Add or modify: `apps/secret_base_app/test/arcade_screen_test.dart`

**Purpose:** 놀이 첫 화면의 잘린 게임 목록과 큰 빈 패널을 개선하고, 게임 내부는 규칙을 건드리지 않으면서 시작·재개·나가기 흐름을 통일한다.

### Steps

- [ ] 코인 잔액·출석·상점은 보조 상태로 묶고, 게임 선택 제목과 주 행동보다 시각적 우선순위를 낮춘다.
- [ ] 15개 게임 목록이 더 있다는 사실이 명확하도록 2열 목록 또는 스크롤 힌트가 있는 가로 목록으로 정리한다. 각 게임의 route와 잠금/사용 가능 상태는 유지한다.
- [ ] 게임을 선택하기 전 빈 패널에 `게임 고르기` 안내와 선택 결과가 어떻게 나타나는지 짧은 예시를 보여준다.
- [ ] 게임 선택 후 시작 버튼, 현재 세션 재개, 나가기/뒤로가기의 위치와 semantics를 통일한다.
- [ ] `GameScaffold`와 `GameMenu`를 먼저 수정해 모든 게임에 공통으로 적용하고, 게임별 파일에 같은 헤더를 반복 추가하지 않는다.
- [ ] 게임별 규칙, 턴, 서버 메시지, 코인 계산은 변경하지 않는다.
- [ ] 현재 재개 세션과 상대방 접속 상태 표시가 공통 헤더에서 잘리지 않는지 확인한다.
- [ ] 테스트에서 게임 목록 전체 접근, 선택 상태, 세션 재개, 게임 종료/뒤로가기 route를 검증한다.
- [ ] 대표 게임 3종 이상과 카드/보드 게임에서 390px 화면을 확인한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] 커밋: `feat(ui): clarify play lobby and game entry`

**Acceptance:** 사용자가 15개 게임을 발견하고 선택할 수 있으며, 게임 규칙은 바뀌지 않은 채 시작·재개·나가기 흐름이 일관된다.

## Task 8: 비밀기지·상점·인벤토리·계정·인증 표면 정리

**Files:**

- Modify: `apps/secret_base_app/lib/screens/secret_base/secret_base_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/secret_base/base_postcard_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/shop/shop_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/shop/inventory_tab.dart`
- Modify: `apps/secret_base_app/lib/screens/settings/settings_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/entry_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/auth/auth_layout.dart`
- Modify: `apps/secret_base_app/lib/screens/auth/login_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/auth/register_screen.dart`
- Modify: `apps/secret_base_app/lib/screens/auth/partner_screen.dart`
- Modify: `apps/secret_base_app/test/more_navigation_test.dart`
- Add or modify: `apps/secret_base_app/test/auth_screen_test.dart`
- Add or modify: `apps/secret_base_app/test/shop_screen_test.dart`

**Purpose:** 더보기에서 들어가는 보조 표면도 앱의 주요 화면과 같은 읽기 규칙을 가지게 한다. 인증과 파트너 연결은 신뢰와 오류 회복을 우선한다.

### Steps

- [ ] 비밀기지는 현재 콘텐츠/엽서/빈 상태/새 글 행동을 하나의 계층으로 정리하고, 개인·커플 범위를 화면에서 구분한다.
- [ ] 상점은 코인 잔액, 구매 가능한 항목, 구매 결과를 분리한다. 구매 버튼에는 비용과 결과를 함께 표시하고, 중복 탭을 방지한다.
- [ ] 인벤토리는 보유 없음, 보유 있음, 사용 불가 상태를 구분하고 아이템 설명과 사용 CTA를 명확히 한다.
- [ ] 로그인·회원가입 폼은 브랜드 설명보다 입력 label, 오류 위치, 제출 상태, 재시도 방법을 우선한다.
- [ ] 파트너 연결은 현재 상태, 초대/코드 입력, 연결 완료, 만료/실패를 단계별로 보여준다. 파트너의 민감 데이터를 불필요하게 노출하지 않는다.
- [ ] 인증 화면의 키보드가 CTA를 가리지 않는지, 로딩 중 중복 제출이 막히는지 확인한다.
- [ ] 테스트에서 인증 오류/성공, 파트너 연결 상태, 상점 구매/보유 없음, 비밀기지 빈 상태를 검증한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] 로그아웃/재로그인 포함 실제 브라우저 흐름을 확인한다.
- [ ] 커밋: `feat(ui): polish private space, shop, and auth surfaces`

**Acceptance:** 보조 화면에서도 사용자가 상태와 행동을 구분하고, 인증·파트너·구매 실패에서 복구 경로를 잃지 않는다.

## Task 9: 노출되는 보조 기록 화면과 게임 내부 시각 회귀 정리

**Files:**

- Modify only for reachable surfaces: `afterglow_section.dart`, `album_screen.dart`, `capsule_screen.dart`, `challenge_screen.dart`, `heart_exchange_screen.dart`, `jukebox_screen.dart`, `monthly_report_screen.dart`, `personal_history_screen.dart`, `shelter_screen.dart`, `timeline_screen.dart`, `vault_screen.dart`, `wish_ticket_screen.dart`
- Modify only for shared visual regressions: `ui/bomb_board.dart`, `ui/character_painters.dart`, `ui/hwatu_card.dart`, `ui/marble_board.dart`, `ui/uno_board.dart`, `ui/yut_board.dart`
- Modify corresponding existing tests; add a test only for a currently reachable screen without coverage

**Purpose:** 메인 흐름에서 실제로 도달 가능한 보조 화면에만 공통 제목·빈 상태·뒤로가기·safe area 규칙을 적용한다. 숨겨진 화면을 새로 노출하거나, 규칙이 다른 게임 보드의 내부 디자인을 이 단계에서 재작성하지 않는다.

### Steps

- [ ] `home_shell.dart`, `settings_screen.dart`, `archive_screen.dart`와 route 호출을 기준으로 실제 도달 가능한 보조 화면을 목록화한다.
- [ ] 도달 가능한 화면은 제목·한 줄 설명·주 행동·loading/empty/error를 같은 표현으로 정리한다.
- [ ] 도달하지 않는 레거시 화면은 코드 변경 대신 계획 범위에서 제외하고, 메인 네비게이션에 다시 추가하지 않는다.
- [ ] 게임 보드는 게임 규칙/좌표/터치 판정을 변경하지 않고, 이미 확인된 overflow·contrast·semantics 회귀만 수정한다.
- [ ] 기존 phase2/game/board 테스트를 먼저 실행하고, 시각 변경으로 필요한 최소 assertion만 갱신한다.
- [ ] 관련 테스트와 `flutter analyze --no-pub`를 실행한다.
- [ ] 커밋: `chore(ui): align reachable secondary surfaces`

**Acceptance:** 실제 사용자가 도달하는 보조 화면에만 일관된 표면 규칙이 적용되고, 숨겨진 기능과 게임 규칙에는 불필요한 변경이 없다.

## Task 10: 전역 접근성·반응형·성능·배포 검증

**Files:**

- Modify only where verification finds a real issue in the affected screen files
- Add: `docs/superpowers/plans/` execution notes only if a release record is required by the repository workflow
- Do not modify: backend contracts, deployment secrets, unrelated `test-results/` files

**Purpose:** 전체 프론트 개편을 실제 출시 가능한 상태로 검증하고, 다음 작은 개선으로 이어질 관찰 결과를 남긴다.

### Steps

- [ ] `flutter analyze --no-pub`를 실행한다.
- [ ] `flutter test`를 전체 실행하고 실패를 화면별로 분류한다.
- [ ] 기존 API 테스트를 포함해 fortune, saju, tarot, mindcare, assessment, map, home, archive, game 대표 테스트가 모두 통과하는지 확인한다.
- [ ] Chrome에서 로그인 후 다음 경로를 순서대로 확인한다: 홈 → MomentLoop → 지도 → 놀이 → 더보기 → 관계 이해 → 운세 → 사주 → 타로 → 마음관리 → 비밀기지/상점.
- [ ] 각 경로에서 loading, ready, empty, error 또는 restricted 상태 중 실제로 재현 가능한 상태를 확인한다.
- [ ] 390×844와 440×880에서 상단 제목, 가로 목록, 중앙 타로 카드, 하단 CTA, 하단 NavigationBar가 잘리지 않는지 확인한다.
- [ ] 키보드/스크린 리더가 접근 가능한 주요 버튼과 탭의 label을 확인한다.
- [ ] 지도에서 `API KEY REQUIRED`, 내부 exception, 좌표/토큰이 화면에 없는지 검색한다.
- [ ] 브라우저 콘솔과 Flutter 로그에서 새로 발생한 레이아웃 overflow, 반복 API 호출, 중복 제출을 확인한다.
- [ ] 프로덕션 배포 workflow를 실행하고 성공 여부를 확인한다.
- [ ] 배포 후 `https://secretbase.cloud/health` 또는 현재 배포에서 사용하는 health endpoint를 확인한다.
- [ ] 주요 화면의 최종 캡처와 테스트 결과를 `test-results/` 아래 기존 방식에 맞춰 기록하되, 사용자 데이터가 포함된 캡처는 저장소에 커밋하지 않는다.
- [ ] 커밋: `chore(ui): verify frontend redesign for release`

**Acceptance:** 정적 분석·전체 테스트·실제 주요 경로·반응형·접근성·프로덕션 health check가 모두 통과하고, 배포 후 핵심 화면이 계획한 정보 계층으로 보인다.

## Completion Checklist

- [ ] Task 1–10의 커밋이 순서대로 존재한다.
- [ ] 현재 메인 탭 5개와 기존 route 계약이 유지된다.
- [ ] 운세의 상단/하단 의미가 설명 가능한 섹션으로 정리된다.
- [ ] 사주 입력 부족/전문 보기/관계 범위가 명확하다.
- [ ] 타로는 카드 전체가 뭉개지지 않고 중앙 카드 중심 캐러셀로 선택된다.
- [ ] 지도 운영 오류 문자열이 사용자에게 노출되지 않는다.
- [ ] 빈 상태와 오류 상태에 다음 행동이 있다.
- [ ] 개인·커플 데이터 경계와 안전 문구가 유지된다.
- [ ] `flutter analyze --no-pub`와 `flutter test`가 통과한다.
- [ ] 배포 workflow와 health check가 성공한다.
