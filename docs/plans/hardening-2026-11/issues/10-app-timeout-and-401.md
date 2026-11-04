# 10: 앱 타임아웃과 401 처리

**What to build:** 앱의 API 호출은 시간 초과 시 명확한 오류를 내고, 인증된 호출이 401이면 로그아웃되어 로그인 화면으로 돌아간다.

**Blocked by:** None (can start immediately)

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/212

- [x] 타임아웃이 ApiException(timeout)으로 보고된다
- [x] 토큰을 보낸 요청의 401만 로그아웃 콜백을 부른다
- [x] 로그인·가입의 401(잘못된 자격)은 로그아웃을 일으키지 않는다
- [x] format, analyze, test가 통과한다
