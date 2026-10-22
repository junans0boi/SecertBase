# MomentLoop 작성·편집·백그라운드 업로드·그리드 리서치 (2026-10)

## 요약 (10줄)

1. **순서 변경**: 그룹 내 순서는 지금 `id` 오름차순(`moment_loop_screen.dart:130`)이라 저장 후 순서를 바꿀 방법이 없다. 순서 컬럼(`position`)과 순서 저장 API가 먼저 필요하다. 작성 화면 UI는 Flutter 공식 `ReorderableListView`(가로)로 충분하다.
2. **백그라운드 업로드**: 지금은 `POST /api/setlog`를 파일마다 순차 호출하고, 하나라도 실패하면 이미 올라간 파일이 남은 채 중단된다(`media_upload_service.dart:24-60`). 재시도하면 중복 생성된다.
3. **멱등성 필수**: 서버에 `client_request_id`/idempotency 개념이 전혀 없다. 파일(=행)마다 클라이언트 UUID를 받아 `UNIQUE`로 막는 것이 가장 작은 설계다.
4. **1단계는 앱 안 업로드 큐**: 작성 화면과 분리된 영구 큐(outbox) + 실패 시 임시저장 + 로컬 알림. 새 네이티브 의존성 없이 "다른 화면 이동·추가 업로드"를 만족한다.
5. **2단계는 OS 백그라운드**: `background_downloader`가 멀티파트 업로드·재시도·알림을 지원한다. Android는 기본 9분 제한, iOS는 앱 스와이프 종료 시 전송이 죽을 수 있다. 웹은 사실상 불가(Background Sync는 제한적 지원).
6. **수정**: `PATCH /setlog/:id`는 행 하나의 `caption`/`taken_at`/`tags`/`map_pin_id`만 바꾼다. 그룹 단위 수정·사진 추가·삭제 후 정렬은 없다. 사진 추가는 기존 `session_id`로 `POST`하면 가능하나 순서·날짜 규칙이 없다.
7. **그리드**: 서버는 썸네일을 만들지 않고 원본을 그대로 정적 서빙한다(`create-app.js:25`). 피드 API는 커플 전체를 페이지 없이 반환한다. 3열 그리드 전에 썸네일 + 페이지네이션이 필요하다.
8. **리서치 한계**: Instagram 공식 도움말은 확인하지 못했다(서드파티뿐). iOS BGTaskScheduler 제약, `image_picker` 선택 순서 보존, 접근성은 문서로 확인하지 못해 **검증 필요**로 표시했다.
9. 새 서버 변경은 3개로 묶인다: ① `position` + 순서 API ② `client_request_id` 멱등 ③ 썸네일 + 커서 페이지네이션.
10. 제품 오너 결정 사항은 문서 끝 §7에 모았다.

---

## 1. 현재 구현 사실 (코드)

| 항목 | 사실 | 위치 |
| --- | --- | --- |
| 업로드 API | `POST /setlog`: 파일 1개 + 필드 | `http-router.js:119-122` |
| 파일 상한 | 30MB, multer가 디스크에 먼저 저장 | `domain.js:15`, `http-router.js:23-36` |
| 클라이언트 업로드 | 미디어마다 순차 `sendMultipart`, 같은 `session_id` | `media_upload_service.dart:24-60` |
| 그룹 | `session_id`로 묶음, 서버는 값만 저장 | `application.js:132`, 인덱스 `migrations/0040_moment_loop_reactions.sql:5` |
| 그룹 내 순서 | `id` 오름차순으로 클라이언트가 정렬. 순서 컬럼 없음 | `moment_loop_screen.dart:130`, `schema.sql:46-63` |
| 오늘의 순간 플래그 | 첫 파일에만 `today_moment` 전송, 서버는 값이 true일 때만 지정 | `media_upload_service.dart:36`, `application.js:103` |
| 수정 | `PATCH /setlog/:id`: `caption`, `taken_at`, `tags`, `map_pin_id`만 | `http-router.js:129-132`, `application.js:161-185`, `repository.js:235-256` |
| 삭제 | `DELETE /setlog/:id` (행 단위) | `http-router.js:134` |
| 피드 조회 | `GET /setlog` 전체 반환, `LIMIT` 없음, 선택적 `month` 필터 | `repository.js:132-141`, 클라이언트는 주 인자를 쓰지 않음 `moment_loop_repository.dart:53-55` |
| 이미지 처리 | 이미지는 그대로 저장. ffmpeg는 영상 정규화에만 사용 | `http-router.js:46-62`, `moment-clip.js:4`, `package.json:28` |
| 정적 서빙 | `express.static(UPLOADS_ROOT)` | `create-app.js:25` |
| 멱등성 | `client_request_id`/idempotency 코드 없음 | `grep src` 결과 없음 |
| 이미 있는 훅 | 컨트롤러가 `operationInProgress`·`pendingDraft`를 가짐 | `moment_loop_controller.dart:14-25,83-84` |
| 설치된 관련 패키지 | `image_picker`, `exif`만. `flutter_local_notifications`·`workmanager`·`firebase` 없음 | `pubspec.yaml` |

---

## 2. 주제 1 — 다중 선택 + 드래그 순서 변경

### 외부 근거
- Flutter 공식 `ReorderableListView`: 모든 항목에 key가 필요하고, 모바일에서는 항목을 길게 누르면 이동이 시작된다. `onReorderItem`이 현재 콜백이고 `onReorder`는 deprecated다. `.builder` 생성자와 드래그 모양 변경용 `proxyDecorator`도 있다. 이 문서는 **접근성/시맨틱 동작과 그리드 지원 여부를 다루지 않는다.** — [api.flutter.dev ReorderableListView](https://api.flutter.dev/flutter/material/ReorderableListView-class.html)
- `reorderable_grid_view` 2.2.8: 그리드용 드래그 정렬(MIT, 웹 포함 6개 플랫폼). 마지막 안정 릴리스가 약 2년 전이고, 알려진 이슈(`placeholderBuilder`, 스코프 밖 드래그)가 있으며 게시자는 미검증이다. — [pub.dev](https://pub.dev/packages/reorderable_grid_view)
- `image_picker`: `pickMultiImage()`/`pickMultipleMedia()`는 `List<XFile>`을 반환한다. **선택 순서 보존 여부는 문서에 없다.** Android 13+는 시스템 Photo Picker를 쓴다. — [pub.dev](https://pub.dev/packages/image_picker)

### 평가
- 작성 화면의 썸네일 줄은 가로 한 줄이므로 `ReorderableListView.builder(scrollDirection: Axis.horizontal)`로 충분하다(공식, 추가 의존성 없음). 그리드형 정렬은 상세 편집 화면이 생길 때 재검토한다.
- 선택한 순서를 숫자 배지로 보여주는 방식은 인스타그램 등에서 흔한 패턴이지만, 이번 조사에서 **출처를 확인하지 못했다**(제품 패턴 관찰일 뿐 사실로 인용하지 말 것).
- 접근성: 길게 누르기 드래그만 두면 스크린리더·스위치 사용자가 순서를 바꿀 수 없다. "앞으로/뒤로 이동" 버튼 대안을 같이 두자는 것은 **우리의 제안**이며, TalkBack/VoiceOver 실기기 검증이 필요하다.
- 저장 후 순서를 바꾸려면 서버가 순서를 가져야 한다. 아래 §6의 `position`이 선행 조건이다.

---

## 3. 주제 2 — 인스타그램식 백그라운드 업로드

### 외부 근거
- `background_downloader` v9.6.4: 멀티파트/바이너리/다중 파일 업로드 지원, 큐·진행률·재시도·오프라인 보류/재개, 실행·완료 알림. Android·iOS·macOS·Windows·Linux(웹 언급 없음). Android 표준 WorkManager 작업은 9분 제한이며 `allowPause`/`largeFile`/`userInitiated`로 이어서 실행한다. iOS는 리소스 타임아웃 기본 4시간. **앱을 스와이프로 종료하면 OS가 백그라운드 전송을 조용히 죽일 수 있다.** — [pub.dev](https://pub.dev/packages/background_downloader)
- `workmanager` 0.10.10: Android는 WorkManager, iOS는 BGTaskScheduler, 웹은 실험적. 업로드 API 자체는 없고 "일을 예약"하는 도구다. iOS 실행 제약(기회적 실행, 시간 제한)은 이 페이지에 없어 **확인하지 못했다**. — [pub.dev](https://pub.dev/packages/workmanager)
- Android 공식: WorkManager는 작업을 DB에 저장해 재부팅 후에도 재스케줄하고, 10분을 넘는 작업은 `setForeground()`로 알림을 띄워야 하며 백오프 재시도를 지원한다. — [developer.android.com](https://developer.android.com/develop/background-work/background-tasks/persistent)
- Android 14+ 사용자 시작 데이터 전송(UIDT): 알림 필수, Jetpack 라이브러리 지원 없음(`JobScheduler` 직접), 앱 프로세스를 사용자가 Task Manager에서 종료하면 재스케줄되지 않음. 페이지 예시는 다운로드이며 업로드 명시는 없다. — [developer.android.com UIDT](https://developer.android.com/develop/background-work/background-tasks/uidt)
- 웹 Background Sync API: "제한적 가용성(Baseline 아님)", HTTPS + 서비스 워커 필요. — [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API)
- `flutter_local_notifications` 22.3.1: 웹 포함 6개 플랫폼, Android 13+는 `POST_NOTIFICATIONS` 권한 요청 필요, 채널·탭 payload·종료 상태 콜백 지원. — [pub.dev](https://pub.dev/packages/flutter_local_notifications)
- 멱등성 키 패턴: 클라이언트가 UUID v4 같은 키를 만들고, 서버는 같은 키의 재시도에 저장된 응답을 반환한다. 키는 255자 이하, 파라미터가 다르면 오류, Stripe는 24시간 후 키를 정리한다. — [Stripe Docs](https://docs.stripe.com/api/idempotent_requests). IETF `Idempotency-Key` 헤더 초안은 **만료(Expired)** 상태이며 RFC가 아니다 — [datatracker](https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/). 표준이 아니라 업계 관행으로만 인용할 것.
- Instagram 공식 도움말은 찾지 못했다. 검색 결과는 서드파티 블로그뿐이라 "실패 시 임시저장 유도" 같은 서술은 **미검증**이다.

### 현재 흐름의 문제 (코드 근거)
1. 작성 화면이 `_saving = true`로 잠기고 업로드가 끝나야 닫힌다(`moment_loop_screen.dart:2290-2347`).
2. 파일 N개가 순차 N회 요청이라 중간 실패 시 일부만 서버에 남는다(`media_upload_service.dart:24-60`).
3. 실패 후 전체 재시도 시 이미 올라간 파일이 중복 생성된다(멱등성 없음).
4. 서버는 검증 전에 파일을 디스크에 먼저 쓴다(`http-router.js:23-36`). 중복 요청이면 새 파일을 지워야 한다.

### 제안 설계
- **업로드 큐(outbox)**: 작성 화면이 "저장" 시 초안을 로컬 영구 저장소에 넣고 즉시 닫는다. 초안은 `draft_id`(UUID), 파일 목록(앱 문서 디렉터리에 **복사**), 캡션·기록 날짜·위치·`session_id`, 파일별 상태(대기/전송/성공/실패)를 가진다. `image_picker` 문서는 카메라 파일이 캐시에 임시 저장된다고 하고 갤러리 선택 파일의 보관은 설명하지 않으므로, 우리 쪽에서 복사해 두는 것이 안전하다.
- **파일별 `client_request_id`(UUID)**: 서버가 `UNIQUE(user_id, client_request_id)`로 막고, 중복이면 기존 행을 200으로 반환하며 새로 받은 파일은 삭제한다. 행 자체가 키를 보관하므로 24시간 정리가 필요 없다.
- **재시도**: 지수 백오프, 이미 성공한 파일은 건너뜀. 모든 파일이 성공해야 초안이 `완료`.
- **실패**: 초안을 `임시저장` 상태로 유지하고 로컬 알림("업로드에 실패했어요, 눌러서 다시 시도")을 보낸다. 탭하면 해당 초안을 연다.
- **단계**: 1단계는 앱 프로세스 안 큐(새 네이티브 의존성 없음, 기존 `http` 멀티파트 재사용). 2단계에서 `background_downloader`로 OS 백그라운드를 추가한다. 훅 후보는 이미 있는 `pendingDraft`다(`moment_loop_controller.dart:83-84`).
- **웹**: 진정한 백그라운드는 불가에 가깝다. 큐를 IndexedDB에 저장하고 다음 접속 때 이어서 올리는 수준이 현실적이다.
- **오늘의 순간**: 지금은 첫 파일만 플래그를 보낸다(`media_upload_service.dart:36`). 큐로 옮길 때 이 규칙과 "과거 날짜는 불가" 규칙(`application.js:103-107`)을 그대로 유지해야 한다.

---

## 4. 주제 3 — 기존 순간 수정

### 지금 되는 것 / 안 되는 것

| 요구 | 현재 지원 | 부족한 것 |
| --- | --- | --- |
| 글(캡션) 수정 | 행 단위 `PATCH` 가능 | 그룹 대표 캡션 규칙. 클라이언트는 `group.first`의 캡션을 쓰는데 캡션은 행마다 저장된다 |
| 위치 변경 | 행 단위 `map_pin_id` `PATCH` 가능 (`application.js:166-176`) | 그룹의 모든 행을 한 트랜잭션으로 바꾸는 엔드포인트 |
| 기록 날짜 변경 | 행 단위 `taken_at` | 그룹 단위 + 오늘의 순간과의 관계(§5) |
| 사진 추가 | 기존 `session_id`로 `POST` 하면 가능(코드상) | 순서(`position`) 규칙, 날짜·위치·캡션 상속, 권한 확인 |
| 사진 삭제 | 행 단위 `DELETE` 가능 | 삭제 후 순서 재배열, 마지막 한 장 삭제 시 처리 |
| 사진 교체 | 없음 (삭제 + 추가로 우회) | 필요하면 별도 설계 |
| 순서 변경 | 없음 | `position` 컬럼 + 순서 API |

### 주의할 기존 제약
- 반응(이모지)은 `session_id` 단위(`toggleReaction`, `http-router.js:124`)이므로 그룹의 `session_id`를 바꾸는 수정은 반응을 잃는다. 그룹 식별자는 불변으로 두는 것이 안전하다.
- 오늘의 순간으로 지정된 글은 공개(reveal) 이후 삭제·교체에 특별 처리가 있다(`repository.js:266-280`). 수정·삭제 UI는 이 상태를 존중해야 한다.
- 수정 권한은 작성자 본인만(`mutationTarget` 사용, `application.js:162`).

---

## 5. 주제 4 — 인스타그램 프로필식 격자 피드

### 외부 근거
- `ResizeImage`는 이미지를 작은 크기로 디코딩해 `ImageCache` 메모리를 줄인다. 작게 표시되는 이미지가 많을 때 적합하다는 해석은 문서 목적에서의 추론이다. — [api.flutter.dev ResizeImage](https://api.flutter.dev/flutter/painting/ResizeImage-class.html)
- `cached_network_image` 4.0.4: 디스크 캐시는 `flutter_cache_manager`를 쓴다. **웹은 최소 지원이며 캐시를 포함하지 않는다.** — [pub.dev](https://pub.dev/packages/cached_network_image)
- `GridView.builder`의 지연 생성은 일반적인 Flutter 지식이며 이번 조사에서 공식 페이지를 가져오지 않았다(미검증).

### 평가
- 서버는 이미지 썸네일을 만들지 않는다(§1). 3열 그리드(화면당 30장 이상)에서 원본(수 MB)을 내려받으면 데이터와 메모리가 폭증한다. 디코딩 크기 축소(`cacheWidth`/`ResizeImage`)는 **메모리만** 줄이고 네트워크 바이트는 그대로다. → 업로드 시 서버가 썸네일(예: 긴 변 480px JPEG)을 만들어 별도 URL로 내려주는 편이 맞다.
- 이미 있는 `ffmpeg-static`(`package.json:28`)이 이미지 축소에도 쓰일 수 있다는 점은 일반 지식이다(미검증). 이미지 전용 라이브러리 도입 여부는 구현 티켓에서 결정한다.
- 피드 API가 커플 전체를 한 번에 반환한다(`repository.js:132-141`). 격자는 스크롤형이므로 `limit` + 커서 페이지네이션이 필요하다. 지금은 클라이언트가 주 단위 필터를 로컬에서 한다(`moment_loop_repository.dart:53-55`).
- 그룹 표시: `session_id` 그룹의 대표(`position` 첫 번째)를 셀로 쓰고, 2장 이상이면 모서리에 장수 배지를 단다(현재 일별 카드에 이미 장수 배지가 있다).
- 상세로 들어가는 탭 동작은 현재 `_PostDetailPage`를 재사용할 수 있다.

---

## 6. 권장 설계 (요약)

**서버**
1. `setlog_posts.position SMALLINT` 추가, `POST`가 `position`을 받고 조회는 `position, id` 순. 순서 변경 API(`PATCH /setlog/session/:sessionId/order` 형태, 소유자만, 한 트랜잭션).
2. `setlog_posts.client_request_id VARCHAR(64)` + `UNIQUE(user_id, client_request_id)`. 중복이면 기존 행 반환 + 새 업로드 파일 삭제.
3. 이미지 썸네일 생성 + 응답에 `thumb_url`. 피드에 커서 페이지네이션.
4. 그룹 단위 수정 엔드포인트(캡션/위치/날짜를 같은 `session_id` 모든 행에 적용).

**클라이언트**
1. 작성 화면: 가로 `ReorderableListView.builder` + 이동 버튼 대안. 날짜는 EXIF 자동 설정(이미 구현).
2. 업로드 큐(앱 내 영구 저장) + 임시저장 목록 + 실패 로컬 알림. 이후 `background_downloader`.
3. 수정 화면: 사진 추가/삭제/순서/위치/글을 한 화면에서.
4. 3열 그리드 피드 + 무한 스크롤.

**의존성 증가**: 1단계에서는 `flutter_local_notifications`만 추가 후보. 큐 저장소는 기존 파일/JSON 또는 `sqflite` 중 구현 티켓에서 결정.

---

## 7. 제품 오너가 정해야 할 것

1. **업로드 실패 알림 범위**: 로컬 알림만으로 충분한가, 푸시(FCM) 도입(§8번 항목 런칭 계획)과 함께 갈 것인가.
2. **iOS/Android/웹 중 우선 플랫폼**: 지금 설치 가능한 것은 Android APK다. iOS·웹의 백그라운드 업로드 수준을 어디까지 약속할 것인가(웹은 "다음 접속 때 이어서" 수준이 현실적).
3. **그룹의 의미**: 캡션·위치·날짜는 "게시물(그룹) 단위 하나"인가, "사진마다 따로"인가. 현재 데이터 모델은 행마다 저장하지만 UI는 그룹 첫 행을 쓴다.
4. **사진 수 상한**: 지금 클라이언트는 10장(`moment_loop_screen.dart`의 `_maxMedia`). 늘릴지, 영상 포함 시 용량 상한(30MB/파일)을 유지할지.
5. **수정 허용 범위**: 사진 교체를 지원할지(삭제+추가로 대체해도 되는지), 오늘의 순간이 공개된 뒤에도 수정을 허용할지.
6. **임시저장 보관 정책**: 얼마나 오래, 몇 개까지 보관하고 언제 자동 폐기하는가(기기 용량 문제).
7. **격자의 시간 단위**: 전체 스크롤인가, 월 단위 구분인가, 기존 "주 단위" 탐색을 유지하는가.
8. **썸네일 소급 적용**: 이미 올라간 원본 사진의 썸네일을 일괄 생성할 것인가(마이그레이션 작업).
9. **업로드 중 편집/삭제 충돌**: 큐에 있는 초안을 사용자가 취소할 수 있게 할 것인가.

---

## 8. 검증하지 못한 것 (후속 확인 필요)

- Instagram 공식 도움말의 임시저장/백그라운드 업로드 동작 (서드파티 글만 확인, 인용하지 않음).
- iOS BGTaskScheduler의 실행 시간·빈도 제약 (`workmanager` 페이지에 없음, Apple 문서 미확인).
- `image_picker`의 다중 선택 순서 보존, `limit` 인자 동작 (pub.dev 페이지에 없음, 실기기 확인 필요).
- `ReorderableListView`의 스크린리더 지원 수준 (공식 페이지에 설명 없음).
- `GridView.builder` 지연 생성, 이미지 썸네일 생성 방식(ffmpeg 또는 별도 라이브러리) 공식 확인.
- 범위 밖 메모: 사용자 보고 "체크하지 않았는데 오늘의 순간으로 나옴"은 서버가 플래그가 true일 때만 지정하고(`application.js:103`) 클라이언트도 첫 파일에만 보낸다(`media_upload_service.dart:36`)는 것까지만 확인했다. 원인은 재현 후 별도 진단이 필요하다.
