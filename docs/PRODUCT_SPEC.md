# Secret Base 기획 요약

## 목표

- 오직 두 사람만 접속 가능한 프라이빗 공간
- 술자리 텐션용 실시간 미니게임 + 일상 기록 아카이브

## 핵심 존 구성

1. **아케이드 존**: 윷놀이, UNO, 폭탄 돌리기, 룰렛, 주사위 등
2. **아카이브 존**: 셋로그, 비밀 지도, 10시 Q&A, 목표 챌린지, 주크박스
3. **히든 존**: 기념일 이펙트, 7탭 이스터에그

## 현재 기술 방향

- Frontend: Flutter (Web + Android)
- Realtime Backend: Node.js + Express + Socket.IO
- 세션/게임 상태 캐시: Redis
- 영구 저장소: MariaDB
- 파일 저장: 서버 로컬 `uploads/`
- 인프라: Ubuntu 홈서버 + nginx + PM2
- 운영 URL: `https://secertbase.kro.kr`

## 현재 제품 상태

- 로그인/회원가입/파트너 코드 연결이 구현되어 있다.
- 파트너 연결 시 커플 방 `RoomCode`/`RoomSecret`이 생성되고, 앱은 이후 자동으로 Socket.IO 방에 접속한다.
- 아케이드 게임은 공통 대기방을 거쳐 2인 실시간 게임으로 진입한다.
- UNO는 클래식/고와일드 모드 선택 후 각각 별도 로비로 입장한다.
- 아카이브 기능은 Setlog, 지도, Q&A, 챌린지, 주크박스, 타임캡슐 일부가 REST API와 연결되어 있다.

## 리텐션 방향

- 앱의 다음 제품 목표는 기능 모음이 아니라 매일 다시 들어오는 커플 루프를 만드는 것이다.
- 상세 계획은 `docs/RETENTION_FEATURE_PLAN.md`에 정리한다.
