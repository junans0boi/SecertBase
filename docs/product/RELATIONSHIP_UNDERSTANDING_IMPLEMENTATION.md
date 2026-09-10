# 관계 이해 기능 구현 정리

기준일: 2026-09-10
기준 브랜치: `main`
제품 영역: 출생 프로필, 개인·커플 심리검사, 궁합 분석, 운세, 상담

이 문서는 스펙을 다시 쓰는 문서가 아니라 현재 저장소에 들어온 구현을 빠르게 파악하기 위한 as-built 문서다. 제품 원칙과 결정은 [관계 이해 기반 스펙](./RELATIONSHIP_ASSESSMENT_FOUNDATION_SPEC.md), [운세·마음관리 확장 스펙](./FORTUNE_AND_MINDCARE_EXPANSION_SPEC.md), [ADR](../adr/)을 따른다.

## 현재 상태

- 운영 데이터베이스 기준은 PostgreSQL이 아니라 현재 서버와 마이그레이션 체계인 MariaDB/MySQL이다.
- 핵심 검사 결과는 LLM 없이 동작한다. 점수·차원·전체 경향·권한은 결정론적으로 계산한다.
- LLM은 선택적 자연어 설명 계층이다. 무료 provider가 비활성화되거나 실패해도 고정 설명으로 결과를 표시한다.
- 개인검사와 커플검사는 상단 탭으로 분리한다. 하단 네비게이션에 새 탭을 추가하지 않는다.
- 개인검사 기록은 최신 결과와 과거 결과를 모두 보존하며, 기록 항목을 누르면 문항별 선택 답변을 읽기 전용으로 확인할 수 있다.
- 검사 변화 비교는 인증 REST가 같은 버전의 최근 두 개인·커플 기록만 계산하고, Flutter 기록 화면이 중립적인 변화 카드와 접근성 문장을 표시한다. 기록이 한 건뿐이면 재검사 안내를 보여준다. 계약은 [ADR 0010](../adr/0010-assessment-change-comparison-contract.md)을 따른다.
- 개인 사주 첫 vertical slice와 관계 사주 요약이 들어왔다. 서버는 `k-saju@0.1.4`와 고정 규칙 세트로 1900–2050년 한국 표준시 입력을 계산하고, 윤달 여부·출생지 문자열·입춘/절기·자시 경계를 결과에 보존한다. Flutter는 네 기둥·일간·오행·십신·일주·성찰 질문을 쉬운 설명으로 먼저 보여주고 같은 계산 결과의 전문 용어를 펼쳐 볼 수 있다. 활성 Couple이 있으면 원본 명식이나 점수 없이 오행·일간 패턴 카드와 대화 질문만 함께 반환한다. 타로는 메이저 22장 정방향 카탈로그를 개인·Couple 범위로 보여주고 사용자가 직접 고른 카드를 날짜에 고정해 저장하며, 선택 전에는 카드 뒷면 선택 UI를 제공한다. 마음관리 가이드는 고정 taxonomy와 10단계 개인 비공개 대화, 빠른 선택지·선택적 자유 입력, 위험 표현 후보의 명시적 안전 확인까지 구현했다. 계산 참고 원문은 [프로젝트 참조 PDF](./reference/saju/23-saju-120-day-challenge.pdf)로 고정한다.
- 출생 프로필이 저장된 사용자는 관계 이해 허브에서 입력 폼을 보지 않는다. 수정은 설정의 프로필 수정에서 한다.
- `main`에는 기능 코드와 테스트가 합쳐져 있다. 운영 배포 및 운영 DB 마이그레이션 적용 여부는 별도 배포 확인이 필요하다.

현재 구현은 기존 `오늘의 운세` 호환 API를 유지하면서 관계 이해 허브에서 개인 사주
페이지와 타로 페이지, 마음관리 가이드 페이지로 진입하는 경로를 추가한 상태다. 위험
표현 후보의 안전 확인, 버전 JSON 리소스 API, Flutter의 일회성 위치 권한 요청과
국가·행정지역만 전송하는 안전 화면 연결까지 구현했다. 검사 변화 비교도 인증 REST와
Flutter 기록 카드에서 동작한다. 상담사 marketplace는 포함하지 않으며, 위험 신호는
일반 추천보다 상황별 안전 안내를 먼저 보여주는 별도 콘텐츠 범위로 다룬다.

## 사용자 흐름

1. 홈의 관계 이해 카드에서 허브로 진입한다.
2. 출생 프로필이 없으면 허브에서 입력한다. 저장된 경우 허브에는 입력 폼 대신 저장 상태만 보인다.
3. 허브 상단 탭에서 `개인` 또는 `커플` 영역을 선택한다.
4. 개인검사 카드에서 상태를 확인한다.
   - `검사 시작하기`: 새 시도 생성
   - `검사 이어하기`: 진행 중 시도 복원
   - `다시 검사하기`: 새 재검사 시도 생성
   - `기록 보기`: 완료 기록 목록 열기
5. 기록 목록에서 현재 결과 또는 과거 결과를 누르면 상세 화면으로 이동한다.
6. 상세 화면에서 전체 점수, 차원 점수, 문항, 당시 선택한 5점 리커트 답변을 확인한다. 과거 기록은 수정하지 않는다.
7. 커플 영역에서는 두 사람의 완료 상태에 따라 대기·준비·결과 카드를 표시한다.
8. 허브 개인 영역의 `사주 보기`에서 개인 사주 페이지로 이동한다. 출생 시각·출생지가
   없으면 `출생정보 수정하기` 또는 `네`를 선택해 제한 명식을 확인한다.

## 검사 구성

### 개인검사

| 코드 | 검사 | 차원 |
| --- | --- | --- |
| `attachment` | 애착과 안정감 | 확인과 안심, 거리와 자율성, 감정 표현 |
| `social_bonding` | 사회적 유대와 연결 | 관계의 깊이, 의존과 균형, 고립감 인식 |
| `emotional_regulation` | 감정 해소와 조절 | 내부 처리, 외부 자극, 대화 선호 |
| `relationship_deficiency` | 관계의 결핍 인식 | 자기 인식, 파트너 기대, 대안 자원 인식 |

### 커플검사

| 코드 | 검사 | 차원 |
| --- | --- | --- |
| `conflict_repair` | 갈등과 회복 방식 | 갈등 신호, 회복 행동, 대화 안전감 |
| `togetherness_personal_time` | 함께 있음과 개인 시간 | 함께 있음, 개인 시간, 조율 |
| `affection_alignment` | 애정 표현과 기대의 일치 | 애정 표현, 기대, 일치와 조율 |

모든 검사 버전은 후보 문항 24개와 활성 문항 12개를 가진다. 실제 응답은 활성 문항에 대해 `전혀 그렇지 않다`부터 `매우 그렇다`까지 5점 리커트로 받으며, 역채점 여부는 문항 정의에 보존한다.

## 데이터와 권한

### 사용자 범위

- 출생 프로필
- 개인검사 시도와 진행 답변
- 개인검사 결과와 결과 history
- 개인 상담 세션과 원문

개인검사 원문과 개인 결과는 파트너용 API 또는 공유 궁합 API에서 반환하지 않는다. 완료된 결과는 원본 시도와 문항별 답변을 연결한 채 보존한다.

### 커플 범위

- 커플검사 시도 조합 결과
- 개인 결과의 허용된 요약만 사용한 궁합 분석
- 커플검사 결과 기반 궁합 분석
- 관계 운세
- 공개 커플 상담
- 사용자가 명시적으로 승인한 공유 힌트

커플검사는 두 사람이 같은 버전을 완료해야 공유 결과가 준비된다. 연결이 해제되면 활성 커플이 필요한 공유 API는 차단되고, 개인검사 history와 프라이빗 상담은 사용자 범위로 남는다.

### 현재 보안 한계

프라이빗 상담 원문은 일반 사용자 API와 파트너에게 노출되지 않지만, 현재 저장 암호화와 운영자 접근 감사는 적용하지 않는다. 서버 운영자는 운영 DB 권한으로 원문을 볼 수 있다. 이 제한은 제품 보안 부채로 남아 있으며 별도 보안 작업이 필요하다.

## REST API 표면

모든 요청은 기존 JWT 인증과 `{ ok: true, ... }` / `{ ok: false, reason: ... }` 응답 규칙을 따른다.

### 출생 프로필·검사

```text
GET    /api/relationship/birth-profile
PATCH  /api/relationship/birth-profile
GET    /api/relationship/assessments
GET    /api/relationship/assessments/:code/attempt
POST   /api/relationship/assessments/:code/attempt
GET    /api/relationship/couple-assessments/:code/attempt
POST   /api/relationship/couple-assessments/:code/attempt
PATCH  /api/relationship/assessment-attempts/:attemptId/answers/:questionKey
POST   /api/relationship/assessment-attempts/:attemptId/submit
POST   /api/relationship/couple-assessment-attempts/:attemptId/submit
GET    /api/relationship/assessment-results/:code/current
GET    /api/relationship/assessment-results/:code/history
```

`history` 응답에는 결과 요약과 함께 `questionKey`, 문항 내용, 문항 순서, 차원, 선택값, 리커트 라벨, 역채점 여부가 포함된다. Flutter는 이 응답을 기록 상세 화면에서 읽기 전용으로 표시한다.

### 궁합·설명 생성

```text
GET    /api/relationship/compatibility/current
GET    /api/relationship/compatibility/:code/current
GET    /api/relationship/explanations/personal/:code/current
POST   /api/relationship/explanations/personal/:code
GET    /api/relationship/explanations/compatibility/:code/current
POST   /api/relationship/explanations/compatibility/:code
```

설명 생성 요청은 명시적인 POST에서만 실행된다. 설명 생성은 구조화된 결과를 보조하며 점수나 공개 범위를 변경하지 않는다.

### 운세·상담

```text
GET    /api/relationship/fortune/today
POST   /api/relationship/fortune/today/regenerate
POST   /api/relationship/counseling/private/sessions
GET    /api/relationship/counseling/private/sessions
GET    /api/relationship/counseling/private/sessions/:sessionId
POST   /api/relationship/counseling/private/sessions/:sessionId/messages
POST   /api/relationship/counseling/private/sessions/:sessionId/archive
POST   /api/relationship/counseling/private/sessions/:sessionId/insights
GET    /api/relationship/counseling/private/insights
POST   /api/relationship/counseling/insights/:insightId/revoke
POST   /api/relationship/counseling/shared/sessions
GET    /api/relationship/counseling/shared/sessions
GET    /api/relationship/counseling/shared/sessions/:sessionId
POST   /api/relationship/counseling/shared/sessions/:sessionId/messages
POST   /api/relationship/counseling/shared/sessions/:sessionId/archive
GET    /api/relationship/counseling/shared/insights
POST   /api/relationship/mindcare/sessions
GET    /api/relationship/mindcare/sessions
GET    /api/relationship/mindcare/sessions/:sessionId
POST   /api/relationship/mindcare/sessions/:sessionId/messages
POST   /api/relationship/mindcare/sessions/:sessionId/safety
GET    /api/relationship/mindcare/safety-resources
GET    /api/relationship/assessment-results/:code/comparison
GET    /api/relationship/couple-assessment-results/:code/comparison
GET    /api/relationship/tarot/today
POST   /api/relationship/tarot/today/draw
```

개인 사주 첫 slice는 기존 운세 저장소와 별도의 결과 저장소를 사용한다.

```text
GET    /api/relationship/saju
POST   /api/relationship/saju
```

`GET`은 완전한 프로필이면 `ready` 결과를 계산하고, 출생 시각·출생지 또는 한국
시간대가 제한되는 경우 `saju_limited_confirmation_required`를 반환한다. `POST`는
`{ "mode": "limited" }` 같은 명시적 선택 뒤에만 제한 결과를 계산한다. 결과에는
`calculationVersion`, `inputSummary`, `basis`, `limitations`, `plain`, `technical`이
포함되며 파트너 원본 명식은 포함하지 않는다.
활성 Couple이 있으면 `relationship`에 `scope: couple`, `patterns`,
`conversationQuestions`만 추가되며 점수·파트너 원본 명식·technical 필드는 반환하지
않는다. Couple 요약은 `0036_relationship_saju_couple_results`에 별도로 저장한다.

마음관리 API는 기존 `relationship_counseling_*`와 별도로 `relationship_mindcare_*`에
상태·응답 수·콘텐츠 버전·메시지를 저장한다. 최근 미완료 세션 하나를 재개하며,
파트너 계정에는 404로 응답한다. 감정 8개·상황 6개·필요 6개·작은 행동 24개를
고정 콘텐츠로 제공하고, 위험 표현 후보가 있으면 정상 진행을 멈추고 안전 확인으로
전환한다. 안전 리소스는 `safety-kr-v1` 버전 JSON과 일반 fallback을 사용하며,
좌표를 받거나 저장하지 않는다. Flutter는 `geolocator`로 권한을 확인하고
`geocoding`으로 한 번 얻은 위치를 즉시 국가·행정지역으로 줄인 뒤 좌표를 폐기한다.
권한 거부·서비스 불가·역지오코딩 실패는 인증 `safety-resources` API의 일반 fallback을
화면에 표시한다.

## DB 마이그레이션

관계 이해 데이터는 순차 마이그레이션으로 관리한다.

| 마이그레이션 | 책임 |
| --- | --- |
| `0023_user_birth_profile` | 사용자 출생 프로필 확장 |
| `0024_relationship_assessment_catalog` | 검사, 버전, 차원, 후보·활성 문항 |
| `0025_relationship_assessment_attempts` | 검사 시도와 문항별 임시 응답 |
| `0026_relationship_assessment_results` | 완료 결과와 원본 시도 연결 |
| `0027`–`0028` | 커플 시도 범위와 커플검사 조합 결과 |
| `0029`–`0031` | 개인·커플 기반 궁합 분석 |
| `0032` | 설명 생성 상태·provider 메타데이터 |
| `0033` | 날짜·콘텐츠 버전별 운세 |
| `0034` | 프라이빗/공유 상담과 공유 힌트 |
| `0035` | 윤달 입력과 버전·fingerprint별 개인 사주 결과 |
| `0036` | Couple 범위 관계 사주 요약 결과 |
| `0037` | 개인·Couple 날짜 고정 타로 카드 |
| `0038` | 개인 비공개 마음관리 guided chat 상태와 메시지 |
| `0039` | 타로 자동 생성 row와 사용자 선택 row 구분 |

운영 배포 시 기존 migration runner를 사용한다. 요청 처리 중 테이블을 새로 만드는 방식으로 확장하지 않는다.

## Flutter 구현 위치

```text
apps/secret_base_app/lib/screens/relationship/relationship_understanding_screen.dart
apps/secret_base_app/lib/screens/relationship/assessment_catalog_screen.dart
apps/secret_base_app/lib/screens/relationship/assessment_attempt_screen.dart
apps/secret_base_app/lib/screens/relationship/assessment_history_screen.dart
apps/secret_base_app/lib/screens/relationship/compatibility_screen.dart
apps/secret_base_app/lib/screens/relationship/fortune_screen.dart
apps/secret_base_app/lib/screens/relationship/saju_screen.dart
apps/secret_base_app/lib/screens/relationship/tarot_screen.dart
apps/secret_base_app/lib/screens/relationship/mindcare_screen.dart
apps/secret_base_app/lib/screens/relationship/counseling_screen.dart
apps/secret_base_app/lib/core/birth_profile_api.dart
apps/secret_base_app/lib/core/saju_api.dart
apps/secret_base_app/lib/core/assessment_catalog_api.dart
apps/secret_base_app/lib/core/assessment_attempt_api.dart
apps/secret_base_app/lib/core/compatibility_api.dart
apps/secret_base_app/lib/core/fortune_api.dart
apps/secret_base_app/lib/core/tarot_api.dart
apps/secret_base_app/lib/core/mindcare_api.dart
apps/secret_base_app/lib/core/safety_location.dart
apps/secret_base_app/lib/core/counseling_api.dart
```

## 검증 기준

관계 이해 기능의 외부 동작은 다음 테스트 묶음으로 확인한다.

- Node REST integration: `services/realtime-server/test/*relationship*.integration.test.js`, `*assessment*.integration.test.js`
- Flutter API/widget: `apps/secret_base_app/test/assessment_*_test.dart`, `relationship_understanding_screen_test.dart`, `compatibility_screen_test.dart`, `fortune_api_test.dart`, `counseling_api_test.dart`
- 사주 첫 slice: `services/realtime-server/test/relationship-saju.test.js`, `saju.integration.test.js`, `apps/secret_base_app/test/saju_api_test.dart`, `saju_screen_test.dart`
- 기록 상세 동작: `assessment_history_screen_test.dart`에서 결과 행 탭, 문항, 선택 답변, 읽기 전용 문구를 검증한다.
- 마음관리 안전 흐름: `safety_api_test.dart`와 `mindcare_safety_screen_test.dart`에서
  지역 리소스, 좌표 미전송, 권한 거부 일반 fallback, 접근성 label을 검증한다.

자동 테스트가 운영 API 배포를 대신하지는 않는다. 특히 현재 로컬 Flutter를 운영 API 프록시에 연결해 확인하는 경우, 저장소에 새로 추가된 `history.answers` 응답이 운영 백엔드에 배포되기 전에는 결과 상세 화면에 문항별 답변이 나타나지 않을 수 있다.

## 남은 작업과 비범위

- 운영 백엔드에 최신 migration과 history 답변 응답을 배포하고 실제 계정으로 smoke test할 것
- 프라이빗 원문 저장 암호화와 운영자 접근 감사
- 임상 검사지 라이선스·임상가 검토·위기 대응 체계
- 스트리밍, 백그라운드 생성, 알림, 유료 provider 운영
- 테스트 DB/Redis URL을 제공한 인증 REST smoke test와 migration 적용 확인
- 실제 기기에서 위치 권한 허용·거부 및 한국 행정지역 역지오코딩을 확인하는 수동 beta 점검
