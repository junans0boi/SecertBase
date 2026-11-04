# 05: 로그인 제한과 보안 헤더

**What to build:** 로그인·가입·구글 인증에 시도 횟수 제한(429, Retry-After)이 걸리고, 모든 응답에 기본 보안 헤더가 붙는다.

**Blocked by:** None (can start immediately)

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/206

- [x] 한도 초과 시 429와 Retry-After를 반환한다
- [x] 한도는 윈도우가 지나면 풀린다
- [x] 정상 사용 흐름은 영향받지 않는다
- [x] 응답에 nosniff, frame 차단, referrer 정책 헤더가 있다
