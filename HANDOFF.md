# 세션 핸드오프 노트 (2026-07-12)

Claude/Codex/Gemini 같은 다음 에이전트가 이어받기 위한 컨텍스트 정리.

## 0. Codex 최신 업데이트 (2026-07-12, Kakao 심사용 운영 도메인 분리)

### 요청 배경

- `https://secertbase.kro.kr`가 Kakao Developers 심사 대상 도메인이다.
- 심사 중에는 로그인 화면이 나오면 안 된다는 요구 때문에 운영 도메인을 로그인 없는 심사용 빌드로 유지해야 한다.
- 그 상태에서는 친구/타인과 정상 로그인/페어링 플로우를 테스트할 수 없어서 별도 테스트 도메인이 필요했다.

### 완료된 서버 작업

DNS:

- 사용자가 `test.secertbase.kro.kr` A 레코드를 기존 운영 서버와 같은 IP로 열어둔 상태였다.

서버 접속:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -t ubuntu@100.97.58.29 'cd ~/SecertBase && exec bash -l'
```

Caddy:

- `/etc/caddy/Caddyfile`에 `test.secertbase.kro.kr` 블록을 추가했다.
- `secertbase.kro.kr`은 `/var/www/secretbase`를 서빙한다.
- `test.secertbase.kro.kr`은 `/var/www/secretbase-test`를 서빙한다.
- 두 도메인 모두 `/api/*`, `/uploads/*`, `/health`, `/socket.io/*`를 `127.0.0.1:4100`으로 프록시한다.
- `sudo caddy validate --config /etc/caddy/Caddyfile` 통과 후 `sudo systemctl reload caddy` 완료.

Backend env:

- `services/realtime-server/.env`의 `CORS_ORIGIN`을 아래 값으로 변경했다.

```text
CORS_ORIGIN=https://secertbase.kro.kr,https://test.secertbase.kro.kr
```

- 변경 전 `.env` 백업은 서버의 `~/secretbase-env-backups/.env.backup-before-test-domain-<timestamp>` 형태로 옮겨두었다.
- `pm2 restart secretbase-realtime --update-env` 및 `pm2 save` 완료.

Tester web build:

- 서버의 `apps/secret_base_app/.env`에는 Kakao 심사용으로 `KAKAO_REVIEW_AUTO_LOGIN=true`가 들어 있다.
- 그래서 `scripts/deploy_server.sh`를 그대로 쓰지 않고 임시 dart-define 파일로 테스트 빌드를 수동 생성했다.
- 테스트 빌드는 `KAKAO_REVIEW_AUTO_LOGIN=false`로 빌드되어 정상 로그인/페어링 플로우를 보여준다.
- 이후 이 절차를 `scripts/deploy_test_server.sh`로 고정했다. 다음부터는 수동 명령 대신 이 스크립트를 사용한다.

다음부터 사용할 명령:

```bash
cd ~/SecertBase
./scripts/deploy_test_server.sh
```

2026-07-12 최초 배포에 사용한 수동 명령:

```bash
cd ~/SecertBase
git checkout -- apps/secret_base_app/analysis_options.yaml apps/secret_base_app/pubspec.lock 2>/dev/null || true
cd apps/secret_base_app
flutter pub get
BUILD_ENV_FILE=$(mktemp)
{
  echo "SOCKET_URL=https://test.secertbase.kro.kr"
  grep -E "^GOOGLE_CLIENT_ID=" .env || true
  echo "KAKAO_REVIEW_AUTO_LOGIN=false"
} > "$BUILD_ENV_FILE"
flutter build web --release --no-wasm-dry-run --dart-define-from-file="$BUILD_ENV_FILE"
rm -f "$BUILD_ENV_FILE"
rsync -a --delete build/web/ /var/www/secretbase-test/
```

### 검증 결과

```text
https://test.secertbase.kro.kr/health => {"ok":true}
https://secertbase.kro.kr/health => {"ok":true}
https://test.secertbase.kro.kr/ => HTTP/2 200, server: Caddy
```

추가 검증:

- `Origin: https://test.secertbase.kro.kr` 요청에 backend CORS가 `access-control-allow-origin: https://test.secertbase.kro.kr`를 반환해야 한다.
- 서버는 Socket.IO를 `transports: ["websocket"]`로 제한하므로 polling curl은 `Transport unknown`이 정상이다.
- `wss://test.secertbase.kro.kr/socket.io/?EIO=4&transport=websocket` WebSocket handshake가 `0{"sid":...}` 형태의 open packet을 반환해야 한다.

빌드 산출물 확인:

```text
/var/www/secretbase-test/main.dart.js contains https://test.secertbase.kro.kr
/var/www/secretbase/main.dart.js does not contain https://test.secertbase.kro.kr
```

현재 역할:

```text
https://secertbase.kro.kr       Kakao Developers 심사용, 로그인 없는/자동 로그인 빌드 유지
https://test.secertbase.kro.kr  친구/테스터용, 정상 로그인/페어링 빌드
```

Kakao Developers 설정 주의:

- `test.secertbase.kro.kr`에서 Kakao SDK 또는 Kakao Maps JavaScript 키를 직접 쓰려면 Kakao Developers의 웹 도메인/JavaScript SDK 도메인에 `https://test.secertbase.kro.kr`도 추가해야 한다.
- Kakao Local/Open Map 서비스 심사가 아직 끝나지 않았다면 테스트 도메인에서도 Kakao provider는 실패할 수 있고, NAVER/OSM fallback 중심으로 테스트해야 한다.

### 발견한 운영 문제

PM2 로그에서 배포와 별개인 DB 스키마 문제를 발견했다.

```text
SELECT * FROM album_folders WHERE couple_id = ? ORDER BY sort_order ASC, created_at DESC
Unknown column 'sort_order' in 'ORDER BY'
```

의미:

- 현재 백엔드 코드는 `album_folders.sort_order` 컬럼을 기대한다.
- 운영 MariaDB의 `album_folders` 테이블에는 해당 컬럼이 없는 것으로 보인다.
- `/api/album/folders` GET 요청이 실패한다.

다음 조치:

- `services/realtime-server/schema.sql` 및 관련 migration 부재 여부 확인.
- 운영 DB에 `sort_order` 컬럼을 추가하는 migration을 만들거나, 백엔드 쿼리를 현재 스키마와 호환되게 수정한다.
- 수정 전에는 앨범 폴더 기능을 신뢰하지 말 것.

### 문서 업데이트

이번 세션에서 다음 문서를 현재 서버 상태에 맞게 갱신했다.

- `CONTEXT.md`
- `docs/deployment/Caddyfile`
- `docs/deployment/SERVER_SETUP.md`
- `docs/deployment/LOCAL_DEV_AND_DEPLOY.md`
- `scripts/deploy_test_server.sh`
- `HANDOFF.md`

## 1. Codex 업데이트 (2026-07-09, 비밀지도 1차 개발)

### 비밀지도 1차 UX 구현 완료

이번 세션의 중심 작업은 `비밀 지도`를 실제 제품 방향에 맞게 1차 UI/검색 구조로 올리는 것이었다.

주요 반영 파일:

- `apps/secret_base_app/lib/screens/archive/map_screen.dart`
- `apps/secret_base_app/lib/core/server_config.dart`
- `services/realtime-server/src/place-search.js`
- `services/realtime-server/src/routes.js`
- `services/realtime-server/src/config.js`
- `services/realtime-server/test/place-search.test.js`
- `services/realtime-server/.env.example`
- `scripts/local-dev-proxy.js`
- `docs/SECRET_MAP_PLAN.md`
- `docs/REST_API.md`
- `docs/PRODUCT_SPEC.md`

비밀지도 UX 변경:

- 지도 첫 화면 중심 유지.
- `전체 / 다녀온 곳 / 가고 싶은 곳` 상태 필터 추가.
- 카테고리 필터 유지: 식당, 카페, 활동, 여행, 쇼핑, 기타.
- 핀 디자인 구분:
  - 다녀온 곳: 따뜻한 채움 핀.
  - 가고 싶은 곳: 라일락 계열 핀.
- 장소 카드 누르면 상세 바텀시트 표시:
  - 상태/카테고리/방문일.
  - 우리 온도(별점).
  - 감정 태그.
  - 우리 메모.
  - MomentLoop 연결 자리.
  - 하트/댓글/공유 액션 placeholder.
  - `길찾기` 1차 CTA.
- 장소 추가 플로우를 AlertDialog에서 바텀시트로 변경:
  - 다녀온 곳/가고 싶은 곳 선택.
  - 카테고리 선택.
  - 다녀온 곳이면 방문 날짜, 별점, 감정 태그 입력.
  - 가고 싶은 곳이면 이유/메모 중심.
- 위시리스트 장소 상세에서 `다녀왔어요` 플로우 추가:
  - 방문 날짜, 별점, 감정 태그, 메모 입력.
  - 현재 백엔드가 `status`/`visit_date` PATCH 저장을 지원하지 않으므로 UI/로컬 상태 중심. 영구 저장은 다음 백엔드 슬라이스 필요.
- 장소 상세에 길찾기 앱 선택 추가:
  - 네이버지도: `nmap://route/public?...`
  - 카카오맵: `kakaomap://route?...`
  - TMAP: `tmap://route?...`
  - 웹 지도 fallback: Google Maps URL.
- 사용자 위치 기반 검색 UX 추가:
  - 비밀지도 진입 시 위치 권한을 부드럽게 요청한다.
  - 권한 허용 시 검색 기준점을 현재 위치로 사용하고, 현재 위치 마커를 지도에 표시한다.
  - 권한 거절/실패 시 앱을 막지 않고 대한민국 중심 지도와 일반 검색으로 동작한다.
  - 검색 결과 목록에 거리(`145m`, `1.2km`)를 표시한다.
- 지도 기본값 변경:
  - 핀/현재 위치가 없으면 서울 한 점이 아니라 대한민국 전체가 보이는 중심/줌으로 시작한다.

주의:

- 현재 `map_pins` DB/API는 아직 `status`, `emotion_tags`, `provider_place_id`, `place_url`, `address`, `road_address`, `phone`, `couple_id`, `user_id` 등을 저장하지 않는다.
- 프론트는 호환을 위해 `visit_date` 유무로 `다녀온 곳/가고 싶은 곳`을 임시 판정한다.
- 장소 추가 요청 body에는 `status`, `emotion_tags`도 같이 보내지만 기존 백엔드는 무시한다.
- 다음 backend slice에서 스키마/권한/API를 정식으로 맞춰야 한다.

### 장소 검색 백엔드 프록시 구현

새 REST API:

```text
GET /api/places/search?q=성수%20카페&limit=3&lat=37.544&lng=127.055
```

구현:

- `services/realtime-server/src/place-search.js`
  - Kakao Local 정규화.
  - NAVER API HUB Search Local 정규화.
  - Naver Maps Geocoding fallback 정규화.
  - provider 결과 dedupe.
  - 좌표가 들어오면 모든 provider 결과에 `distanceMeters`를 계산하고 가까운 순으로 정렬.
  - NAVER Local은 좌표 기반 검색이 아니므로 좌표를 지역명 힌트로 바꾼 뒤 `원검색 + 지역어 검색`을 병합.
  - 지역명 힌트는 Naver Maps Reverse Geocoding이 활성화되면 우선 사용하고, 현재는 Nominatim reverse fallback으로 보강.
- `services/realtime-server/src/routes.js`
  - `/api/places/search` 추가.
  - provider가 모두 실패하면 502 `place_search_failed`.
  - 프론트는 502를 받으면 기존 OSM/Nominatim fallback을 탄다.
- `apps/secret_base_app/lib/screens/archive/map_screen.dart`
  - 검색을 직접 Nominatim 호출에서 `/api/places/search` 호출로 변경.
  - 실패 시 기존 Nominatim fallback 유지.
  - 검색 결과에는 장소명/주소/거리/provider 표시.
  - provider 카테고리를 앱 카테고리로 매핑.

실제 위치 기반 검색 확인:

```text
GET /api/places/search?q=철길부산집&limit=5&lat=37.5668&lng=126.8279
regionHints: 마곡지구도시개발지구, 가양1동, 강서구, 서울특별시
1. 철길부산집 마곡나루점, 약 145m
2. 철길부산집 발산점, 약 929m
3. 철길부산집 마곡역점, 약 933m
```

이전에는 NAVER 단독 `철길부산집` 검색이 대학로/신당/공덕/신촌 위주로만 내려왔다.
지역어 보강 검색이 없으면 거리순 정렬만으로는 가까운 매장이 후보에 포함되지 않는 문제가 있다.

Provider 상태:

- Kakao:
  - REST API 키는 로컬 `.env`에 입력됨.
  - 실제 호출 결과는 현재 403:

```text
App(SecretBase) disabled OPEN_MAP_AND_LOCAL service.
```

  - Kakao Developers에서 SecretBase 앱의 Open Map and Local / 카카오맵 로컬 API 서비스 활성화가 필요하다.
- NAVER API HUB Search Local:
  - 기존 `openapi.naver.com` 방식이 아니라 신규 API HUB 방식으로 동작 확인.
  - endpoint:

```text
https://naverapihub.apigw.ntruss.com/search/v1/local
```

  - headers:

```text
X-NCP-APIGW-API-KEY-ID
X-NCP-APIGW-API-KEY
```

  - 실제 테스트 성공:

```text
GET /api/places/search?q=성수%20카페&limit=3
count: 3
firstProvider: naver
firstName: 하하하성수
```

- Naver Maps:
  - 별도 Maps 키는 로컬 `.env`에 `NAVER_MAPS_CLIENT_ID`, `NAVER_MAPS_CLIENT_SECRET`로 분리.
  - Geocoding 직접 테스트는 현재 401:

```text
A subscription to the API is required.
```

  - NCP Maps Application에서 Geocoding 구독/권한 활성화 필요.

로컬 `.env` 키 이름:

```text
KAKAO_REST_API_KEY=
NAVER_SEARCH_CLIENT_ID=        # NAVER API HUB Search Local key id
NAVER_SEARCH_CLIENT_SECRET=    # NAVER API HUB Search Local key
NAVER_MAPS_CLIENT_ID=          # Naver Maps key id
NAVER_MAPS_CLIENT_SECRET=      # Naver Maps key
```

키 값은 `.env`에만 있고 문서/코드에는 커밋하지 말 것.

### localhost:5050 테스트 구성

현재 `localhost:5050`에서 테스트하려면 다음 구성이 가장 편하다.

```text
Flutter web:      http://localhost:5050
local proxy:      http://localhost:3000
local backend:    http://localhost:4100
production API:   https://secertbase.kro.kr
```

의도:

- 로그인/기존 API는 운영 서버로 보낸다.
- 새 장소 검색 API만 로컬 백엔드로 보낸다.
- 운영 서버에 아직 `/api/places/search`가 배포되지 않아도 `localhost:5050`에서 매장 검색을 확인할 수 있다.

현재 테스트용 실행 방식:

```bash
cd services/realtime-server
npm run dev
```

```bash
LOCAL_PLACE_SEARCH_ORIGIN=http://localhost:4100 node scripts/local-dev-proxy.js
```

```bash
cd apps/secret_base_app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port=5050 --dart-define-from-file=.env_dev
```

현재 프록시 변경:

- `scripts/local-dev-proxy.js`
  - 기존에는 `/api`, `/socket.io`, `/uploads`, `/health`를 모두 운영 서버로 프록시.
  - 이제 `LOCAL_PLACE_SEARCH_ORIGIN`이 있으면 `/api/places/search`만 해당 origin으로 프록시.

직접 확인한 명령:

```bash
curl 'http://localhost:3000/api/places/search?q=%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98&limit=3'
```

성공 응답 예:

```text
하하하성수
카페 마트리
포레스트 서울숲
```

테스트 시 주의:

- `localhost:5050`에서 비밀지도 검색창에 `성수 카페` 입력 후 Enter.
- 매장 검색 결과가 뜨면 성공.
- 장소 저장까지 누르면 현재 `/api/map`은 운영 서버로 가므로 실제 운영 DB에 저장될 수 있다. 검색 UI 확인 위주로 테스트할 것.
- 로컬 백엔드는 DB/Redis 터널 없이도 `places/search`는 동작하지만, `/health`, 로그인, map 저장 등은 DB/Redis가 없으면 실패할 수 있다.
- 현재 로컬 백엔드 로그에는 DB/Redis 연결 실패가 반복될 수 있다:

```text
DB ECONNREFUSED 127.0.0.1:3307
Redis ECONNREFUSED 127.0.0.1:6380
```

장소 검색 API 자체는 DB/Redis를 사용하지 않는다.

### server_config.dart 로컬 주소 보정

`apps/secret_base_app/lib/core/server_config.dart` 수정:

- 기존에는 웹에서 host가 `localhost`가 아니면 `Uri.base.origin`을 API 서버로 사용했다.
- 모바일/LAN 테스트 주소(`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`, Tailscale `100.64-127.x.x`)에서는 이 로직 때문에 `:5051/api/...`로 요청이 가서 404가 났다.
- `_isDevHost()`를 추가해 로컬/LAN/Tailscale 개발 주소에서는 `SOCKET_URL`을 사용하도록 수정.

### 검증 결과

이번 세션 검증:

```text
cd services/realtime-server && npm test
pass, 20 tests

cd services/realtime-server && npm run check
pass

cd apps/secret_base_app && flutter analyze lib/core/server_config.dart lib/screens/archive/map_screen.dart
pass

flutter build web --release --no-wasm-dry-run ...
pass (중간 단계에서 확인)

2026-07-09 위치 기반 검색 추가 후 재검증:

cd services/realtime-server && npm test && npm run check
pass, 25 tests

cd apps/secret_base_app && flutter analyze lib/screens/archive/map_screen.dart
pass

cd apps/secret_base_app && flutter build web --release --no-wasm-dry-run --dart-define-from-file=.env_dev
pass

로컬 프록시 실제 검색 확인:

GET /api/places/search?q=철길부산집&limit=5&lat=37.5668&lng=126.8279
1. 철길부산집 마곡나루점, 145m
2. 철길부산집 발산점, 929m
3. 철길부산집 마곡역점, 933m

GET /api/places/search?q=트레이더스&limit=5&lat=37.5668&lng=126.8279
트레이더스 홀세일클럽 마곡점이 상위권에 포함됨.
```

기존 전체 `flutter test`는 여전히 `dart:html` import 때문에 VM test 전 단계에서 실패하는 기존 이슈가 있다.

### 다음에 해야 할 일

### Kakao 심사용 자동 로그인 모드

Kakao Map/Local 심사에서 로그인 화면이 없어야 하는 경우를 위해 자동 로그인 모드를 추가했다.
초기 구현은 Flutter `dart-define`에 심사용 이메일/비밀번호를 넣는 방식이었는데, Kakao 심사에서 서비스 웹에 이메일 주소가 노출된다고 반려되어 구조를 변경했다.

현재 구조:

- 프론트 빌드에는 `KAKAO_REVIEW_AUTO_LOGIN=true`만 들어간다.
- 심사용 계정 이메일은 백엔드 `services/realtime-server/.env`에만 둔다.
- 프론트는 `/api/auth/review-login`을 호출한다.
- 백엔드가 내부 `.env`의 `KAKAO_REVIEW_EMAIL`로 사용자를 찾아 JWT를 발급한다.
- 클라이언트 응답/JWT payload/설정 화면에서 실제 이메일 노출을 제거했다.

반영 파일:

- `apps/secret_base_app/lib/core/auth_service.dart`
- `apps/secret_base_app/lib/main.dart`
- `apps/secret_base_app/.env.example`
- `apps/secret_base_app/lib/screens/settings/settings_screen.dart`
- `apps/secret_base_app/lib/screens/auth/login_screen.dart`
- `apps/secret_base_app/lib/screens/auth/register_screen.dart`
- `services/realtime-server/src/routes.js`
- `services/realtime-server/src/config.js`
- `services/realtime-server/.env.example`
- `scripts/deploy_server.sh`

프론트 빌드 환경값:

```text
KAKAO_REVIEW_AUTO_LOGIN=true
```

백엔드 환경값:

```text
KAKAO_REVIEW_AUTO_LOGIN=true
KAKAO_REVIEW_EMAIL=<심사용 계정 이메일>
```

동작:

- `KAKAO_REVIEW_AUTO_LOGIN=false` 또는 미설정이면 기존 로그인/회원가입 화면이 그대로 나온다.
- 프론트가 `true`이면 앱 시작 시 `/api/auth/review-login`으로 심사용 계정 자동 입장을 시도한다.
- 자동 로그인 실패/계정 미설정 시에도 로그인 폼을 보여주지 않고 `비밀기지로 입장하는 중...` 화면과 재시도 버튼만 보여준다.
- 심사 종료 후에는 반드시 `KAKAO_REVIEW_AUTO_LOGIN=false`로 되돌릴 것.
- `scripts/deploy_server.sh`는 Flutter 빌드용 `.env`에서 `SOCKET_URL`, `GOOGLE_CLIENT_ID`, `KAKAO_REVIEW_AUTO_LOGIN`만 넘기도록 필터링한다. 이메일/비밀번호류 값은 프론트 build artifact에 들어가면 안 된다.

### Push/Deploy 상태 (2026-07-09)

현재 원격 상태:

```text
origin/main = ef258bb update app surfaces and agent docs
이전 주요 커밋 = d2f3adf feat: add secret map place search and review login
```

`d2f3adf`에는 비밀지도, 장소 검색, Kakao 심사용 자동 로그인, Kakao 비즈 아이콘, 관련 문서/HANDOFF가 포함됐다.
`ef258bb`에는 앱 표면 UI/agent docs 갱신이 포함됐다.

주의할 로컬 미커밋 파일:

```text
.github/workflows/deploy-flutter-web.yml   # 로컬 수정분, 아직 커밋/푸시하지 않음
.github/workflows/ci.yml                   # 새 CI workflow, 아직 커밋/푸시하지 않음
```

이 두 workflow 파일은 GitHub OAuth 토큰에 `workflow` scope가 없어서 push가 거절됐기 때문에 의도적으로 커밋에서 제외했다.
운영 서버 배포는 GitHub Pages workflow가 아니라 `.github/workflows/deploy-to-server.yml`이 담당한다.

배포 실패 로그:

```text
Deploy to Server 2
2026/07/09 07:05:32 Error: missing server host
```

원인:

- `deploy-to-server.yml`의 `appleboy/ssh-action`이 `host: ${{ secrets.SERVER_HOST }}`를 사용한다.
- GitHub Actions repository secret `SERVER_HOST`가 비어 있어서 SSH 액션이 시작되기 전에 실패했다.

필요한 GitHub Actions secrets:

```text
SERVER_HOST=100.97.58.29
SERVER_USER=ubuntu
SERVER_SSH_KEY=< /Users/junzzang/Downloads/ssh-key-2026-07-06.key 파일 내용 전체 >
```

`SERVER_SSH_KEY`는 파일 경로가 아니라 `-----BEGIN OPENSSH PRIVATE KEY-----`부터 `-----END OPENSSH PRIVATE KEY-----`까지 전체 내용이다.

주의:

- `100.97.58.29`는 Tailscale IP다.
- GitHub hosted runner가 Tailscale 네트워크에 붙어 있지 않으면 다음 실패는 `missing server host`가 아니라 SSH timeout일 수 있다.
- timeout이 나면 workflow에 Tailscale 연결 단계를 추가해야 한다. 이 workflow 수정은 `workflow` scope가 있는 GitHub token/권한으로 push해야 한다.

GitHub Pages 관련 실패:

```text
Branch "main" is not allowed to deploy to github-pages due to environment protection rules.
The deployment was rejected or didn't satisfy other protection rules.
```

이 실패는 운영 서버 배포와 별개다.
`deploy-flutter-web.yml`은 GitHub Pages 배포용이고, 운영 도메인 `https://secertbase.kro.kr` 배포는 `deploy-to-server.yml` → `scripts/deploy_server.sh`가 담당한다.

GitHub Pages도 쓰려면 GitHub repo settings에서:

```text
Settings -> Environments -> github-pages -> Deployment branches and tags
```

에서 `main` 배포를 허용하거나 required reviewer를 승인해야 한다.

운영 서버 수동 배포 명령:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -t ubuntu@100.97.58.29 'cd ~/SecertBase && exec bash -l'
git pull origin main
./scripts/deploy_server.sh
```

현재 확인:

```text
https://secertbase.kro.kr/health => {"ok":true}
```

1. Kakao Developers에서 Open Map and Local / 카카오맵 로컬 API 활성화 후 Kakao 검색 재확인.
2. Naver Maps Geocoding 구독/권한 활성화 후 geocode fallback 재확인.
3. `/api/places/search`를 운영 서버에 배포하고, 운영 `.env`에 API 키 4개 입력.
4. `map_pins` 스키마 확장:
   - `couple_id`
   - `user_id`
   - `status`
   - `emotion_tags`
   - `provider`
   - `provider_place_id`
   - `address`
   - `road_address`
   - `phone`
   - `place_url`
5. `/api/map` 인증/권한 정리:
   - `GET /api/map`은 로그인 사용자의 couple scope로 제한.
   - `POST /api/map`은 JWT 사용자 기준으로 작성자/커플 설정.
   - `PATCH/DELETE`는 작성자만 가능.
6. Flutter 저장/상세 UI를 확장 스키마와 실제 contract에 맞게 연결.
7. 추천 둘러보기/공유/댓글/하트는 그 다음 vertical slice.

## 1. Codex 이전 업데이트 (2026-07-08)

### UI/UX 정식 출시 방향 재전환 진행 중

사용자 피드백:

- 이전에 "과한 사랑스러움/귀여움"을 줄이려고 딥 와인 + 앤틱 골드 + 성숙한 톤으로 바꿨지만, 결과적으로 앱의 정체성이 약해짐.
- 지금 방향은 **사랑스럽고 귀여운 색감/로고/폰트는 유지**하되, **레이아웃/버튼/화면 구조를 정식 출시 수준으로 전면 개선**하는 것.
- 설정 탭은 현재 디자인이 마음에 든다고 했으므로 건드리지 말 것.

반영한 1차 UI 변경:

- `apps/secret_base_app/lib/core/main_design.dart`
  - 캔디 핑크/피치/허니/스카이 계열 팔레트 복구.
  - `mainTitle()`을 `GoogleFonts.gaegu`로 복구.
  - `CozyMascot`을 겹친 링이 아니라 볼터치 있는 캐릭터 로고로 복구/개선.
  - `MainCard` radius를 다시 22 중심으로 조정.
- `apps/secret_base_app/lib/core/app_theme.dart`
  - 전역 테마도 새 핑크/피치 계열로 동기화.
- `apps/secret_base_app/lib/screens/home/home_screen.dart`
  - 홈 첫 화면의 정보량을 줄이고 `D-day + 하트 CTA + 오늘 질문/미션` 중심으로 재배치.
  - 하트 전송은 큰 그라디언트 CTA로 바꿈.
  - 오늘 질문/미션 카드에서 칩/중첩 박스를 줄여 시야 분산 완화.
- `apps/secret_base_app/lib/screens/arcade/arcade_screen.dart`
  - 기존 2열 게임 격자 제거.
  - 상단에 인스타 스토리처럼 가로 스크롤 가능한 원형 게임 선택 목록 추가.
  - 선택한 게임이 아래 큰 상세 패널에 표시됨: 게임 로고, 공지/태그, 설명, `게임 접속` 버튼.
  - `커플 밸런스`, `소원권`, `10시의 질문`은 놀이 탭에서 제거. 놀이 탭은 실시간 게임만 남김.
  - 사용자 반응: "와 존나 맘에 들어" — 현재 방향 유지.
- `apps/secret_base_app/lib/screens/archive/archive_screen.dart`
  - 기존 둥근 사각형 버튼 7개 격자 제거.
  - 대표 기록 카드(`MomentLoop`) + 가로 컬렉션(`비밀 지도`, `우리 앨범`, `타임캡슐`) + 하단 리스트(`마음 대피소`, `마음 교감`, `추억 저장고`) 구조로 변경.
  - 기록 탭은 놀이 탭과 다른 성격의 "추억 컬렉션/피드" 느낌으로 가야 함.
- `apps/secret_base_app/lib/main.dart`
  - 미사용 `EntryScreen` import 제거.

로컬 개발 프록시 정리:

- 기존 HANDOFF에는 휘발성 스크래치패드 프록시가 적혀 있었는데, 이번에 레포 안으로 옮김.
- 추가 파일: `scripts/local-dev-proxy.js`
  - 의존성 없이 Node 기본 `http`/`https`/`tls`로 동작.
  - `/api`, `/socket.io`, `/uploads`, `/health`를 `https://secertbase.kro.kr`로 프록시.
  - WebSocket upgrade도 처리.
- 현재 실행 방식:

```bash
node scripts/local-dev-proxy.js
cd apps/secret_base_app
flutter run -d web-server --web-port=5050 --dart-define-from-file=.env_dev
```

현재 로컬 서버 상태:

```text
http://localhost:3000  local-dev-proxy, /health -> {"ok":true}
http://localhost:5050  Flutter web-server
```

현재 세션에서 실행 중이던 프로세스:

```text
3000: node scripts/local-dev-proxy.js
5050: dartvm flutter web-server
```

다음 세션에서는 `lsof -nP -iTCP:3000 -sTCP:LISTEN` / `lsof -nP -iTCP:5050 -sTCP:LISTEN`으로 먼저 확인할 것.

검증:

```text
dart format: pass for touched Flutter files
flutter analyze: exits 1 because existing info-level lints remain, but no new warning/error from touched files
flutter build web: pass
flutter test: still fails before tests load because existing dart:html imports are not VM-test compatible
```

`flutter build web`의 WASM dry-run 경고는 기존 이슈:

- `lib/core/uno_audio.dart` imports `dart:html`
- `lib/screens/archive/jukebox_screen.dart` imports `dart:html`
- 일반 Flutter Web build는 성공.

### 비밀 지도 관련 확인 / 최신 상태 (2026-07-09)

사용자가 "비밀지도 어떻게 할건지 내가 어디 적어놨나?"라고 물어 확인함.

찾은 기획/구현 메모:

- `docs/notion/01_project_planning.md`
  - 커플의 데이트 장소를 핀 형태로 저장.
  - 카테고리: 식당, 카페, 활동, 여행, 쇼핑, 기타.
  - 방문 날짜, 별점(1-5), 동행 메모 기록.
- `docs/WORKLOG.md`
  - 향후 지도 연동: Naver/Kakao Maps.
  - 이 문서는 PostgreSQL 등 stale 내용도 있으므로 아키텍처 판단에는 주의.
- `docs/WHAT_I_DID.md`
  - 현재 구현은 지도 SDK 없이 리스트 뷰.
  - `apps/secret_base_app/lib/screens/archive/map_screen.dart`
  - `GET /api/map`, `POST /api/map`, `PATCH /api/map/:id`.
- `docs/REST_API.md`
  - `/map` API 계약.
- `services/realtime-server/schema.sql`
  - `map_pins` 테이블.

현재 비밀 지도 상태:

- 실제 지도 UI가 들어와 있음.
- `apps/secret_base_app/lib/screens/archive/map_screen.dart`
  - `flutter_map` + `latlong2` 기반.
  - Carto/OSM 타일: `https://{s}.basemaps.cartocdn.com/rastertiles/voyager/...`
  - Nominatim 검색 API로 장소/주소 검색.
  - 지도 탭으로 임시 좌표 선택 후 장소 등록.
  - 등록된 핀은 카테고리 이모지 마커로 표시.
  - 하단 PageView 카드와 지도 중심 이동이 연동됨.
  - 카테고리 필터: 전체, 식당, 카페, 활동, 여행, 쇼핑, 기타.
  - 장소 추가 다이얼로그: 이름, 카테고리, 별점, 방문 날짜, 메모, 좌표.
- `apps/secret_base_app/pubspec.yaml`
  - `flutter_map: ^6.1.0` 의존성이 추가되어 있음.
- 백엔드 API:
  - `GET /api/map`: `SELECT * FROM map_pins ORDER BY visit_date DESC`
  - `POST /api/map`: place/category/rating/date/memo/created_by/latitude/longitude 저장.
  - `PATCH /api/map/:id`: rating/memo만 수정.
- DB:
  - `services/realtime-server/schema.sql`의 `map_pins`는 `place_name`, `latitude`, `longitude`, `category`, `rating`, `visit_date`, `memo`, `created_by`만 갖고 있음.

중요한 운영/기획 리스크:

- 현재 `/api/map`은 인증 토큰, `couple_id`, `user_id` 기준 조회가 아니다.
- `GET /api/map`은 모든 커플/사용자의 핀을 반환할 수 있는 구조다.
- `POST /api/map`도 클라이언트가 보내는 `created_by` 문자열을 그대로 믿는다.
- `PATCH /api/map/:id`는 소유권 검증 없이 id 기준으로 수정한다.
- 비밀지도는 커플 프라이버시 기능이므로 출시 전 최우선으로 couple scope / auth scope를 잡아야 한다.
- 현재 검색은 외부 Nominatim에 직접 요청한다. 사용량 정책/속도 제한/장애 대응을 별도로 검토해야 한다.

권장 다음 방향:

- 바로 새 지도 SDK로 갈아타기보다, 먼저 현재 `flutter_map` 기반 화면을 제품 요구사항에 맞게 확정할 것.
- 1순위 vertical slice: `map_pins`에 `couple_id`/`user_id` 또는 그에 준하는 소유권 컬럼 추가 → `/api/map`을 로그인 사용자/커플 기준으로 제한 → Flutter 요청도 인증 기반으로 정리 → backend test/check.
- 2순위: 지도 UX 기획 결정. 예: "다녀온 곳", "가고 싶은 곳", "추억 밀도", "장소별 사진/셋로그 연결", "둘만의 별명/태그".
- 3순위: 검색/지도 제공자 정책 결정. OSM/Nominatim 유지, 서버 프록시, Kakao/Naver 전환 중 선택.
- 4순위: UI polish. 현재 앱의 사랑스럽고 귀여운 색감은 유지하되, 지도 화면은 정보 구조와 조작 안정성을 정식 출시 수준으로 다듬기.

추가 기획 정리:

- 새 문서: `docs/SECRET_MAP_PLAN.md`
- 비밀지도 핵심 방향:
  - 메인 지도에서 다녀온 장소와 다음에 갈 위시리스트를 함께 본다.
  - `상태(다녀온 곳/가고 싶은 곳)`와 `카테고리(식당/카페/활동/여행/쇼핑/기타)`를 분리한다.
  - 위시리스트 장소는 `다녀왔어요` 흐름으로 방문 기록이 되며, 방문 평가 작성 시 작은 앱 내 리워드를 줄 수 있다.
  - 별점은 유지하되, `또 가자`, `특별했어`, `웃겼어` 같은 감정 태그와 결합해 Secret Base다운 평가 기능으로 만든다.
  - 사진은 MVP에서 핀 직접 업로드보다 MomentLoop 연결을 먼저 고려한다.
  - 커플 내부에서는 작성자를 보여주고, 외부 추천에서는 공동 기록처럼 보이게 한다.
  - 파트너 반응은 하트/댓글을 지원한다.
  - 삭제/수정은 작성자만 가능하게 한다.
  - 추천은 기본 지도에 섞기보다 `추천 둘러보기` 탭/모드로 분리한다.
  - 공유는 카카오톡 링크/장소 카드, 이후 럽스타형 이미지 공유까지 고려한다.
  - 지도/검색은 비용을 최소화하는 방향으로 서버 프록시를 둔다. 현재 구현은 `/api/places/search`에서 Kakao Local을 우선 사용하고, Kakao가 비활성화되어 있으면 NAVER API HUB Search Local로 보강/대체한다.
- 제품 의도:
  - 사랑을 과시하거나 소비하는 기능이 아니라, 건강하고 예쁜 관계를 자연스럽게 기록하고 공유하게 돕는 서비스로 잡는다.
  - 한국에서 커플 표현이 불편함/질투/조롱의 대상으로 소비되는 분위기를 바꾸고, "나도 예쁜 사랑을 해보고 싶다"는 긍정적 이미지를 만드는 방향.

### 현재 로컬에 남아 있는 미커밋 변경 업데이트

이번 UI 작업과 이전 AI 문서/CI 작업이 같은 worktree에 섞여 있음. 커밋 전 반드시 분리해서 확인할 것.

현재 확인된 변경:

```text
 M .github/workflows/deploy-flutter-web.yml
 M apps/secret_base_app/lib/core/app_theme.dart
 M apps/secret_base_app/lib/core/main_design.dart
 M apps/secret_base_app/lib/main.dart
 M apps/secret_base_app/lib/screens/arcade/arcade_screen.dart
 M apps/secret_base_app/lib/screens/archive/archive_screen.dart
 M apps/secret_base_app/lib/screens/home/home_screen.dart
?? .github/workflows/ci.yml
?? AGENTS.md
?? CLAUDE.md
?? CONTEXT.md
?? HANDOFF.md
?? docs/AI_AGENT_WORKFLOW.md
?? scripts/local-dev-proxy.js
```

추천 커밋 분리:

1. AI 문서/워크플로우 문서: `CONTEXT.md`, `AGENTS.md`, `CLAUDE.md`, `docs/AI_AGENT_WORKFLOW.md`, `HANDOFF.md`
2. CI/deploy 워크플로우: `.github/workflows/*`
3. 로컬 개발 프록시: `scripts/local-dev-proxy.js`
4. Flutter UI refresh: `app_theme.dart`, `main_design.dart`, `main.dart`, `home_screen.dart`, `arcade_screen.dart`, `archive_screen.dart`

주의:

- 아래 `## 4. 미해결: 서버가 origin/main과 diverge된 상태` 섹션은 과거 Claude 세션 기록이다.
- 최신 섹션 기준으로 서버 divergence는 이미 `b190e9a`로 복구 완료됐으므로, 아래 내용을 현재 미해결로 오해하지 말 것.

### AI 작업 방식 세팅

Codex에서 프로젝트를 AI 친화적으로 다루기 위해 다음 파일을 추가했다.

- `CONTEXT.md`: Claude/Codex가 먼저 읽을 프로젝트 용어집, 현재 아키텍처, source of truth, stale docs 경고.
- `docs/AI_AGENT_WORKFLOW.md`: 이 레포 기준의 grill-with-docs, TDD, diagnosing-bugs, code-review, handoff 워크플로우.
- `AGENTS.md`: Codex용 짧은 프로젝트 지침.
- `CLAUDE.md`: Claude Code용 짧은 프로젝트 지침.

중요한 문서 정정:

- 현재 백엔드는 MariaDB/MySQL + `mysql2`를 사용한다.
- `PROGRESS_SUMMARY.md`, `DEVELOPMENT_LOG.md`, `docs/WORKLOG.md` 일부에는 PostgreSQL이라고 적힌 오래된 내용이 남아 있다.
- AI 세션에서는 `CONTEXT.md`, `docs/PROJECT_OVERVIEW.md`, `docs/REST_API.md`, `docs/SOCKET_EVENTS.md`, 현재 코드를 우선 source of truth로 봐야 한다.

### 서버 divergence 복구 완료

이전 미해결 항목이었던 "서버에만 있는 `e792dc7` 커밋 회수 및 origin/main 정리"는 완료됐다.

처리 결과:

- 서버 전용 커밋 `e792dc7`의 변경 내용을 회수했다.
- 로컬 최신 `main` 위에 새 커밋으로 재반영했다.
- 새 커밋 `b190e9a fix: recover server caddy and google auth schema changes`를 `origin/main`에 push했다.
- 운영 서버 `/home/ubuntu/SecertBase`의 `main`을 `origin/main`으로 맞췄다.
- 기존 서버 전용 커밋은 `backup/server-e792dc7` 브랜치로 보존했다.
- Caddy 설정을 `/etc/caddy/Caddyfile`에 적용하고 reload했다.
- `scripts/deploy_server.sh`를 서버에서 실행해 backend test/check, Flutter web build, PM2 restart, health check까지 완료했다.

반영 파일:

- `docs/deployment/Caddyfile`
- `docs/deployment/SERVER_SETUP.md`
- `services/realtime-server/schema.sql`
- `services/realtime-server/src/routes.js`

Google 로그인 관련 실제 수정:

- `PasswordHash`, `PasswordSalt`를 신규 schema에서 `NULL` 허용으로 변경했다.
- 기존 운영 MariaDB 테이블도 `ensureUserColumns()`에서 `NOT NULL`이면 `NULL` 허용으로 자동 보정하도록 했다.
- 운영 DB 확인 결과:
  - `PasswordHash`: `IS_NULLABLE = YES`
  - `PasswordSalt`: `IS_NULLABLE = YES`
- 배포된 `routes.js`에서 과거 문제였던 `ModifiedBy`/`ModifiedDateTime` SET 절은 제거된 상태다.

검증 결과:

```text
backend npm test: pass, 11 tests
backend npm run check: pass
Caddy validate: pass
server deploy: complete
PM2 secretbase-realtime: online
http://localhost:4100/health: {"ok":true}
https://secertbase.kro.kr/health: {"ok":true}
server git status: clean
server HEAD: b190e9a
server origin/main: b190e9a
```

현재 실제 운영 서버 접속 정보:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key ubuntu@100.97.58.29
cd /home/ubuntu/SecertBase
```

### 현재 로컬에 남아 있는 미커밋 변경

서버 divergence 복구 커밋에는 섞지 않고 남겨둔 변경:

```text
 M .github/workflows/deploy-flutter-web.yml
?? .github/workflows/ci.yml
?? AGENTS.md
?? CLAUDE.md
?? CONTEXT.md
?? HANDOFF.md
?? docs/AI_AGENT_WORKFLOW.md
```

다음 세션에서 할 일:

1. 위 AI 작업 방식 문서들을 커밋할지 결정.
2. `.github/workflows/deploy-flutter-web.yml`, `.github/workflows/ci.yml` 변경 의도를 확인하고 별도 커밋 여부 결정.
3. 새 기능 요구사항을 받으면 `CONTEXT.md`를 먼저 읽고, 작은 vertical slice 단위로 진행.

## 배경

`SecertBase`는 커플 전용 앱 (Flutter 웹 프론트 `apps/secret_base_app` + Node/Express/Socket.io
백엔드 `services/realtime-server`, MariaDB, 운영 도메인 `https://secertbase.kro.kr`).
디자인이 "너무 귀엽고 사랑스러운(하트하트)" 느낌이라 성숙한 커플 감성으로 바꿔달라는 요청으로 시작.

## 1. 디자인 개편 (완료, 배포됨)

- **색상**: 캔디핑크 팔레트 → 딥 와인 + 앤틱 골드 톤. `apps/secret_base_app/lib/core/main_design.dart`,
  `lib/core/app_theme.dart`에서 색상 상수 전면 교체 (`kMainRose`, `kMainHoney`, `kRoseGrad` 등).
  배경도 블러시 핑크 → 웜 아이보리.
- **폰트**: 제목용 `GoogleFonts.gaegu`(손글씨) → `GoogleFonts.notoSerifKr`(세리프)로 교체.
  `mainTitle()` 한 곳만 바꿔서 앱 전체(26개+ 화면)에 자동 반영됨.
- **마스코트**: 블러시 볼터치 있는 캐릭터 얼굴(`CozyMascot`/`_MascotPainter`) → 겹쳐진 두 개의 링(커플
  상징) 미니멀 마크로 재설계.
- **레이아웃 정리**:
  - `MainCard` 기본 corner radius 22 → 16.
  - entry_screen: 둥둥 떠다니던 하트 아이콘들, 기울어진 "Secret" 마스킹테이프 스티커, "짜잔!" 문구 제거.
  - home_screen: 130px 짜리 글로우+펄스 애니메이션 하트 전송 버튼 → 차분한 아이콘+텍스트 행(row)으로
    교체 (`_heartSection()`). 룰렛/타임캡슐 퀵카드 이모지(🎲🕯️) → 실제 아이콘(`casino_outlined`,
    `inventory_2_outlined`)으로 교체. ❤️/✨/💕/🌿 이모지 전부 제거.
  - partner_screen: 하트 구분선 아이콘 완전 제거, "연결 시작!" → "연결하기", 스낵바 문구 톤 다운.
  - `heart_overlay.dart` (하트 받았을 때 풀스크린 애니메이션): 캔디색 하트/💓 이모지 → 새 팔레트 톤으로
    교체.
- **미해결 스코프**: 아케이드 미니게임들은 같은 토큰을 써서 색만 자연히 톤다운됨. `date_roulette_screen.dart`는
  자체 하드코딩 팔레트+이모지 카드라 손 안 댐. archive 하위 화면들(앨범/타임라인/편지 등)도 미착수.

## 2. 로컬 개발 환경 구축 (완료)

- 이 macOS 머신엔 Flutter가 전혀 없었음 → `brew install --cask flutter`로 설치 완료 (3.44.5).
- **운영 DB를 그대로 쓰는 방식**으로 결정 (로컬 MariaDB는 안 세움). 문제: 브라우저에서 로컬 포트로 실행하면
  실제 서버(`secertbase.kro.kr`)가 CORS를 막음 (그 서버는 Caddy가 프론트+백엔드를 같은 도메인에서 서빙하는
  구조라서 원래 CORS라는 개념 자체가 없음).
- **해결**: 로컬 리버스 프록시를 만들어서 `/api`, `/socket.io`, `/uploads`, `/health`는 실제 서버로 전달하고,
  나머지는 로컬 `build/web` 정적 파일을 서빙. 브라우저 입장에서는 전부 동일 origin으로 보여서 CORS 문제 없음.
  - 위치: `/private/tmp/claude-501/-Users-junzzang-BACKUP-workspace-SecertBase/d3c4c7c2-706c-46a9-a789-bda9fa1c7e29/scratchpad/local-proxy/server.js`
    (⚠️ 이 경로는 세션 스크래치패드라 **휘발성**임 — Codex에서 이어가려면 이 프록시 스크립트를 레포 안
    적절한 위치(예: `scripts/local-dev-proxy.js`)로 옮기는 걸 추천)
  - `http-proxy` npm 패키지 사용. `/api`, `/socket.io`, `/uploads`, `/health` prefix는
    `https://secertbase.kro.kr`로 프록시 (WebSocket 업그레이드 포함), CORS 헤더는 요청 Origin을
    그대로 반사해서 허용 (`proxy.on('proxyRes', ...)`로 강제 오버라이드).
  - 실행: `node server.js` → `http://localhost:3000`에서 리슨.
- **`.env` / `.env_dev` 분리** (Flutter의 `--dart-define-from-file` 사용, 별도 패키지 불필요):
  - `apps/secret_base_app/.env` — 운영용 (`SOCKET_URL=https://secertbase.kro.kr`), git에 안 올라감.
  - `apps/secret_base_app/.env_dev` — 로컬용 (`SOCKET_URL=http://localhost:3000`, 위 프록시 주소),
    git에 안 올라감.
  - `apps/secret_base_app/.env.example` — 템플릿, git에 커밋됨.
  - `.gitignore`에 `.env_dev` 추가.
  - **빌드**: `flutter build web --dart-define-from-file=.env_dev` (release, 수동 새로고침 필요)
  - **개발 모드(핫리로드)**: `flutter run -d chrome --web-port=5050 --dart-define-from-file=.env_dev`
    (⚠️ macOS는 `--web-port=5000`이 AirPlay Receiver가 이미 점유하고 있어서 못 씀, 5050 사용)
  - `scripts/deploy_server.sh`는 서버에 `apps/secret_base_app/.env`가 있으면 그걸 우선 사용하고,
    없으면 기존 방식(CI가 넘겨주는 `SOCKET_URL`/`GOOGLE_CLIENT_ID` 환경변수)으로 폴백하도록 수정함
    (운영 배포 파이프라인은 안 깨짐).

## 3. 발견/수정한 버그 (일부만 배포됨 — 아래 "미해결" 참고)

### 3-1. `google_sign_in_web`에 웹 미지원 파라미터 전달 (수정 완료, 배포됨)
- `apps/secret_base_app/lib/core/auth_service.dart`의 `initGoogleSignIn()`이 웹에서 `serverClientId`를
  같이 넘겨서 `assert(params.serverClientId == null)` 실패 → 디버그 모드(`flutter run`)에서 앱이 아예
  안 뜸. release 빌드는 `assert`가 제거돼서 안 보였던 것.
- 수정: `serverClientId: kIsWeb ? null : googleClientId` (kIsWeb 체크 추가).
- 이건 프론트엔드 코드라 커밋 `456eaa8`에 포함, **정상 배포됨**.

### 3-2. `services/realtime-server/src/routes.js`의 `ModifiedBy`/`ModifiedDateTime` 컬럼 (수정함, 배포 안 됨!)
- Users 테이블 UPDATE 3곳(구글 계정 연동, 프로필 수정, 비밀번호 변경)이 스키마에 없는
  `ModifiedBy`/`ModifiedDateTime` 컬럼을 SET 하려고 해서 `ER_BAD_FIELD_ERROR` 발생 →
  `/api/auth/google`가 500 대신 401(`google_auth_failed`)로 응답해서 "계정 선택창만 계속 뜨는" 것처럼
  보였음. 이 두 컬럼은 코드 어디서도 읽지 않는 죽은 컬럼이라 (Users 테이블엔 이미 `updated_at`이 자동
  갱신됨) SET 절에서 제거하는 걸로 수정.
- 커밋 `456eaa8`에 포함, **로컬에서 push까지는 했지만 서버 자동배포는 실패**함 (아래 참고).

## 4. 미해결: 서버가 origin/main과 diverge된 상태 ⚠️ **가장 먼저 처리해야 함**

- 서버(`~/SecertBase`, host: 배포 워크플로우 secrets의 `SERVER_HOST`)에서 `git log -1`을 찍어보니
  `e792dc7 (HEAD -> main) feat: add Caddy config for Server 2 and fix Google login DB constraint`가
  나옴. 이 커밋은 **GitHub(origin/main)엔 존재하지 않음** (`git fetch` 후 확인, `git cat-file -t e792dc7`
  실패) — 즉 서버에서 로컬로만 커밋되고 push는 안 된 상태.
- 이것 때문에 GitHub Actions 자동배포(`deploy-to-server.yml` → `scripts/deploy_server.sh`)의
  `git pull --ff-only origin main`이 fast-forward 불가로 실패 → 배포 스크립트가 `set -euo pipefail`로
  거기서 중단됨 → pm2 재시작도 안 됨 → 서버는 여전히 옛날(버그 있는) 코드로 계속 떠 있는 상태.
  (`/health`가 계속 200으로 응답한 이유이기도 함 — 프로세스 자체는 안 죽고 그냥 안 바뀐 것)
- `e792dc7`의 커밋 메시지를 보면 **이것도 진짜 필요한 수정**임: (a) `secertbase.kro.kr` DNS가 이미
  Server 2의 Caddy를 가리키는데 매칭되는 site block이 없어서 HTTPS가 깨져 있었던 문제 (Caddy 설정 추가로
  해결 시도), (b) `PasswordHash`/`PasswordSalt` NOT NULL 제약 때문에 신규 유저가 구글로 처음 가입할 때
  (INSERT 경로) `ER_BAD_NULL_ERROR`로 실패하던 문제. **내가 고친 `ModifiedBy` 버그(UPDATE 경로, 기존
  유저 재로그인)와는 다른 버그라 둘 다 필요함.**
- `git show e792dc7 --stat`과 `git show e792dc7 -- services/realtime-server/src/routes.js
  services/realtime-server/schema.sql` 전체 출력을 요청했는데 사용자가 페이저 때문에 중간에 잘려서
  못 받음 — **다음 단계로 다시 받아야 함** (`git show e792dc7 --stat | cat` 등 페이저 없이).
- 로컬에 있는 untracked 파일들(`docs/deployment/Caddyfile`, `.github/workflows/ci.yml`,
  수정된 `.github/workflows/deploy-flutter-web.yml`)이 아마 이 "Server 2 Caddy" 작업과 관련된
  로컬 미커밋 작업으로 보임 — 이번 세션에서는 의도적으로 건드리지 않고 그대로 뒀음.

### 다음에 할 일
1. 서버에서 `git show e792dc7 --stat | cat` 및 관련 파일 전체 diff를 다시 받아서 정확히 뭐가
   바뀌었는지 확인.
2. `e792dc7`의 두 수정사항(Caddy 설정, PasswordHash/PasswordSalt NOT NULL 완화)을 로컬 `main`
   (`456eaa8` 기준)에 반영 — 예: 서버에서 해당 커밋을 `git format-patch`로 뽑아서 로컬에 적용하거나,
   diff 내용을 보고 수동으로 재현.
3. 로컬에서 커밋 → push → `deploy-to-server.yml` 재트리거 → `git pull --ff-only` 성공 확인 →
   `pm2 logs secretbase-realtime`으로 실제 재시작 확인.
4. 서버의 로컬 전용 커밋(`e792dc7`)은 이제 origin에 흡수됐으니, 서버에서
   `git reset --hard origin/main` (또는 동일 효과) 로 정리 — **주의: 서버에 다른 미커밋/미푸시
   변경사항이 더 있는지 먼저 확인 후 진행할 것.**
5. 구글 로그인 재테스트 (기존 유저 재로그인 + 신규 유저 첫 가입 두 경로 모두).

## 5. 참고: 로컬에서 계속 테스트하려면

```bash
# 로컬 프록시 (CORS 우회, 실제 서버로 /api 전달) — 이미 떠 있으면 생략
cd <프록시 스크립트 위치>  # 위 3번 항목 참고, 레포로 옮기는 걸 권장
node server.js   # http://localhost:3000

# Flutter 개발 모드 (핫리로드)
cd apps/secret_base_app
flutter run -d chrome --web-port=5050 --dart-define-from-file=.env_dev
```

Google 로그인 관련해서 로컬 포트(`http://localhost:3000`, `http://localhost:5050`)를 Google Cloud
Console의 OAuth 클라이언트(`999734545507-blrukf3rd81kse4j5bjhm93ppsoaniat.apps.googleusercontent.com`)
"승인된 자바스크립트 출처"에 등록해야 로컬에서 구글 로그인 테스트가 됨.
