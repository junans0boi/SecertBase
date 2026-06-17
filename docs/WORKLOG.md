# WORKLOG

## 2026-06-17 (오후)

### 완료 항목

1. **프로젝트 초기화**
   - 모노레포 구조 생성 (`apps`, `services`, `docs`)
   - Flutter 앱 생성 (`apps/secret_base_app`)
   - Realtime 서버 생성 (`services/realtime-server`)

2. **기반 기능 구현**
   - Socket.IO 이벤트 기반 MVP 연결 구현
   - 2인 제한 입장 로직 + Redis 상태 저장
   - Flutter 테스트 UI (접속, Ping, 주사위, 룰렛, 로그)

3. **게임 확장**
   - 가위바위보 (Rock-Paper-Scissors) 동시 선택 + 승자 판정
   - 텔레파시 게임 (동시 선택, 일치 여부 확인)
   - 해적 룰렛 (폭탄 슬롯 랜덤 선택)
   - Redis 세션 기반 대기/결과 처리

4. **문서화**
   - README.md (실행 방법/구조)
   - PRODUCT_SPEC.md (기획 요약)
   - ROADMAP.md (Phase별 계획)
   - SOCKET_EVENTS.md (v1 이벤트 명세)
   - WORKLOG.md (작업 로그)

5. **인프라**
   - Redis 로컬 실행 확인
   - 서버 포트 4100 구동 확인
   - health 엔드포인트 테스트
   - Git 초기화 및 첫 커밋

### 기술 스택 현황

- **Backend**: Node.js 25.2.1, Socket.IO 4.8.3, Redis 8.4.0, Express 5.2.1
- **Frontend**: Flutter 3.38.6, Dart 3.10.7, socket_io_client 3.1.6
- **Infrastructure**: macOS (local dev), Redis (homebrew)

### 현재 기준

- **Phase 1 완료**: 실시간 통신 MVP + 5개 게임 동작 가능
- **다음 마일스톤**: 윷놀이/UNO/폭탄돌리기 턴제 게임 상태 머신

### 알려진 이슈

- Flutter 경고: `_rpsChoice`, `_telepathyChoice` 필드가 UI에서 미사용 (표시 추가 필요)
- Reconnect 후 게임 세션 복구 로직 미구현 (Phase 2 대상)
