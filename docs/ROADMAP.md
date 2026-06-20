# Secret Base 로드맵

## 2026-06-20 현재 상태

- Phase 0~2의 핵심 기반은 대부분 구현되어 있다.
- Phase 3 아카이빙 API는 MariaDB 기반으로 구현되어 있으며, 화면도 일부 연결되어 있다.
- Phase 5 웹 배포는 HTTPS/nginx/PM2 기준으로 운영 중이다.
- Android APK/스토어 배포와 장기 운영 자동화는 남아 있다.

## Phase 0 (Week 1) - 환경/통신 기반

- [x] Node.js + Socket.IO + Redis 연결
- [x] Flutter Web/Android 프로젝트 생성
- [x] 기본 소켓 연결 검증

## Phase 1 (Week 2) - MVP 실시간 동기화

- [x] 2인 Room 생성/입장
- [x] 로그인/파트너 연결 기반 자동 방 접속
- [x] Ping/Pong 지연 측정
- [x] 주사위/룰렛 동기화
- [~] 재접속 처리 안정화

## Phase 2 (Week 3~4) - 코어 게임

- [x] 윷놀이/UNO/폭탄 돌리기 턴 상태 머신
- [x] 게임별 대기방/방장 시작 흐름
- [x] UNO 클래식/고와일드 모드 분리
- [x] UNO 선물형 리액션
- [~] 애니메이션/물리 처리
- [~] 승패/벌칙 규칙 엔진

## Phase 3 (Week 5~6) - 아카이빙

- [x] MariaDB 스키마 및 자동 테이블 보강
- [x] 셋로그/지도/Q&A API
- [x] 챌린지/주크박스/타임캡슐 API
- [~] 사진/영상 업로드 UX 및 최적화

## Phase 4 (Week 7) - 폴리싱

- [~] 주크박스
- [ ] Haptic
- [ ] 이스터에그
- [~] UX 디테일

## Phase 5 (Week 8) - 배포

- [ ] Android APK 배포
- [x] Web 빌드 + nginx 배포
- [x] HTTPS 적용
- [x] PM2 프로세스 관리
