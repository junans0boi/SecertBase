# 분석: 더보기/보관함 계열 (archive/*, MomentLoop·비밀지도 제외)
(lib = apps/secret_base_app/lib, srv = services/realtime-server/src)

## 0. 핵심 발견
1. **보관함 허브는 사실상 없다.** `ArchiveScreen`은 어디에도 연결되지 않음(home_shell.dart:74-78이 탭을 직접 연결). 항목 2개(MomentLoop, 비밀 지도)뿐이고 둘 다 이미 하단 탭.
2. **archive/* 약 5,600줄이 도달 불가·출시 불가**: album, capsule, shelter, qa, balance, challenge, wish_ticket, jukebox, timeline, monthly_report, premium, heart_exchange, vault + date_roulette. 어디서도 이동하지 않고, 서버는 기본 `PUBLIC_FEATURE_SET=mvp`에서 403 `FEATURE_DISABLED`(srv/shared/feature-registry.js:1-16), 클라이언트는 Authorization 헤더 없이 `user_id`를 쿼리/본문으로 보냄(서버는 JWT 요구). `MVP_DEFINITION.md:143`에서 범위 밖.
3. **출시 1.0의 실제 "기록" 기능**: 개인 보관함(미연결 상태 전용), 여운(Afterglow, 지도 핀 상세 안), MomentLoop/지도(다른 영역). → 2.0은 새 허브를 만들지 말고 죽은 코드 정리 + 이 기능들 다듬기.
4. `docs/FEATURE_MATRIX.md` §2·§5는 낡음("라우팅만, 1~2시간, P0")—실제로는 서버 게이트 해제 + 인증 래퍼 + 서버 IDOR 수정이 필요.

## 1. 인벤토리
| 화면 | 목적 | 진입 | 상태 |
|---|---|---|---|
| personal_history_screen (210줄) | 미연결 사용자의 MomentLoop·핀 보기, 삭제, ZIP 내보내기 | partner_screen.dart:222-237 버튼 1개 | live(미연결 전용) |
| afterglow_section (224)+afterglow_api | "우리의 여운": 같은 날 두 사람의 장면 | 지도 핀 상세(map_screen.dart:1471-1490), "오늘 다녀왔어요"(:1749) | live(베타 성격) |
| archive_screen/heart_exchange/vault | 허브 | 없음 | 죽음 |
| qa, balance, wish_ticket, challenge, timeline, monthly_report, jukebox, album, capsule, shelter | 레거시 | 없음 | 서버 403 |
| premium_screen (762) | 구독 ₩1,900/월·₩19,000/년 | album에서만 | 비활성(Play 결제 미연동) |
| date_roulette_screen | 클라이언트 전용 룰렛 | 참조 0 | 죽음 |
실제 더보기(settings_screen.dart:136-210): "우리의 공간"(MomentLoop·비밀 지도·함께 놀기 — 탭 전환뿐이라 하단 탭과 중복), "기록과 이해"(우리의 비밀기지·관계 이해), 알림 설정.

## 2. 흐름
1. 미연결 사용자의 기록: 로그인→파트너 화면→맨 아래 "개인 보관함 열기" (설명 없음).
2. 여운: 지도→핀→다녀왔어요→글 선택→한 장 남기기 (5탭). 오늘 연결된 MomentLoop가 없으면 막다른 길("나중에 남겨도 괜찮아요"), 돌아가려면 8~9탭.
3. 재방문: 홈의 "n년 전 오늘" 카드가 유일한 회상 진입점.

## 3. 문제점
구조/출시 차단(상): 죽은 코드 5,600줄(APK·테스트·오해), 레거시 화면은 게이트를 풀어도 동작 불가(인증 헤더 없음, `user_id` 클라이언트 전달), 서버 IDOR(레거시 라우트가 클라이언트가 보낸 user_id를 신뢰), 문서 충돌.
라이브 화면:
- (상) 개인 보관함 삭제가 즉시 영구 삭제(미디어 포함)인데 확인이 없고 실패도 조용함; 내보내기 피드백 없음.
- (중) 개인 보관함 버튼이 연결 상태에서도 항상 보임 → 서버 409를 "불러오지 못했어요" 오류로 표시.
- (중) 본문이 ListTile/Text 수준, 빈 상태 한 줄, 썸네일 없음, 기본 제목 "사진으로 남긴 순간".
- (중) 여운: 날짜 매칭이 startsWith라 UTC/로컬 불일치 위험, 섹션 제목이 영어("Date Afterglow") vs 내용 "우리의 여운", 로드 실패가 조용히 숨겨짐(상대 미작성과 구분 안 됨).
- (중) "기록" 명칭 불일치(우리의 기록·개인 보관함·우리의 비밀기지·기록과 이해), 소원권/소원 쿠폰/데이트 쿠폰 중복.
- (하) 접근성: Image.network에 errorBuilder/semanticLabel 없음, 영상 탭 Semantics 없음, 컴포넌트 불일치(이모지 vs 머티리얼 아이콘, premium은 하드코딩 색 + 👑).
프리미엄(고위험): 도달 불가, "현재 데모 모드입니다" 문구, 서버가 운영에서 활성화를 거부, 유일한 혜택(앨범 한도)도 앨범이 꺼져 있어 의미 없음, Play는 디지털 구독에 Play Billing 필수 → **1.0에서는 프리미엄 UI·카피 노출 금지**.

## 4. 2.0 제안
판정: MomentLoop·지도 출시(타 영역), 여운 출시+강화, 개인 보관함 출시+강화, ArchiveScreen/HeartExchange/Vault 삭제, Q&A+밸런스 1.0 숨김(1.1에 "오늘의 질문"으로 통합), 소원권 숨김(상점 쿠폰과 통합 먼저), 타임캡슐 숨김(추후 유력), 타임라인 숨김(MomentLoop 달력/리뷰로 흡수), 월간 리포트 숨김(월간 엽서와 통합), 챌린지 숨김, 앨범 숨김/삭제, 쉼터 숨김, 주크박스 삭제 권장(UGC·저작권), 프리미엄 제거/숨김, 데이트 룰렛 보류(홈 빠른 실행에 재노출 가능).
IA: 하단 5탭 유지. "보관함" 허브 신설 금지. 더보기에서 탭 중복 "우리의 공간" 제거 → "우리의 기록"(우리의 비밀기지, 개인 보관함(미연결 시), 기념일). 개인 보관함 진입을 파트너 대기 화면의 명시적 카드로 승격.
화면별:
- 개인 보관함: 상단 안내(누가 볼 수 있나·연결 시 어떻게 되나·내보내기), 썸네일 카드, 파괴적 삭제 확인 시트("사진/클립 파일까지 지워져요 · 되돌릴 수 없어요")+성공/실패 스낵바, 내보내기 진행·완료·실패, 첫 기록 CTA가 있는 빈 상태, 409는 정책 안내로.
- 여운: 이름 "우리의 여운" 통일, 후보 없을 때 "지금 MomentLoop 남기기" CTA(장소·날짜 미리 채움), 상대 상태 3종(아직/삭제/로드 실패+재시도), 방문 전 힌트, 이미지 대체 텍스트/오류 플레이스홀더.
- 빠진 화면: 보관함 빈/오류/삭제 확인, 내보내기 성공(저장 위치), 연결 해제 후 "내 기록은 어디로" 안내.
- 컴포넌트: ConfirmDestructiveSheet, EmptyState, LoadErrorCard(재시도/정책), SectionHeader+Badge, MemoryTile, PartnerSceneCard.
사전 작업(디자인 외): 레거시 화면·테스트 정리(lib/legacy 이동 또는 삭제), FEATURE_MATRIX·PRODUCT_SPEC 문구 정정, 출시 체크리스트에 `PUBLIC_FEATURE_SET=mvp`·`ALLOW_DEMO_PREMIUM` 해제 추가, 레거시 부활 전 인증 http 래퍼+서버 `req.auth.userId` 전환.

## 5. 목업 대상
P0: 개인 보관함(기본/로딩/빈 상태+CTA/오류+재시도/연결 후 접근 안내/삭제 확인/삭제 완료·실패/내보내기 진행·완료·실패), 핀 상세의 여운 섹션(방문 전 힌트/나만 작성/둘 다/상대 삭제/로드 실패/미디어 오류), 여운 남기기 시트(후보 선택·메모·감정 태그/후보 없음 CTA/저장 중·성공·실패), 더보기 "우리의 기록" 재구성(연결/미연결 변형).
P1: 파트너 대기 화면의 개인 보관함 카드(기록 있음/없음), 공용 시트 모음(삭제 확인·빈·오류).
P2: "오늘의 질문"(Q&A+밸런스, 1.1), 소원권+상점 쿠폰 통합·타임캡슐 콘셉트.
제외: 프리미엄, 앨범, 주크박스, 챌린지(1.0 아님).
확인 필요: 미연결 사용자가 MomentLoop/지도 기록을 만들 수 있는지, 여운 상대 알림 여부, `moment['id']` 타입, 여운 날짜 타임존 처리, 상점 미션/쿠폰의 `/missions` 게이트.
