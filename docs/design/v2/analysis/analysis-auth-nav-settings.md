# 분석: 진입·인증·내비게이션·설정·공용 디자인 시스템 (경로는 apps/secret_base_app/lib/ 기준)

## 1. 인벤토리
| 화면 | 목적 | 핵심 요소 | 진입 |
|---|---|---|---|
| 부트 main.dart | 세션 복원·분기 | auth.init() 후 프로필 재조회. 토큰 없음→Login, PartnerCode 없음→Partner, 소켓 미연결→로딩, 연결됨→HomeShell (:177-247) | 앱 실행 |
| 소켓 로딩 | 연결 대기 | 로고, "입장하는 중...", 하드코딩 `v1.0.4 - 상태`, 실패 시 재시도/로그아웃 | 페어링 후 |
| 로그인 | 진입 | 히어로, "이메일로 로그인"→바텀시트, Google 버튼(GOOGLE_CLIENT_ID 정의 시), "회원가입" | 토큰 없음 |
| 회원가입 | 2단계 | 1/2 이름·닉네임·생일, 2/2 이메일·비번·약관 | 로그인 하단 |
| 파트너 연결 | 코드 페어링 | 내 코드+복사, 상대 코드(6자), 상태 카드, 받은/보낸 요청, 개인 보관함, 닉네임 수정, "다른 계정으로 로그인" | PartnerCode 없을 때 강제 |
| HomeShell | 5탭 셸 | 홈/MomentLoop/지도/놀이/더보기, 오프라인 배너(15초 HEAD 폴링), 푸시 타깃 라우팅 | 연결 후 |
| 더보기 (settings_screen.dart:44) | 허브 | 헤더 "전체"+고객센터, 내 공간 카드, "우리의 공간"(탭 바로가기 3), "기록과 이해"(비밀기지·관계 이해·알림 설정), 버전 | 탭 5 |
| 내 공간 MySpaceScreen (:247) | 계정·연결 | 프로필 요약, 연결된 애인/기념일, 이모지 그리드, 연결 상태(Ping), 접속자, 로그아웃, 탈퇴, 개발자 정보, 법적 링크 | 더보기 |
| 알림 설정 | 푸시 선호 | 스위치 3, 방해금지+시작/종료, 공개 시각 | 더보기 |
| entry_screen.dart | 죽은 코드 | 서버 URL·방 코드·개발용 폼 | 없음 |
권한: 푸시는 페어링 직후 자동 요청(push_service.dart:110-117, 1회), 위치는 지도 탭 진입 즉시(map_screen.dart:92).

## 2. 흐름
- A 이메일 첫 사용: 가입(3입력→다음→이메일/비번/약관→가입) → 로그인 시트가 열려 비번 재입력 → 파트너 화면에서 코드 복사해 수동 전달 → 상대 수락 → 로딩 → 홈. 푸시 팝업이 맥락 없이 뜸. 약 10~12탭, 온보딩 없음.
- B Google 첫 사용: 1~2탭에 계정 생성, 약관·생일·닉네임 단계 없음, 서버가 BirthDate='2000-01-01' 삽입(routes.js:471-475) → 사주·운세 정확도에 영향.
- C 재방문: 토큰 복원 → 프로필 재조회(최대 20초) → 소켓 → 홈. 탭 전환 시 State 폐기.
- D 푸시 진입: pendingPushTarget → Navigator.push 풀스크린, 실패 시 스낵바만.
- E 탈퇴: 더보기→내 공간→맨 아래 흐린 "회원 탈퇴"→다이얼로그 3단. **미연결 사용자는 도달 불가.**
- F 연결 해제: 4탭+확인 2단.

## 3. 문제점
상
1. 인증 화면이 별도 디자인 시스템(네이비 auth* 8색, 입력 반경 18; auth_layout.dart:6-13). 다음 화면(파트너)은 로즈+Gaegu 손글씨체 → 가입 직후 브랜드 인상이 바뀜.
2. Google 가입에 약관 동의 없음, 서버에 동의 이력 필드 없음.
3. 파트너 화면에 로그아웃만 있고 탈퇴·약관·고객센터·알림 링크 없음(partner_screen.dart:241) → 연결 전 사용자는 앱 내 탈퇴 불가(Play 계정 삭제 요건).
4. 비밀번호 찾기 없음(앱·서버 모두 0건).
5. 콜드 스타트 블로킹: main()이 await auth.init()→getProfile()(타임아웃 20초)을 기다려야 runApp.
6. register()가 bool만 반환해 서버의 email_already_exists/invalid_birth_date 구분이 사라짐. 가입 시 비번 규칙 안내·검증 없음(변경 시에만 6자).
7. 푸시 권한 사전 설명 없음·거부 후 안내 없음. 위치는 지도 탭 진입 즉시 요청.
중
8. 더보기 "우리의 공간"은 이미 탭인 3곳 바로가기(중복). 이름이 탭 "더보기"/화면 "전체"/"내 공간"으로 갈림. 탭 라벨 중 "MomentLoop"만 영문. 상점은 놀이 탭 안에서만, 기념일은 홈 카드로만, 사주·타로·궁합·상담은 홈 카드나 관계 이해를 거쳐야 함.
9. 탭 상태 미보존(IndexedStack 아님), PopScope 없어 안드로이드 뒤로가기가 즉시 앱 종료. 더보기는 내부 Navigator라 하단 탭 유지, 다른 탭은 루트 풀스크린이라 이동 규칙이 다름.
10. 접근성: 흰 배경 대비비 kMainMuted 2.26, kMainRose(흰 글자 버튼 포함) 2.62, kMainSage 2.28, kMainHoney 1.66, authMuted 2.12 — 전부 AA 4.5 미달. 비게임 화면 본문 글자 13px 138회·12px 119회·11px 47회, textScale 대응 0건.
11. 디버그 정보가 일반 사용자에게 노출: 하드코딩 v1.0.4, Ping 테스트·접속자·사용자 ID·방 코드, 개발자 정보 카드, 탈퇴 실패 시 ($error).
12. 파트너 화면: 공유 시트·딥링크 없음, 3초 폴링, 닉네임 수정이 생일을 2000-01-01로 덮어쓸 수 있음, 6블록이 한 화면에 있어 위계 약함.
13. 로그인: 비밀번호 .trim(), 약관 링크 없음, 동작 없는 장식 점 3개가 페이저처럼 보임.
14. 설정이 ApiClient 대신 http.get/patch 직접 호출 → 401 처리·타임아웃 우회, 실패 무음.
15. 알림 설정: 항목 3개뿐, OS 권한 상태 표시 없음, 로드 실패 재시도 없음, 스위치/ListTile 스타일 혼재.
하
16. AlertDialog 28곳·바텀시트 23곳·스낵바 50곳·로딩 59곳·AppBar 37곳 직접 구현. 17. 헤더 3종(MainHero/MainTabHeader/자체 AppBar). 18. 카피 톤 "~해요"/"~합니다" 혼용, "애인"/"상대방" 혼용. 19. 폰트 런타임 다운로드(오프라인 첫 실행 시 흔들림, 확인 필요). 20. 매니페스트에 CAMERA/RECORD_AUDIO가 있으나 사용 흔적 0건(Play 심사 위험).

## 4. 공용 토큰·컴포넌트(현재)
색(core/main_design.dart): Bg #FFFBFD, Paper #FFF, PaperSoft #FFF5F8, Line #F3DCE6, Ink #1E1E2E, Sub #5A5A78, Muted #ABABBC. 액센트: Rose #FF6F9F, Sage #55BF8A, Sky #55A9DE, Honey #FFBE32, Peach #FF9670, Lilac #9D83FF. 상태: Success #2EB872, Error #E53935. 중복: app_theme.dart 레거시 별칭, kMainCream #FFF2F6, auth* 8색, kHeroRoseGrad. 하드코딩 Color(0x…): archive 32, date_roulette 30, relationship 8, auth 8, secret_base 6, shop 4; Colors.white 210회.
타입: mainTitle=Gaegu 28, mainBody=Noto Sans 13, 스케일 정의 없음(실사용 title 22/20/24/26/28, body 13/12/14/11/15), AppBar 타이틀 Noto Sans 17이 Gaegu와 충돌.
반경: 12(44회) 16(37) 20(28) 14(26) 18(23) 99(20) 8(16) 10(15) 4(14), 토큰 없음. 간격 토큰 없음(16/18/20/24 혼재). 그림자는 MainCard 하나.
하단 탭 충돌: app_theme.dart는 선택=Ink·elevation 0, home_shell.dart:170-195는 선택=Rose·elevation 8로 재정의.
컴포넌트: CozyPage, MainCard, IconBadge(=DoodleBadge), BrandLogo, CozyMascot, MainHero, HeroMascot, MainTabHeader, Auth* 6종, HeartOverlay, GoogleSignInButton. 중복 구현: _Card/_InfoRow(settings·premium), _ErrorState(moment_loop만). 공용 빈 상태 위젯 없음. Primary 버튼 높이 50/52/56, 입력 스타일 4종.

## 5. 2.0 제안
- IA: 탭 라벨 한글 통일(기록/지도/놀이/더보기), 화면 제목과 일치. 더보기의 탭 바로가기 3개 제거 → "우리 이야기" 허브(기념일·관계 이해·상점·보관함). 더보기를 프로필·커플 / 서비스 / 앱 설정 / 계정(위험 구역) 4구역으로 재편, 디버그 카드 숨김. MySpaceScreen을 3개 서브 화면으로 분리. IndexedStack+PopScope.
- 인증: 로컬 세션으로 먼저 runApp, 프로필 갱신은 백그라운드. 로그인: Google Primary·이메일 보조, 약관 링크 상시, 장식 점은 제거하거나 3장 온보딩으로. 가입: 전체 동의+개별 동의(14세 이상), 비번 규칙 인라인, 서버 오류 코드별 문구, 가입 후 자동 로그인. Google 신규도 동의·생일·닉네임 필수. 비밀번호 재설정(앱+서버) 신규.
- 파트너 연결: 3단 스텝(공유→입력→축하), 공유 시트·딥링크. 오버플로 메뉴에 로그아웃·탈퇴·고객센터. 연결 전 둘러보기는 제품 결정 필요.
- 권한: 푸시는 페어링 완료 화면의 사전 안내 카드→OS 요청, 거부 시 설정 이동 배너. 위치는 "내 위치" 버튼에서 용도 시트 후 요청.
- 디자인 시스템: 별칭/중복 정리, Muted·Rose 대비 보강, 타입 6단계, 반경 4단계+pill, 4pt 간격, 본문 최소 12px. 컴포넌트: AppScaffold, SettingsRow, AppButton, AppTextField, AppDialog.confirm, AppSheet, AppSnack, EmptyState, ErrorState, Skeleton, PermissionRationaleCard, StatusBanner, Avatar, ConsentRow. 게임 GameTheme/Mod*는 유지, 비게임은 main_design으로 단일화.
- 빠진 화면: 온보딩, 비번 찾기, Google 동의, 연결 성공/실패, 권한 사전 안내·거부 후 안내, 오프라인/서버 오류, 점검·강제 업데이트(서버 지원 확인 필요), 계정 보안, 탈퇴 후 안내, FAQ.

## 6. 목업 대상
P0: 로그인(기본/시트 입력 중/오류/로딩/약관 링크), 가입 1~2단계+동의(오류/로딩/자동 로그인), Google 신규 프로필/동의, 비밀번호 재설정(입력/발송/오류), 파트너 연결 스텝형(코드 공유/입력/대기/받은 요청/만료/오류/성공/오버플로 메뉴), 권한 사전 안내(푸시·위치, 거부 후 설정 이동), 연결 로딩(실패/오프라인), 하단 탭 셸(오프라인 배너), 더보기 허브(로딩/푸시 미허용 배너), 계정(프로필 편집/로그아웃 확인/탈퇴 3단/소셜 탈퇴/실패), 알림 설정(로딩/실패+재시도/OS 꺼짐 안내).
P1: 연결·기념일 관리(해제 확인), 온보딩 3장, 고객센터/FAQ, 공용 컴포넌트 카탈로그.
P2: 계정 보안, 점검/강제 업데이트, 숨김 진단 화면.
확인 필요: Google 신규 가입 생일 2000-01-01 보정 시점, CAMERA/RECORD_AUDIO 필요성, textScale 1.3+에서 하단 탭·설정 행 넘침, 서버의 동의 이력·비번 재설정·만 14세 정책(검색상 없음), RESEARCH_2026-10_LAUNCH_READINESS.md가 푸시를 "없음"으로 적었으나 현재 코드엔 구현 있음.
