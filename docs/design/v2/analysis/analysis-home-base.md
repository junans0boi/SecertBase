# 분석: 홈과 비밀기지 (app = apps/secret_base_app/lib, srv = services/realtime-server/src)

## 1. 인벤토리
| 화면 | 목적/핵심요소 | 진입 | 서버 |
|---|---|---|---|
| HomeShell (app/screens/home_shell.dart) | 5탭(홈/MomentLoop/지도/놀이/더보기), 오프라인 배너(:145, 15초 HEAD), 푸시 딥링크(:87) | main.dart:197, 로그인→파트너연결→소켓연결 필요 | - |
| HomeScreen (home/home_screen.dart) | 히어로(D+n), 기념일 카드(D-day·파트너·시작일·다음 기념일), 오늘의 루프 카드, "순간 남기기"+"놀이" 버튼, "함께 해볼까요?" 캐러셀 5칸(지도/비밀기지/운세/타로/사주), 관계이해 카드, 추억 카드, pull-to-refresh | 1번 탭 | /couple/info, /retention/memory-card, /relationship/assessments, /retention/today 병렬 |
| TodayCard | 5상태(empty/partnerWaiting/selfWaiting/complete/viewed) 단일 CTA | 홈 | TodayState |
| TodayLoopViewer | 나/상대 순간 세로 카드. StatelessWidget | 카드 CTA, 푸시 today_loop | 홈 상태 재사용 |
| MemoryListScreen | "n년 전 오늘" 목록(항목 탭 동작 없음) | 홈 추억 카드 | /retention/memory-card/list |
| AnniversariesScreen | 기념일 CRUD, 삭제는 길게 누르기뿐 | 홈 기념일 카드 | /anniversaries |
| SecretBaseScreen | 마일스톤 21개 평면 목록+보상 받기, 달성도 바 | 홈 캐러셀 2번째, 더보기>기록과 이해(settings_screen.dart:175) | /retention/secret-base/milestones(+claim) |
| BasePostcardScreen | 월간: 순간·장소 수, 하이라이트 1, 장소 칩 | 비밀기지 앱바 "기지 엽서" | /retention/secret-base/postcard/:y/:m |
| DateRouletteScreen | 하드코딩 20개 아이디어 뽑기 | **어디서도 연결 안 됨**. FEATURE_MATRIX.md:143은 P0 재활성화로 표기 | 없음 |

서버의 /api/today, 오늘의 질문, streak는 홈에서 안 쓰임(RETENTION_FEATURE_PLAN.md:654 Today Hub와 괴리).

## 2. 흐름
1. 첫 사용: 로그인→PartnerScreen→연결 직후 OS 알림 권한 즉시 요청(설명 없음, push_service.dart:111)→소켓 대기("비밀기지로 입장하는 중", main.dart:203, 개발용 문구 `v1.0.4 - status` 노출 :213)→홈. 시작일 없으면 "우리의 첫날을 등록해보세요". 첫 순간까지 최소 3탭.
2. 일상 체크인: 홈 TodayCard "오늘의 순간 남기기"는 MomentLoop 탭 전환만(home_screen.dart:538), 작성기 안 열림. FAB→사진→"오늘의 순간으로 남기기" 스위치를 직접 켜야 반영(moment_loop_screen.dart:3336 기본 false, :3900). 4~5탭. 놓치면 홈이 계속 "남겨볼까요?".
3. 푸시 today_loop→PushTodayRoute→뷰어: 잘 이어짐. 단 markViewed 미호출.
4. D-day: 기념일 카드→AnniversariesScreen에는 시작일 입력이 없음(시작일은 더보기 settings_screen.dart:1319에만).
5. 비밀기지/엽서: 캐러셀 2번째칸(화면 밖) 또는 더보기→3탭 이상.
6. 추억: 카드(그날 기록 있을 때만)→목록, 항목 탭해도 무반응(memory_list_screen.dart:150).

## 3. 문제점
상
1. 오늘의 순간 흐름 끊김(위 2번). home_screen.dart:538, moment_loop_screen.dart:3336.
2. 같은 목적지 CTA 3~4중복: TodayCard CTA, 큰 "순간 남기기", 하단 탭 모두 onNavigate(1) (home_screen.dart:345/538). 놀이·비밀지도 칸도 탭과 중복. 기획은 "Home CTA 하나"(2026_COUPLE_APP_RETENTION_RESEARCH.md:288).
3. dDay null이면 미설정·조회 실패 구분 없이 "첫날 등록해보세요"(home_screen.dart:276), 탭하면 시작일 입력 없는 화면(:269).
4. 푸시 권한 맥락 없이 1회 요청, 거절 후 안내 없음, 홈에 알림 진입점 없음. 출시 심사 위험.
중
5. viewed 상태 도달 불가: markViewed 호출처 없음(today_api.dart:188만), 뷰어 Stateless. today_card.dart:55 죽은 코드.
6. 루프 공개 연출·후속 행동(반응/공유/지도) 없음, TodayCard에 실제 썸네일 없음(today_card.dart:76).
7. 상태 처리: 탭 전환 시 홈 재생성 추정(home_shell.dart:166, 확인 필요), 전체 실패 화면 없음, 오프라인 배너가 브랜드 장미색(:145), 추억 카드 없을 때 안내 없음.
8. 접근성: kMainMuted #ABABBC 흰 배경 약 2.3:1, 흰 글씨 on kMainRose 약 2.6:1(TodayCard 버튼, 히어로), 10px 칩(today_card.dart:108), 9px 등급(secret_base_screen.dart:642), 보상 Opacity 0.4(:619).
9. 터치: 홈 두 버튼 GestureDetector라 리플 없음(home_screen.dart:344,401), 기념일 삭제 long-press만(anniversaries_screen.dart:209), 받기 버튼 32dp(secret_base_screen.dart:539).
10. 기념일 빈약: 다음 기념일은 repeat_yearly만(srv/routes.js:5676), 100일/1주년은 비밀기지 마일스톤에만(routes.js:3858), 비반복은 D-day null(:5759), 날짜 ISO 원문·오름차순 정렬, 이 화면만 기본 Material(Colors.red/grey), 새로고침 없음.
11. 비밀기지는 보상 목록일 뿐: 21개 고정 순서, 진행도 없음(서버 value 미채움 routes.js:3834), "진행 중" 칩만, 등급 B~SSS·보상 사용처 설명 없음.
하
12. 카피: "활성 커플" 내부 용어 노출(secret_base_screen.dart:141,385; base_postcard_screen.dart:79,294), 합니다체 혼용(:188), "MomentLoop" 영문 탭 vs "순간 남기기", 탭 "놀이" vs 더보기 "함께 놀기", 더보기 헤더 "전체".
13. MemoryList는 오늘 날짜의 과거만, 항목 탭·새로고침 없음, 카드 전체 비탭(home_screen.dart:684).
14. 엽서: 숫자 2개+하이라이트 1, 공유/저장 없음, 로드마다 _postcard=null 깜빡임(base_postcard_screen.dart:46), scope 카드 3상태 반복.
15. 데이트 룰렛 미연결, 이모지 UI, 저장·지도연동 없음.
16. 캐러셀 5칸 중 3칸이 운세/타로/사주, 색 배정 무의미, 약 2.7칸만 노출.

## 4. 2.0 제안
- 홈 = 오늘의 관계 장면 1개 + 다음 D-day. 순서: 히어로(D+n·다음 기념일) → 오늘 카드(상태별 단일 주 CTA) → 상대 상태 한 줄 → 바로가기 → 추억. 큰 "순간 남기기"·"놀이" 카드 삭제.
- 비밀기지 허브 통합: 마일스톤/기념일/월간 엽서 3탭, 홈에 진행도 요약 카드("8/21 · 보상 2개"). 운세·타로·사주는 "오늘의 운세" 1칸으로 묶고 캐러셀 3~4칸, 룰렛은 "오늘 뭐 할까?"로 노출.
- 오늘 카드: CTA가 작성기 직접 오픈+"오늘의 순간" 기본 ON, 완성 시 두 썸네일, selfWaiting에 콕 찌르기. 시작일 미설정은 시작일 바텀시트로 직행, 실패는 별도 카드. 탭 상태 유지, 상단 알림 벨+권한 거절 배너, 오프라인 회색 경고+캐시.
- 뷰어: markViewed 호출, 공개 연출, 반응/댓글/공유/지도 보기.
- 추억: 항목→MomentLoop 상세, 연도 묶음, 새로고침.
- 기념일: 시작일 편집+자동 마일스톤(100/200/1주년) 통합, 다가오는 순 정렬, 비반복도 D-day, 한국식 날짜, 스와이프 삭제+실행취소, main_design 컴포넌트.
- 비밀기지: 진행바(7/10), 받을 수 있는 보상 상단, 그룹(순간/장소/함께한 날), 받기 후 상점/놀이 딥링크, 등급 설명, 해요체 통일, "활성 커플" 제거.
- 엽서: 엽서형 카드+저장/공유, 월 1일 푸시(확인 필요), 로딩 시 이전 데이터 유지.
- 룰렛: 진입점 추가, 지도 위시리스트 저장, 기념일 등록 연동.
- 빠진 화면: 첫 사용 체크리스트(시작일/첫 순간/알림), 푸시 권한 사전 안내 시트, 홈 전체 오류/오프라인, 소켓 연결 실패 안내 개선(개발용 문구 제거), 시작일 설정 시트, 보상 수령 연출, 알림 인박스(선택).
- 컴포넌트: StateCard(빈/오류/로딩), MomentThumb, ScopeBanner, SectionHeader, DdayChip, ProgressRow, AnniversaryRow, ConfirmSheet/UndoSnack.

## 5. 목업 대상
P0: 홈(완성/비어있음/나만 기록/상대만 기록/시작일 미설정/첫 사용 체크리스트/로딩/부분 실패/오프라인/알림 거절 배너), 오늘의 루프 뷰어(공개 연출/사진·텍스트·영상/상대 삭제/대기/실패), 푸시 권한 사전 안내 시트, 비밀기지 허브(그룹·진행도·받을 보상·빈/로딩/오류·수령 모달), 기념일+시작일(다가오는 순/빈/미설정/추가·수정 시트/삭제 취소/오류).
P1: 기지 엽서(카드형+공유/빈 달/로딩/오류), 추억 목록(연도 묶음/빈/오류), 연결 중·소켓 실패 화면, 홈 오프라인/전체 실패.
P2: 데이트 룰렛(기본/필터/지도 저장/결과 없음), 알림 인박스.

## 확인 필요
- 탭 전환 시 홈 재생성 여부(home_shell.dart:166).
- 작성기의 _todayMoment 초기화 경로 전체(moment_loop_screen.dart:3336, 3462).
- 파트너 연결 시 StartDate 자동 설정 여부. 마일스톤은 COALESCE(StartDate, ActivatedAt)(routes.js:3787)라 홈 D-day와 기준일이 다를 수 있음.
- _needsPartner 파트너 안내(home_screen.dart:115)는 main.dart:191 게이트 때문에 사실상 도달 불가로 보임.
- 엽서 월간 푸시 존재 여부.
