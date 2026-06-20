# 내가 한 것들 (2026-06-20)

## 개요

커플 앱 "비밀기지"에 아직 미구현된 아카이브 기능들을 전부 완성했습니다.
서버(Node.js) + 프론트(Flutter Web) + DB(MariaDB) 모두 수정했습니다.

---

## 1. Flutter 앱 — 홈 탭 신설

**파일:** `apps/secret_base_app/lib/screens/home/home_screen.dart` (신규)

기존에 홈 탭이 없었음. 새로 만들었습니다.

- **D-Day 카드** — 커플 시작일 기준 N일째 표시. 날짜 미설정 시 "기념일 설정하기" 버튼 노출
- **날짜 설정** — 달력 피커로 시작일 선택 → `PATCH /api/couple/info` 호출
- **상대방 상태 카드** — Socket presenceUsers 기반 온라인/오프라인 표시, 상대방 이모지 포함
- **오늘의 질문 미리보기** — 질문 텍스트 + 나/상대방 답변 완료 여부 칩 표시. 탭하면 Q&A 화면으로 이동
- **당겨서 새로고침** — 커플 정보 + 오늘의 질문 병렬 갱신

**파일:** `apps/secret_base_app/lib/screens/home_shell.dart` (수정)

- 홈 탭을 첫 번째 탭으로 추가 (4개 탭)
- `NavigationDestination(Icons.home_outlined, '홈')` 추가

---

## 2. Flutter 앱 — 아카이브 화면들

### 2-1. QA 화면

**파일:** `apps/secret_base_app/lib/screens/archive/qa_screen.dart` (신규)

- `GET /api/qa/today` — 오늘의 질문 + 양쪽 답변 조회
- 질문 텍스트 크게 표시
- 미답변 시 텍스트 입력 + 제출 (`POST /api/qa/answer`)
- 나(세이지색) / 상대방(스카이색) 답변 카드로 구분해서 표시

### 2-2. 챌린지 화면

**파일:** `apps/secret_base_app/lib/screens/archive/challenge_screen.dart` (신규)

- `GET /api/challenges` — 활성 챌린지 목록
- 각 챌린지: 진행 바(LinearProgressIndicator) + 현재값/목표값 표시
- FAB → 챌린지 생성 다이얼로그 (제목, 설명, 목표 수치, 단위)
- 카드 탭 → 진행 기록 다이얼로그 (`POST /api/challenges/:id/log`)
- 완료된 챌린지는 초록 배경 + "완료 ✓" 뱃지

### 2-3. 지도 화면

**파일:** `apps/secret_base_app/lib/screens/archive/map_screen.dart` (신규)

지도 SDK 없이 리스트 뷰로 구현했습니다 (map_pins 테이블 활용).

- `GET /api/map` — 장소 핀 목록 조회
- 카드: 카테고리 이모지, 이름, 날짜, 별점(★), 메모 표시
- FAB → 장소 추가 다이얼로그 (이름, 카테고리, 별점, 방문 날짜, 메모)
- 카테고리: 식당🍽️ 카페☕ 활동🎯 여행✈️ 쇼핑🛍️ 기타📍

### 2-4. 주크박스 화면

**파일:** `apps/secret_base_app/lib/screens/archive/jukebox_screen.dart` (신규)

- `GET /api/jukebox` — 트랙 목록
- 파일 선택: `dart:html` `FileUploadInputElement` (accept=audio/*)
- 업로드: `http.MultipartRequest` → `POST /api/jukebox`
- 재생: `html.window.open(url, '_blank')` 로 새 탭에서 열기
- FAB → 트랙 추가 다이얼로그 (곡 이름, 아티스트, 파일)

**아카이브 화면 라우팅** `archive_screen.dart` (수정)

- 기존 "개발 중" 스텁(`_ArchiveDetailPage`)을 전부 실제 화면으로 교체

---

## 3. 서버 — 새 API 엔드포인트

**파일:** `services/realtime-server/src/routes.js` (수정)

### GET /api/couple/info?user_id=X

커플 정보 조회 — D-Day, 시작일, 상대방 이름/코드 반환

```json
{ "ok": true, "dDay": 42, "startDate": "2026-05-09", "partnerName": "준쨩", "partnerCode": "ABC123" }
```

### PATCH /api/couple/info

커플 시작일 업데이트

```json
{ "user_id": 1, "start_date": "2026-05-09" }
```

### GET /api/qa/today

오늘의 질문 자동 시딩 — `daily_questions` 테이블에 오늘 날짜 질문이 없으면 `QA_POOL`(30개 한국어 커플 질문)에서 랜덤 선택해 자동 삽입. 답변에 UserName JOIN.

### 기존 API 수정

- `GET /api/challenges` — 없는 뷰(`active_challenges`) 대신 `challenges` 테이블 직접 조회
- `POST /api/map` — latitude/longitude 선택 사항으로 변경 (기본값 0)
- multer fileFilter — `audio/` MIME 타입 추가 허용

---

## 4. DB — 자동 테이블 생성

**파일:** `services/realtime-server/src/routes.js` (수정)

프로덕션 DB에 아카이브 관련 테이블이 없었습니다. `ensureTables()` 함수로 첫 API 호출 시 자동 생성합니다.

생성하는 테이블:
- `map_pins` — 장소 핀 (place_name, category, rating, visit_date, memo, latitude, longitude)
- `daily_questions` — 날짜별 질문 (date, question)
- `question_answers` — 질문 답변 (question_id, user_id, answer)
- `challenges` — 챌린지 (title, description, target_value, current_value, unit, status, owner_id)
- `challenge_logs` — 진행 기록 (challenge_id, value, note)
- `jukebox_tracks` — 음악 트랙 (title, artist, file_url, duration_sec, uploaded_by)

또한 `ensureCouplesStartDate()` 로 `Couples` 테이블에 `StartDate DATE NULL` 컬럼 추가.

---

## 5. 로컬 개발 환경 픽스

### server_config.dart 수정

`apps/secret_base_app/lib/core/server_config.dart`

- 기존: Flutter dev 서버가 로컬호스트에서 돌 때 `Uri.base.origin`을 API base로 써서 404 발생
- 수정: host가 localhost/127.0.0.1이면 `dart-define`의 `SOCKET_URL` 사용, 아니면(프로덕션) `Uri.base.origin` 사용

### 실행 방법 (로컬 개발)

```bash
# 1. SSH 터널 (DB + Redis)
ssh -L 3307:127.0.0.1:3306 -L 6380:127.0.0.1:6379 junzzang@100.82.126.57

# 2. 서버
cd services/realtime-server && node src/index.js

# 3. Flutter (포트 고정 필수 - CORS 화이트리스트)
cd apps/secret_base_app
flutter run -d chrome --web-port=3000 --dart-define=SOCKET_URL=http://localhost:4100
```

---

## 변경 파일 요약

| 파일 | 상태 |
|------|------|
| `apps/secret_base_app/lib/screens/home/home_screen.dart` | 신규 |
| `apps/secret_base_app/lib/screens/home_shell.dart` | 수정 (홈 탭 추가) |
| `apps/secret_base_app/lib/screens/archive/qa_screen.dart` | 신규 |
| `apps/secret_base_app/lib/screens/archive/challenge_screen.dart` | 신규 |
| `apps/secret_base_app/lib/screens/archive/map_screen.dart` | 신규 |
| `apps/secret_base_app/lib/screens/archive/jukebox_screen.dart` | 신규 |
| `apps/secret_base_app/lib/screens/archive/archive_screen.dart` | 수정 (실제 화면 라우팅) |
| `apps/secret_base_app/lib/core/server_config.dart` | 수정 (로컬 개발 URL 픽스) |
| `services/realtime-server/src/routes.js` | 수정 (신규 API, ensureTables) |
