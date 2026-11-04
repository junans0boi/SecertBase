# 04: 업로드 하드닝

**What to build:** 허용된 이미지·영상 형식만 저장되고, 서빙되는 업로드 파일은 브라우저가 스크립트로 실행하지 못한다.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] 허용 목록 밖 MIME은 거부된다
- [ ] 저장 파일의 확장자는 화이트리스트에서만 정해진다
- [ ] 서빙 응답에 nosniff와 샌드박스 CSP가 붙는다
- [ ] 기존 정상 업로드(jpeg, png, webp, mp4 등)는 계속 동작한다
