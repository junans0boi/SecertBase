# 비밀기지 2.0 (게임 탭 제외) — 기획·목업 공통 지침

사용자 요청: "게임 탭을 제외한 모든 기능(로그인, 홈, MomentLoop, 비밀지도, 타로, 사주 등)의 2.0을 만든다. 지금 디자인도 나쁘진 않지만 곧 출시이므로 **완전하고 사용하기 편한 완벽한 UI/UX**. 분석해서 알아서 계획하고, **HTML 목업으로 보여 주면 내가 승인한다.**" → 이번 산출물은 **목업 HTML뿐**이다(승인 전 구현·레포 수정 금지).

## 1. 분석 근거(반드시 읽을 것) — 모두 `/private/tmp/claude-501/-Volumes-WorkSpace-Project-SecertBase/e4e4382d-28d0-45a7-b913-368ee40f3c55/scratchpad/v2/`
- `analysis-auth-nav-settings.md` · `analysis-home-base.md` · `analysis-momentloop-map.md` · `analysis-archive.md` · `analysis-relationship-shop.md`
각 문서의 "문제점·2.0 제안·목업 대상(P0/P1/P2)"이 곧 너의 작업 목록이다. 근거 코드는 `/Volumes/WorkSpace/Project/SecertBase/.claude/worktrees/games-v2-r4-settings/apps/secret_base_app/lib/`(읽기 전용, 현재 화면의 실제 요소·문구 확인용).

## 2. 확정한 2.0 원칙
**제품 톤**: 커플이 둘만의 기록을 쌓는 따뜻하고 차분한 앱. 장식보다 명료함. 한 화면에 주 행동은 하나. 해요체 통일("~해요"), "연인/상대" 대신 **상대의 이름(예: 서윤)** 또는 "우리"를 우선, 영어 UI 문구 금지(MomentLoop → "기록"). 내부 용어("활성 커플", user_code, 해시) 노출 금지.
**정보 구조(하단 탭 5개, 한글, 선택 = 장미색 인디케이터)**: **홈 · 기록 · 지도 · 놀이 · 더보기**. (놀이 탭은 이번 범위 밖 — 목업에서는 탭만 보인다.)
- 홈: 히어로(D+n·다음 기념일) → **오늘 카드(상태별 단일 주 CTA, 눌러서 작성기 직접 열기)** → 상대 상태 한 줄 → 바로가기(최대 4칸: 오늘의 운세, 우리 이해, 기념일, 비밀기지) → "n년 전 오늘". 큰 중복 CTA(순간 남기기·놀이 카드) 삭제. 상단 알림 벨.
- 기록(구 MomentLoop): 상단 "오늘" 카드 고정, 피드 = 오늘/이번 주/지난 기록, 작성기는 촬영·갤러리·글만 3액션, "오늘의 순간" 기본 ON, 영상 10초 클라이언트 검사.
- 지도(구 비밀지도): 검색+내 위치, 상태 칩 한 줄, 미니 시트로 장소 추가, 상세 3섹션, "한마디"(리뷰·가짜 하트·댓글 제거), "우리의 여운".
- 더보기 4구역: ①프로필·커플 ②**우리 이야기**(기념일, 비밀기지, 우리 이해, 상점, 개인 보관함[미연결 시]) ③앱 설정(알림, 개인정보·권한) ④도움말·약관·앱 정보(2.0.0)·계정(로그아웃/탈퇴는 위험 구역). 탭과 중복되는 바로가기·디버그 정보(Ping·접속자·방 코드) 제거.
- 우리 이해(마음·운세): 오늘(운세 한 줄+타로 한 장, 연결 시 "나/우리" 토글) · 알아가기(사주·심리검사·궁합) · 돌봄(마음관리·상담, 항상 "도움이 필요하면" 칩). 마음관리·상담은 입장 시 1회 동의 시트(AI 가이드·의료 아님·비공유·112/119/109), 위기 시 앱 내장 연락처(탭하면 전화/복사).
- 1.0에서 **숨김/삭제**: 앨범·캡슐·쉼터·Q&A·밸런스·소원권·챌린지·주크박스·타임라인·월간 리포트·프리미엄(분석 §archive). 목업에 나오지 않는다.
**진입·권한**: 온보딩 3장 → 로그인(Google 우선, 이메일 보조, 약관 링크 상시) → 가입(전체/개별 동의+만 14세) → 파트너 연결 스텝(공유→입력→축하) → 푸시 사전 안내 → 홈. 위치·카메라·알림 권한은 **사용하는 순간** 용도 시트 후 요청, 거부 시 설정 이동 안내. 비밀번호 재설정 신규. 연결 전에도 로그아웃·탈퇴·고객센터·약관 접근.
**상태 완전성**: 모든 화면에 가능한 한 빈 상태·로딩(스켈레톤)·오류(+재시도)·오프라인·미연결·권한 거부 상태를 포함한다.

## 3. 디자인 시스템(공용 CSS `ds.css`, 쉘에 이미 포함됨)
- 토큰: 중립(--bg #FFFBFD, --surface, --soft, --line, --ink #1E1E2E, --sub #4C4C68, --muted #6B6B84), 장미 --rose #FF6F9F(장식)/--rose-600 #D63B73(버튼·글자, 흰 글자 대비 4.5+)/--rose-soft, 보조 sage/sky/honey/lilac/peach(+soft), 상태 ok/warn/err(+soft). 반경 12/20/28/pill, 그림자 2종, 4pt 간격. 다크 변형 `.screen.app.dark`(마음관리·사진 감상 등 필요 시).
- 타입 6단계(Noto Sans KR): t-display 28/34, t-title 22/28, t-head 18/24, t-body 15/22, t-cap 13/18, t-label 12/16. 감성 숫자·제목(D+, 결과 제목)에만 세리프 `serif`(Gowun Batang) 사용. **본문 최소 13px(캡션)·12px(라벨), 터치 영역 44px 이상.** 회색 글씨는 --sub/--muted만(AA 대비).
- 컴포넌트 클래스: `.hdr .ttl .ib`(상단 바·아이콘 버튼), `.btn(.soft/.ghost/.text/.danger/.sm/.off)`, `.card(.flat/.soft)`, `.list .li .ic .tx .chev`, `.sec`, `.chip(.on/.rose/.ok/.warn/.err/.sky/.lilac/.sage)`, `.badge .bar .avatar(.b/.sm/.lg)`, `.field .inp(.focus/.err) .help`, `.toggle(.on) .seg .check(.on)`, `.tabbar .tb(.on)`, `.scrim .sheet .dialog .banner(.warn/.err/.info/.ok) .snack`, `.state(.art)`, `.skel`. 필요한 보조 스타일은 자기 탭 CSS에서 `#g-<id>` 아래로만 추가(공용 클래스 재정의 금지).
- 아이콘: 인라인 SVG(24px, stroke 1.8, round cap, currentColor — Lucide 스타일). 이모지는 콘텐츠(감정·반응)에만, UI 아이콘으로 쓰지 않는다.
- 사진 자리: 외부 이미지 금지. 그라데이션 `.ph-img`·CSS/SVG 일러스트로 대체(따뜻한 파스텔, 사람 얼굴 사진 흉내 금지, 실루엣·사물 일러스트 OK).
- 샘플 데이터: 나=민지, 상대=서윤(또는 주제에 맞게), D+412 같은 자연스러운 한국어 값. 가짜 실존 브랜드·실명 금지.

## 4. 산출물 형식(영역마다 파일 하나)
`/private/tmp/claude-501/-Volumes-WorkSpace-Project-SecertBase/e4e4382d-28d0-45a7-b913-368ee40f3c55/scratchpad/v2m/tabs/<tab-id>.html`
```html
<section class="game" id="g-<id>" data-title="탭 이름" data-dot="#색">
  <div class="stage">
    <div class="phone-col"><div class="phone">
      <div class="screen app" data-label="화면 이름"> … 390×800 안에서 absolute 레이아웃 … </div>
      <div class="screen app" data-label="…"> … </div>
    </div></div>
    <aside class="notes"> 설명 </aside>
    <style>/* #g-<id> 아래로 스코프 */</style>
  </div>
</section>
```
- 화면은 390×800 기준. 상단 52px(`.safe`)는 노치 영역, 탭 화면은 `.tabbar`(하단 84px, 5탭 한글, 해당 탭 `.on`)를 포함하고 콘텐츠는 `.has-tabs`로 비운다. 모달 화면은 `.scrim`+`.sheet/.dialog`. 화면(상태) 수는 영역당 8~16개까지 자유(P0 전부 + 가능한 P1). 쉘이 화면 선택 버튼을 만들어 준다(`data-label`이 버튼 이름 — 12자 이내로 짧게).
- `<aside class="notes">`: `<span class="tag">2.0 제안</span><h2>탭 이름</h2>` + `<h3>무엇이 달라지나요</h3>`(현재 대비 3~6 bullet, 분석 문서의 문제 번호/근거 연결) + `<h3>화면 구성</h3>`(상태 목록) + `<h3>승인받고 싶은 결정</h3>`(사용자가 고를 질문 1~3개) + `<h3>구현 때 필요한 서버·정책 작업</h3>`(있으면, 예: 비밀번호 재설정 API, 동의 이력 필드).
- JS 거의 불필요(정적 시안). 외부 이미지 금지, 폰트는 쉘에서 로드됨(Noto Sans KR, Gowun Batang).
- 확인: `/private/tmp/claude-501/-Volumes-WorkSpace-Project-SecertBase/e4e4382d-28d0-45a7-b913-368ee40f3c55/scratchpad/v2m/shot.sh <tab-id> <상태 인덱스(0부터)>` → PNG 경로, Read로 열어 **모든 화면을 직접 눈으로 확인**하고 겹침·잘림·어색함을 고친다. 만들면서 "2025년 출시 앱 품질인가? 대비·간격·위계가 정리돼 있는가? 한 화면 주 행동이 하나인가?"를 가혹하게 자문한다. 사용자가 이전에 "너무 진지하게 안 그려도 돼, 느낌만"이라고 했지만 이번엔 **출시 품질 UI의 승인용 목업**이라 완성도 있게 하되, 과하게 오래 다듬지는 말 것.
- 레포·다른 영역 파일 수정 금지. 브라우저 도구 금지(shot.sh만 사용). 최종 보고 ≤100단어(파일, 화면 수, 승인받을 결정 질문).
