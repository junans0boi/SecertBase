# SecretBase 핵심 기능 유지보수 구조 설계

- 날짜: 2026-10-07
- 상태: 제안됨 — 구현 전 사용자 검토 필요
- 범위: Flutter Home·MomentLoop·Couple 경계와 이를 받치는 Node 백엔드 경계
- 제외: 게임 내부 전면 재작성, UI 디자인 개편, OmniRoute, 마이크로서비스 분리

## 1. 목표와 합의된 방향

SecretBase가 기능을 계속 추가해도 핵심 관계 기록 흐름이 게임이나 레거시 기능 때문에 흔들리지 않도록 구조를 개선한다. 지금 가장 중요한 제품 경로는 로그인·커플 상태·Home·MomentLoop이며, 게임은 현재 구현을 유지하면서 독립된 Play 영역으로 격리한다.

성공 기준은 파일 수를 늘리는 것이 아니라 다음 변경 비용을 낮추는 것이다.

- Home에 새 카드나 진입점을 추가해도 API 호출·관계검사·네비게이션 코드를 한 화면에 계속 쌓지 않는다.
- MomentLoop의 기록 목록, 미디어 업로드, 스토리 보기, 오늘의 순간, 지도 연결을 각각 독립적으로 테스트하고 변경한다.
- 사용자와 활성 Couple 권한이 화면·라우트마다 다르게 해석되지 않는다.
- 게임을 건드리지 않고도 Home·MomentLoop·관계 기능을 개선할 수 있다.
- 기존 REST·Socket 이벤트와 사용자 동작은 점진적 이전 동안 유지한다.

## 2. 현재 구조와 문제

현재 구조에는 재사용할 좋은 기반과 명확한 결합 지점이 함께 있다.

### 유지할 기반

- Yut, UNO, RPS 등 게임 규칙 엔진은 별도 파일과 테스트를 가진다.
- `migrations/`와 마이그레이션 CLI가 이미 존재한다.
- Couple lifecycle, Map ownership, MomentLoop clip, Today Moment 같은 정책 모듈이 일부 추출되어 있다.
- REST와 통합 테스트가 충분히 존재하므로 동작 보존형 이전이 가능하다.

### 우선 개선할 결합

- `apps/secret_base_app/lib/core/socket_service.dart`는 연결, presence, lobby, 모든 게임 상태와 UI observable state를 한 클래스에 포함한다.
- `apps/secret_base_app/lib/screens/home/home_screen.dart`는 Couple 정보, memory card, assessment catalog, Today API를 직접 호출하고 여러 기능 화면으로 직접 이동한다.
- `apps/secret_base_app/lib/screens/archive/moment_loop_screen.dart`는 feed, story viewer, detail, reaction, Today Moment, multipart upload, map picker와 상태 관리를 한 파일에 포함한다.
- `services/realtime-server/src/routes.js`는 라우트, 인증, SQL, 도메인 규칙, 응답 직렬화를 한 파일에 포함한다.
- `services/realtime-server/src/socket.js`는 모든 realtime game event와 Redis 상태 변경을 한 파일에 포함한다.
- 일부 요청 처리 경로가 `CREATE TABLE`·`ALTER TABLE`을 실행한다. 스키마 변경은 런타임이 아니라 migration CLI가 담당해야 한다.
- MVP 문서의 공개 게임 범위와 실제 `PUBLIC_GAME_TYPES`·socket game allowlist가 분리되어 있어 기능 공개 상태가 어긋날 위험이 있다.

이 문제는 “모든 파일을 새 폴더로 옮기면 해결되는 문제”가 아니다. 각 Module의 Interface를 줄이고, 구현 세부사항이 다른 기능으로 새어 나가지 않게 하는 것이 핵심이다.

## 3. 검토한 접근과 선택

### A. 점진적 Core-first Modular Monolith — 선택

단일 Flutter 앱과 단일 Node 서버를 유지하면서, 핵심 기능부터 feature-first 경계를 만든다. 기존 API와 게임 코드는 유지하고 adapter와 controller를 앞에 둔 뒤 한 기능씩 이전한다.

- 장점: 배포·운영 복잡도가 늘지 않고, 현재 테스트와 사용자 흐름을 보존한다.
- 장점: Home과 MomentLoop를 먼저 개선하면서 구조 개선의 효과를 바로 확인한다.
- 단점: 이전 기간 동안 구구조와 신구조가 함께 존재한다.
- 선택 이유: 현재 프로젝트의 위험은 확장성 부족보다 큰 모듈과 권한 경계가 섞여 있는 것이다.

### B. Flutter 상태관리·라우팅 프레임워크와 백엔드 모듈을 한 번에 교체

Riverpod/Bloc/GoRouter를 도입하고 Flutter와 Node를 동시에 재배치한다.

- 장점: 새 구조는 깨끗하게 시작할 수 있다.
- 단점: 의존성·수명주기·라우팅·상태 변경이 한 번에 바뀌어 회귀 원인 추적이 어렵다.
- 단점: 게임과 비게임 기능의 변경 범위가 불필요하게 묶인다.
- 판단: 장기적으로도 현재 규모의 1인 운영 프로젝트에는 과하다.

### C. 현재 구조를 유지하고 Home·MomentLoop 화면만 정리

화면 파일만 나누고 공통 API·권한·Socket 경계는 그대로 둔다.

- 장점: 단기 수정 속도가 빠르다.
- 단점: 화면 파일이 작아져도 직접 HTTP, singleton service, SQL 경계 문제는 남는다.
- 판단: 첫 단계에서 일부 사용할 수 있지만 최종 구조로는 부족하다.

## 4. 목표 아키텍처

### 4.1 Flutter 모듈 구조

```text
apps/secret_base_app/lib/
  app/
    bootstrap.dart
    app.dart
    router.dart
  core/
    auth/
      auth_session.dart
      auth_service.dart
    http/
      api_client.dart
      api_exception.dart
    realtime/
      realtime_connection.dart
      couple_realtime_gateway.dart
    config/
    design_system/
  features/
    auth/
    couple/
    home/
      data/
      application/
      domain/
      presentation/
    moment_loop/
      data/
      application/
      domain/
      presentation/
    secret_map/
    relationship/
    play/
  shared/
    widgets/
```

기존 `screens/`와 `core/*_api.dart`를 한 번에 삭제하거나 이동하지 않는다. 새 기능 경계가 동작하면 기존 파일을 adapter로 바꾸거나 단계적으로 이동한다.

### 4.2 Flutter Interface 규칙

- Presentation은 HTTP, JSON, SharedPreferences, Socket.IO 객체를 직접 알지 않는다.
- Application은 화면이 필요한 상태와 명령을 제공한다. 예: `loadWeek`, `createMoment`, `deleteMoment`, `designateTodayMoment`.
- Data는 `ApiClient`, `MediaUploadService`, `RealtimeGateway`를 통해 외부 시스템과 통신한다.
- Domain은 권한·상태·날짜·Today Moment 같은 순수 정책을 담당한다.
- `AuthService()`와 `SocketService()` singleton 직접 생성은 composition root와 legacy game adapter로 제한한다.
- Riverpod·Bloc은 도입하지 않는다. 기존 `ChangeNotifier`, `ValueNotifier`, 명시적 controller로 기능별 수명을 먼저 정리한다. 실제 수명주기 문제가 발견될 때 별도 결정한다.

### 4.3 Home 설계

Home은 여러 기능의 구현을 담는 화면이 아니라 `HomeOverview`를 표시하는 조합 화면으로 만든다.

```text
HomeScreen
  -> HomeController
    -> HomeOverviewRepository
      -> CoupleApi
      -> TodayApi
      -> MemoryApi
      -> RelationshipStatusApi
```

첫 이전에서는 기존 endpoint를 repository 안에서 조합해 API 호환성을 유지한다. Home 위젯이 endpoint를 직접 호출하지 않도록 만드는 것이 우선이다. 이후 실제 성능·일관성 문제가 확인될 때만 백엔드에 `home overview` read model endpoint를 추가한다.

Home은 다음만 책임진다.

- 로딩·부분 실패·새로고침 상태 표시
- Couple summary, Today Loop 진입, MomentLoop 진입, 관계 이해 진입
- 라우터에 목적지를 요청하는 것

운세·사주·타로·지도·비밀기지의 내부 API나 화면 구현은 Home이 직접 알지 않는다.

### 4.4 MomentLoop 설계

```text
features/moment_loop/
  data/
    moment_loop_api.dart
    media_upload_service.dart
    moment_loop_models.dart
  domain/
    moment.dart
    moment_policy.dart
  application/
    moment_loop_controller.dart
    moment_loop_state.dart
  presentation/
    moment_loop_screen.dart
    moment_feed.dart
    story_viewer.dart
    moment_detail.dart
    moment_editor.dart
    map_location_picker.dart
```

Module의 외부 Interface는 다음 정도로 제한한다.

- 목록과 주간 feed 조회
- 기록 생성·수정·삭제
- 반응 조회·변경
- Today Moment 지정·해제
- 지도 pin 연결

미디어 업로드는 화면에서 multipart 요청을 만들지 않고 `MediaUploadService`가 담당한다. 오늘의 순간 정책은 UI 조건문이 아니라 domain/application 경계에서 검사한다. 지도 선택 화면은 MomentLoop가 Map의 내부 구현을 import하지 않고 결과 모델만 받는다.

### 4.5 게임 경계

게임 내부는 이번 설계 대상이 아니다.

```text
features/play/
  legacy/
    existing game screens and engines
  play_gateway.dart
  play_catalog.dart
```

기존 게임 화면과 엔진의 규칙·상태·이벤트 이름은 유지한다. 새 Core 기능은 게임 내부 클래스를 import하지 않고 Play navigation/gateway만 사용한다. 기존 `SocketService`의 게임 메서드는 당장 제거하지 않으며, 필요할 때 `LegacyGameGateway` 뒤로 감싼다.

단, 서버의 공개 게임 allowlist는 보안 경계이므로 한 곳의 backend feature registry에서 관리한다. Flutter의 게임 목록은 표시용일 뿐 서버 권한을 결정하지 않는다.

### 4.6 Backend 모듈 구조

```text
services/realtime-server/src/
  app/
    create-app.js
    create-realtime-server.js
  platform/
    config.js
    db.js
    redis.js
    uploads.js
  shared/
    access-context.js
    feature-registry.js
    http-errors.js
  modules/
    auth/
      http-router.js
      application.js
      repository.js
    couple/
    moment-loop/
    secret-map/
    relationship/
    play/
      legacy-socket-handlers.js

services/realtime-server/migrations/
```

각 Module은 route/socket adapter, application use case, repository/query, 필요하면 순수 domain policy를 가진다.

- Route handler는 입력 검증, context 전달, HTTP 응답 변환만 담당한다.
- Application은 유스케이스와 트랜잭션 경계를 담당한다.
- Repository/query는 MariaDB·Redis 접근을 담당한다.
- Socket adapter는 event payload를 use case 명령으로 바꾸고 결과를 event로 직렬화한다.
- 게임 engine처럼 순수 상태 머신인 구현은 현재 형태를 유지한다.

`routes.js`와 `socket.js`는 새 기능의 추가 지점이 아니라 legacy composition layer가 되며, vertical slice가 이전될 때 해당 handler를 제거한다.

### 4.7 권한과 데이터 흐름

모든 핵심 요청은 다음 흐름을 따른다.

```text
JWT
  -> authenticated actor
  -> optional active Couple context
  -> feature use case
  -> scoped repository query
```

사용자 ID나 Couple ID를 클라이언트 body/query에서 권한 근거로 사용하지 않는다. 개인 기능은 actor scope, 공유 기능은 명시적인 active Couple scope를 선택한다. 연결 해제된 Couple은 공유 기능의 active scope가 될 수 없다.

### 4.8 오류 처리

- Flutter `ApiClient`가 HTTP 상태·인증 만료·네트워크 실패·서버 domain error를 공통 예외로 변환한다.
- Controller는 raw exception 대신 화면이 처리할 수 있는 `loading`, `ready`, `empty`, `partialFailure`, `error` 상태를 노출한다.
- Backend는 기존 `{ ok: false, reason/error }` 계약을 우선 유지하고, 새 모듈부터 error code를 일관되게 사용한다.
- route/socket adapter에서만 transport 형식으로 변환한다.
- SQL 파라미터·개인 기록·토큰을 일반 로그에 남기지 않는다.

## 5. 이전 순서

### 단계 0 — 안전망

- 현재 Home·MomentLoop·Couple 주요 흐름의 Flutter/backend 테스트를 기준선으로 고정한다.
- 기존 REST·Socket 계약과 MVP feature flag 상태를 문서화한다.
- 게임 동작은 변경하지 않는다.

### 단계 1 — 공통 경계

- `AuthSession`, `ApiClient`, 공통 API 예외를 추가한다.
- 기존 `AuthService`가 저장소와 인증 흐름을 직접 담당하는 구조는 유지하되, 새 feature가 singleton 내부를 직접 읽지 않도록 adapter를 제공한다.
- `create-app` 분리와 migration-only startup 방향을 마련한다.

### 단계 2 — Home 수직 슬라이스

- `HomeOverview` 모델과 `HomeController`를 만든다.
- 기존 endpoint를 repository 뒤로 이동한다.
- Home 위젯의 직접 HTTP·JSON·화면별 navigation 결합을 제거한다.
- 기존 Home의 표시 내용과 사용자 흐름을 유지한다.

### 단계 3 — MomentLoop 수직 슬라이스

- API·미디어 업로드·Today Moment·지도 결과를 각각 adapter로 만든다.
- 목록, viewer, detail, editor를 분리한다.
- author scope, partner read-only, clip 제한, Today Moment 잠금 정책을 controller/domain 테스트로 고정한다.
- 기존 MomentLoop endpoint 계약은 유지한다.

### 단계 4 — Backend Core module 이전

- Couple/auth context를 먼저 정리한다.
- MomentLoop route와 query를 `modules/moment-loop`로 이전한다.
- Map과 Relationship을 같은 방식으로 이전한다.
- 이전한 endpoint를 `routes.js`에서 제거하고, 새 모듈이 유일한 등록 지점이 되게 한다.

### 단계 5 — runtime schema mutation 제거

- 기존 migration 파일과 실제 production schema 차이를 확인한다.
- 누락된 변경은 새 numbered migration으로 만든다.
- request-time `ensure*` 함수는 startup assertion 또는 migration CLI 검증으로 바꾼다.
- backup·dry-run·restore 검증 후 production에 적용한다.

### 단계 6 — 게임 격리

- 게임 화면과 엔진은 그대로 둔다.
- Play catalog와 backend feature registry를 일치시킨다.
- Core 화면이 게임 내부 구현을 참조하는 경우에만 gateway로 감싼다.
- 게임 구조 개선은 실제 게임 기능 확장이나 장애가 발생할 때 별도 설계한다.

## 6. 테스트와 완료 기준

각 단계는 기능 동작과 구조 경계를 함께 검증한다.

### Flutter

- `HomeController`와 `MomentLoopController`는 fake repository/gateway로 단위 테스트한다.
- Home은 성공, 부분 실패, 전체 실패, 새로고침을 widget test로 확인한다.
- MomentLoop는 목록, 생성, 수정, 삭제, media 실패, Today Moment 정책을 테스트한다.
- 기존 `cd apps/secret_base_app && flutter test`가 통과한다.
- Core 화면에 직접 `http.*`, `SocketService()`, JSON 파싱이 새로 들어가지 않는다.

### Backend

- application/domain은 DB 없는 단위 테스트를 우선한다.
- REST·Socket integration test로 기존 계약과 Couple scope를 보존한다.
- `cd services/realtime-server && npm test && npm run check`가 통과한다.
- 새 Core endpoint는 `routes.js`와 `socket.js`에 추가하지 않는다.
- 서버 요청 처리 중 DDL이 실행되지 않는다.

### 운영 안전

- 구현 단계마다 production deploy 전 migration status, backup reference, restore rehearsal 상태를 확인한다.
- P0/P1 보안·권한 회귀가 없어야 한다.
- 게임을 사용하지 않는 Core 변경에서 게임 테스트와 게임 파일의 동작이 불필요하게 변하지 않아야 한다.

## 7. 이번 설계에서 하지 않는 것

- Flutter 앱 전체를 새 상태관리·라우팅 프레임워크로 교체하지 않는다.
- backend를 여러 서비스나 별도 저장소로 분리하지 않는다.
- 게임 파일을 새 feature 구조로 일괄 이동하거나 규칙을 재작성하지 않는다.
- 사용하지 않는 레거시 기능을 이번 작업에서 무작정 삭제하지 않는다.
- Home용 aggregate endpoint를 성능 근거 없이 먼저 추가하지 않는다.
- 디자인 방향, 폰트, 애니메이션, 패키지 선택을 구조 작업과 섞지 않는다.

## 8. 결정이 필요한 항목

이 문서의 기본 가정은 기존 API·DB·Socket 계약을 유지하면서 Core 기능을 점진적으로 이전하는 것이다. 레거시 기능의 삭제나 breaking API 변경은 별도 결정과 별도 설계로 다룬다.
