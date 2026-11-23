# 기지 초대장 App Links 설정

`https://secretbase.cloud/i/<코드>` 링크를 Android 앱이 바로 열도록 하는 설정 절차다.
설정 전에도 동작은 한다. 앱 인증이 없으면 브라우저 랜딩 페이지의 "비밀기지 앱에서 열기"
버튼(`secretbase://invite/<코드>`)으로 앱이 열린다.

## 구성 요소

| 위치 | 역할 |
| --- | --- |
| 서버 `GET /i/:code` | 모든 코드에 같은 공개 안내 페이지를 돌려준다(코드 존재 여부·닉네임 미노출, IP당 분당 30회 제한) |
| 서버 `GET /.well-known/assetlinks.json` | 환경 변수 값으로 만든 Digital Asset Links. 값이 없으면 `[]` |
| 앱 `AndroidManifest.xml` | `https://secretbase.cloud/i/` 인텐트 필터(`autoVerify`)와 `secretbase://invite` 필터 |
| `Caddyfile` | `/i/*`, `/.well-known/assetlinks.json`을 정적 파일 대신 서버(4100)로 프록시 |

## 환경 변수 (`services/realtime-server/.env`)

```
# 앱 서명 인증서 SHA-256 지문. 쉼표로 여러 개(업로드 키 + Play 앱 서명 키 등)
ANDROID_APP_LINK_SHA256=
# 기본값 com.secretbase.secret_base_app
ANDROID_PACKAGE_NAME=
```

지문 형식은 `AA:BB:...` 32바이트(콜론 구분 대문자 hex)다. 형식이 틀린 값은 무시된다.

## 절차

1. 지문을 얻는다.
   - 릴리스 키스토어: `keytool -list -v -keystore <keystore> -alias <alias>` 의 `SHA256:` 줄.
   - Google Play 앱 서명을 쓰면 Play Console → 앱 무결성 → 앱 서명 키 인증서의 SHA-256도 함께 넣는다.
     (업로드 키 지문만으로는 스토어 배포본이 인증되지 않는다.)
   - 키스토어와 비밀번호는 저장소에 넣지 않는다([ANDROID_RELEASE_SIGNING.md](ANDROID_RELEASE_SIGNING.md) 참고).
2. 서버 `.env`에 `ANDROID_APP_LINK_SHA256`을 넣고 서버를 재시작한다(PM2).
3. Caddy 설정을 반영한다(`/i/*`, `/.well-known/assetlinks.json` 프록시). `sudo systemctl reload caddy`.
4. 확인한다.
   ```bash
   curl -s https://secretbase.cloud/.well-known/assetlinks.json
   curl -s -o /dev/null -w '%{http_code} %{content_type}\n' https://secretbase.cloud/i/ABC234
   ```
   첫 명령은 지문이 들어간 JSON, 둘째는 `200 text/html`이어야 한다. 존재하지 않는 코드도 같은 응답이어야 한다.
5. 앱을 새로 설치한 단말에서 검증 상태를 본다.
   ```bash
   adb shell pm get-app-links com.secretbase.secret_base_app
   adb shell pm verify-app-links --re-verify com.secretbase.secret_base_app
   adb shell am start -a android.intent.action.VIEW -d "https://secretbase.cloud/i/ABC234"
   ```
   `secretbase.cloud: verified`가 보이면 완료다. 검증 전에는 링크가 브라우저로 열리고 랜딩 페이지의 버튼으로 앱을 연다.

## 동작 원칙

- 링크는 상대의 사용자 코드를 앱에 전달할 뿐이다. 앱은 로그인·가입 후 "이 분에게 연결 요청을 보낼까요?"를
  보여 주고, 사용자가 누를 때만 기존 `POST /api/pairing/requests`를 호출한다. 수락은 받는 쪽이 따로 한다.
- 가입 전에 링크를 연 경우 코드는 기기에 보존되었다가 로그인 뒤 확인 화면에서 쓰인다.
- 랜딩 페이지는 닉네임을 포함해 어떤 정보도 조회하지 않는다. 코드는 브라우저 스크립트가 주소에서 읽는다.
- 앱 스토어 링크는 아직 페이지에 넣지 않았다. 스토어 URL이 확정되면 `src/app/base-invite.js`의 안내 문구에 추가한다.
