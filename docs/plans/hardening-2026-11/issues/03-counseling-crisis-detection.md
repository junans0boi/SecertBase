# 03: 상담 위기 감지

**What to build:** 개인·공유 상담에서 위기 신호가 있는 메시지는 AI 답변 없이 안전 안내(도움 기관 연락처)로 응답한다. 위기 키워드는 띄어쓰기 없이도, 흔한 표현까지 감지한다.

**Blocked by:** None (can start immediately)

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/207

- [x] 위기 메시지에서 LLM이 호출되지 않는다
- [x] 응답에 안전 리소스가 포함된다
- [x] '죽고싶어', '자살', '극단적 선택', '뛰어내리' 등이 감지된다
- [x] 일반 메시지는 기존대로 처리된다
- [x] 마음관리의 기존 감지 테스트가 계속 통과한다
