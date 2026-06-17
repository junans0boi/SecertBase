# Secret Base 기획 요약

## 목표

- 오직 두 사람만 접속 가능한 프라이빗 공간
- 술자리 텐션용 실시간 미니게임 + 일상 기록 아카이브

## 핵심 존 구성

1. **아케이드 존**: 윷놀이, UNO, 폭탄 돌리기, 룰렛, 주사위 등
2. **아카이브 존**: 셋로그, 비밀 지도, 10시 Q&A, 목표 챌린지, 주크박스
3. **히든 존**: 기념일 이펙트, 7탭 이스터에그

## 기술 방향

- Frontend: Flutter (Android + Web)
- Realtime Backend: Node.js + Socket.IO
- 세션/상태 캐시: Redis
- 영구 저장소: PostgreSQL 또는 MongoDB (Phase 3에서 확정)
- 인프라: Ubuntu 홈서버
