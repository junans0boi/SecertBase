# 07: 탈퇴 계정 토큰 거부

**What to build:** 탈퇴한 계정의 토큰은 만료 전이라도 인증 단계에서 거부된다. DB 확인 오류는 요청을 막지 않는다.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] 탈퇴(IsDeleted) 계정은 401 또는 403을 받는다
- [ ] 활성 계정은 영향받지 않는다
- [ ] 확인 결과는 짧은 시간 캐시되고 탈퇴 시 무효화된다
- [ ] DB 오류는 fail-open이며 로그에 남는다
