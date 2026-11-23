# 03 기지 초대장 (링크로 상대 초대)

용어: 사용자, 활성 커플, 파트너 연결(페어링 요청). 표면 이름은 "기지 초대장".

## What to build
- 서버: `GET /i/:code` 공개 랜딩(HTML, 앱 열기/설치 안내, 초대자 닉네임 외 개인정보 미노출, 코드 존재 여부를 열거 공격으로 알 수 없게 일정한 응답). `/.well-known/assetlinks.json`는 값이 외부 키스토어 SHA-256에 의존하므로 **환경 변수 기반 라우트로 만들되 값은 비워 두고 문서화**.
- 기존 페어링 요청 API를 그대로 쓴다(링크는 UserCode를 앱에 전달할 뿐 수락 동의를 대신하지 않는다 — MVP 스펙 사용자 스토리 7).
- 앱: `app_links`로 `https://secretbase.cloud/i/<code>`와 `secretbase://invite/<code>`를 받아 가입/로그인 후 "이 분에게 연결 요청" 확인 화면으로 이동(자동 전송 금지, 사용자 확인 필수). 파트너 화면에 "초대장 보내기" 버튼(시스템 공유 시트, 문구는 직접 작성).
- 미가입자 흐름: 링크로 앱 설치→가입→초대 코드 보존→로그인 후 확인 화면.
- `AndroidManifest.xml`에 intent-filter(App Links, `autoVerify`), `pubspec.yaml`에 `app_links`, 공유는 `share_plus`.
- 레이트리밋: `/i/:code` 조회 제한.

## Acceptance
- [ ] 서버 테스트: 랜딩 응답 일정성, 잘못된 코드, 레이트리밋.
- [ ] 앱 테스트: 딥링크 파싱, 미가입/가입 상태별 라우팅, 자동 전송이 일어나지 않음.
- [ ] 문서: `docs/deployment/`에 assetlinks 설정 절차.
- [ ] `flutter analyze`, `flutter test`, `npm test` 통과.

## Blocked by
없음 (단, 이 티켓이 `pubspec.yaml`·`AndroidManifest.xml`을 먼저 소유한다. 04는 이후)
