# 08: 소소한 서버 결함

**What to build:** 비밀번호 해시 없는 계정의 비밀번호 로그인은 일반 인증 실패로 응답하고, DB 오류 로그에 파라미터가 남지 않으며, 푸시 payload 오류로 토큰이 폐기되지 않고, 쿠폰은 활성 커플의 파트너에게만 발급되며, 소원권은 올바른 상태에서만 전이된다.

**Blocked by:** None (can start immediately)

**Status:** done (closed) - https://github.com/junans0boi/SecertBase/issues/209

- [x] 구글 가입 계정의 비밀번호 로그인이 500 대신 401이다
- [x] DB 에러 로그에 params가 없다
- [x] invalid-argument로 토큰이 폐기되지 않는다
- [x] 비활성 커플의 파트너는 쿠폰 대상이 아니다
- [x] used/canceled 소원권은 재사용·취소되지 않는다
