# Wayfinder Map: 하드닝 2026-11

**Label:** `wayfinder:map`

## Destination

게임을 제외한 코드 리뷰에서 확인된 보안·안전·운영 결함 중 "결정 없이 고칠 수 있는 것"을 모두 수정해 `main`에 반영한다. 결정이 더 필요한 항목은 아래 Not yet specified로 남긴다.

## Notes

- 도메인 용어는 `CONTEXT.md`를 따른다. 관련 ADR: 0003(상담은 명시적 공유 인사이트), 0012(AI 마음관리), 0013(안전 위치·리소스 계약).
- 이번 작업은 계획이 아니라 실행까지 포함한다(사용자 지시: 알아서 수정·커밋·푸시 후 보고).
- 로컬에는 node/flutter가 없다. 검증은 서버의 임시 사본에서 한다. 운영 `.env`·DB·PM2는 건드리지 않는다.

## Decisions so far

- [게이트 대소문자 우회 차단](issues/01-gate-case-insensitive.md): 경로를 소문자로 정규화해 비교한다.
- [프리미엄은 검증 없이 활성화하지 않는다](issues/02-premium-activation-disabled.md): 기본 거부, 개발 설정으로만 허용.
- [상담 위기 감지](issues/03-counseling-crisis-detection.md): 상담 경로에서 LLM 호출 전에 감지하고 안전 안내 반환.
- [업로드 하드닝](issues/04-upload-hardening.md): 확장자 화이트리스트와 서빙 헤더.
- [로그인 제한과 보안 헤더](issues/05-auth-rate-limit-and-headers.md): 자체 제한기와 기본 헤더.
- [MomentLoop 삭제는 작성자만](issues/06-moment-delete-author-only.md): 수정은 파트너 허용 유지.
- [탈퇴 계정 토큰 거부](issues/07-deleted-account-token-rejection.md): 짧은 TTL 캐시로 확인.
- [소소한 서버 결함](issues/08-small-backend-fixes.md): 해시 없는 로그인, 로그 마스킹, 푸시 폐기, 쿠폰, 소원권.
- [테스트와 운영 환경 분리](issues/09-test-env-isolation.md): 테스트에서는 `.env`를 읽지 않는다.
- [앱 타임아웃과 401 처리](issues/10-app-timeout-and-401.md)
- [안드로이드 자동 백업 끄기](issues/11-android-backup-off.md)
- [배포 안전장치와 워크플로 정리](issues/12-deploy-safety.md)

## Not yet specified

- 레거시 라우트(capsules, reflections, wish-tickets, album, jukebox, challenges) 처리: 제거할지, 커플 범위로 재작성할지. 제품 결정 필요. (게이트로 막힌 상태 유지)
- 프리미엄 결제: 스토어 영수증/웹훅 검증 방식과 상품 구성.
- 업로드 인증 서빙(서명 URL): 앱의 이미지 로딩 방식 변경이 함께 필요.
- 외부 LLM으로 나가는 상담·출생 정보의 정제와 시스템 프롬프트.
- 앱 토큰 보안 저장소(웹 대응 포함), 로그인 실패 원인 구분, UGC 신고·차단, l10n, 접근성, 이미지 캐시.
- 대형 파일 분리(서버 라우트, 소켓, MomentLoop·지도 화면), 페이지네이션, 전역 에러 미들웨어.
- 운영: CI 게이트, 통합 테스트·E2E 연동, 모니터링·알림, 오프사이트 백업과 백업 스크립트 개편, 의존성 점검, 문서 드리프트.
- 탈퇴 시 정리 대상 테이블 일원화와 지갑 일일 보너스 시간대 검증.

## Out of scope

- 모든 게임 코드와 게임 문서.
