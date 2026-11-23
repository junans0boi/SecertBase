# 01 마주 열기 (둘이 함께 여는 오늘의 질문)

용어: Couple, 활성 커플, 홈, 오늘의 루프. 표면 이름은 "마주 열기".

## What to build
새 서버 모듈 `services/realtime-server/src/modules/two-answers/`와 앱 `lib/features/two_answers/`. 레거시 `/qa`는 건드리지 않고 게이트 유지.

- 서버(모두 JWT에서 사용자·활성 Couple 도출, `getAuthenticatedActor` 사용, 비활성 Couple 거부):
  - `GET /api/two-answers/today`: 오늘(`business-date.js` 기준) Couple의 질문, 내 답변 여부, 상대 답변 여부. **둘 다 답하기 전에는 상대 답변 본문을 절대 반환하지 않는다**(응답·소켓·푸시 모두).
  - `PUT /api/two-answers/today/answer`: 내 답변 저장/수정(공개 전까지만 수정 가능, 길이 상한 500자).
  - `GET /api/two-answers/history?cursor=`: 둘 다 답한 지난 질문 카드 목록(커서 페이지네이션).
  - `POST /api/two-answers/:id/answer-late`: 놓친 과거 질문에 나중에 답하기(벌점 없음).
  - 질문 선택: Couple별 결정적 선택(같은 날 둘이 같은 질문). 카테고리 5개(일상·추억·장소·미래·가벼운 놀이)에서 로테이션하며 최근 60일 중복 금지. 장소·기념일 참조형 템플릿은 Couple의 지도 핀/기념일이 있을 때만 선택하고 **정확한 위치·좌표를 질문 문구에 넣지 않는다**(핀 제목 수준).
  - 질문 은행은 직접 작성한 JSON(`src/data/two-answers-questions.json`), 카테고리당 40문항 이상. 외부 서비스 문구 복사 금지.
  - 마이그레이션 `0051_two_answers.sql`(테이블에 `couple_id` 필수, 인덱스 `(couple_id, business_date)` 유니크).
  - 스트릭: 둘 다 답한 날 연속 수. 끊김 시 문구 없이 0으로 표시, 벌점·상실 연출 금지.
- 앱: 홈에 "마주 열기" 카드(상태: 내 차례/상대 기다리는 중/열림), 답변 화면, 둘 다 답했을 때 봉인이 풀리는 짧은 연출(기존 `v2` 디자인 토큰 사용), 히스토리 카드 목록, 카드를 MomentLoop 기록으로 남기기 선택.
- `PUBLIC_FEATURE_SET=mvp`에서도 `/api/two-answers`는 허용되어야 한다(`feature-registry.js`는 신규 경로를 막지 않음을 테스트로 확인).

## Acceptance
- [ ] 서버 통합 테스트: 한쪽만 답했을 때 상대 답변 본문 미노출, 둘 다 답하면 노출, 다른 Couple 접근 거부, 비활성 Couple 거부, 클라이언트 `user_id` 불일치 거부, 늦게 답하기, 중복 질문 방지.
- [ ] 앱 위젯 테스트: 카드 3상태, 답변 제출, 공개 연출 후 상대 답변 표시.
- [ ] `npm test`, `flutter analyze`, `flutter test` 통과.
- [ ] CONTEXT.md에 용어 추가: **마주 열기**.

## Blocked by
없음
