# 33: 텔레파시 B안 + 맵기 3단계·19+

**Type:** server+client

**Blocked by:** –

**Status:** done (PR #253)

## What to build

텔레파시를 목업 B안(카드 좌우)으로 다시 만들고, 질문 수위를 3단계로 나눈다. 19+는 안전장치(경고·상대 동의·성인 확인)가 있어야 시작된다.

## Acceptance criteria

- [x] 로비 옵션 `telepathy.heat`(mild|spicy|nuclear), 질문 은행 `heat` 분류 + 19+ 질문 `tone`(m|s|both)
- [x] 살짝 매운맛 149개(장소·속옷·스킨십·취향), 19+ 211개(하드한 성인 질문, BDSM 포함), 19+ 판은 하드한 질문만
- [x] 서버 성인 확인(`adult_only`, 가입 생년월일), 로비 경고와 상대 동의, 질문 화면 🔞 표시
- [x] 질문 은행 검증·가드레일 테스트(미성년·가족·비동의·모욕·3자 금지, 하드 질문 최소 개수)
- [x] 중복 없는 출제: 19+ 21판, 살짝 40판
- [x] 두 계정 실제 플레이 확인(경고 → 동의 → 시작 → 질문)

## Likely files
- `services/realtime-server/src/telepathy-engine.js`, `src/games/telepathy.js`, `src/data/telepathy-questions.json`, `src/lobby-options.js`
- `apps/secret_base_app/lib/screens/arcade/games/telepathy/`
