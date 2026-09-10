# Current Handoff — 2026-09-10

Secret Base의 현재 제품 언어는 [CONTEXT.md](./CONTEXT.md), 실행 구조와 운영 환경은 [docs/PROJECT_OVERVIEW.md](./docs/PROJECT_OVERVIEW.md)를 기준으로 한다. 어제의 UI·계정 정리와 배포 세부사항은 [HANDOFF_2026-09-09.md](./docs/handoff/HANDOFF_2026-09-09.md)에 기록했다.

## 현재 상태

- 운영 주소: `https://secretbase.cloud`
- 호환 별칭: `https://secertbase.kro.kr`
- 메인 탭: `홈`, `MomentLoop`, `지도`, `놀이`, `더보기`
- 더보기 화면 제목: `전체`
- 더보기 상세 화면에서도 하단 내비게이션 유지
- 내 공간에서 프로필·출생 정보·커플 연결·기념일·이모지·접속 상태·로그아웃·탈퇴 관리
- 운영 서버 커밋: `c10d6ff`
- PM2 서비스: `secretbase-realtime` online

## 현재 주의사항

- 기념일 저장은 인증된 활성 Couple의 시작일을 갱신해야 한다. 클라이언트 사용자 ID를 저장 요청의 기준으로 추가하지 않는다.
- `secretbase.cloud`를 운영·로그인·소켓의 기본 도메인으로 사용한다. 기존 `secertbase.kro.kr`는 호환 목적이다.
- 서버 비밀값이 포함된 `services/realtime-server/.env`와 SSH 키는 커밋하지 않는다.
- GitHub CI는 `yut_board_5_step_rail.png` golden 비교에서 0.75% 픽셀 차이로 실패 중이다. Production Server 배포는 성공했다.

## 작업 전 읽을 문서

| 작업 | 문서 |
| --- | --- |
| 제품 용어·범위 | `CONTEXT.md` |
| 구조·실행·운영 | `docs/PROJECT_OVERVIEW.md` |
| 인증·커플·기록 MVP | `docs/MVP_DEFINITION.md` |
| 오늘의 순간·오늘의 루프 | `docs/product/RETENTION_MVP_1_SPEC.md`, `docs/product/RETENTION_MVP_1_DECISIONS.md` |
| REST API | `docs/REST_API.md` |
| Socket.IO | `docs/SOCKET_EVENTS.md` |
| 배포 | `docs/deployment/LOCAL_DEV_AND_DEPLOY.md`, `docs/deployment/SERVER_SETUP.md` |
| 최신 세션 인수인계 | `docs/handoff/HANDOFF_2026-09-09.md` |

날짜가 붙은 `docs/handoff/` 문서는 당시 세션의 역사 기록이다. 현재 사실과 충돌하면 이 문서와 `CONTEXT.md`, `docs/PROJECT_OVERVIEW.md`를 우선한다.
