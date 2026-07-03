# 02. [개발] 비밀기지(Secret Base) 구현 과정 및 기술적 해결 기록

> [!NOTE]
> 본 문서는 프로젝트의 전체 개발 여정(마일스톤), 주요 기능의 세부 구현 논리, 직면했던 고난도의 기술적 문제와 해결 사례(트러블슈팅)를 다룬다. 노션(Notion)에 즉시 가져올 수 있도록 구조화되어 있다.

---

## 1. 개발 마일스톤 및 진행 현황 (Milestones)

비밀기지 프로젝트는 총 6단계(Phase 0 ~ Phase 5)에 걸쳐 개발이 진행되었으며, 각 단계의 구현 성과와 세부 사항은 다음과 같다.

### [Phase 0] 인프라 및 개발 환경 구축 (완료)
* **Monorepo 구성**: 클라이언트(apps/secret_base_app)와 실시간 서버(services/realtime-server)를 단일 레포지토리로 묶어 배포 및 유지보수 단일화.
* **환경 변수 유효성 검증**: zod 라이브러리를 이용하여 config.js에서 필수 환경 변수(DATABASE_URL, REDIS_URL, JWT_SECRET 등)의 누락 및 유효 형식을 강력하게 검증.

### [Phase 1] MVP - 실시간 통신 및 동기화 (완료)
* **Socket.IO 통신 구축**: 방 입장 제어, 실시간 핑퐁 레이턴시(Ping/Pong Latency) 측정, 주사위 및 룰렛 등의 가벼운 2인 동기화 이벤트 처리.
* **Presence 시스템**: 사용자 접속 상태를 감지하여 파트너의 온/오프라인 여부를 실시간 홈 화면에 노출.

### [Phase 2] 코어 턴제 게임 개발 (완료)
* **윷놀이 물리 엔진**: 4개 윷가락의 무작위 값 판정(도, 개, 걸, 윷, 모, 백도) 및 보드의 루트 정보 연산, 도착 판정 등을 완전 서버 주도로 구축.
* **UNO 카드 엔진**: 108장의 덱 셔플, 2인 드로우 스택 누적 공격 방어, discard_all 카드 규칙 구현.
* **폭탄 돌리기**: 타이머 엔진과 실시간 랜덤 퀴즈 API 연동.

### [Phase 3] 아카이빙 존 백엔드 및 DB 구축 (완료)
* **MariaDB 테이블 자동 마이그레이션**: 서버 시작 또는 최초 API 진입 시 ensureTables() 함수가 실행되어 필요 테이블을 자동으로 생성하도록 설계.
* **Multer 미들웨어**: 이미지(최대 10MB) 및 음악 파일(최대 10MB)을 업로드할 수 있는 파일 처리 시스템 구축.
* **REST API 설계**: 15개 이상의 Express 엔드포인트를 구현하고, 예외 처리를 규격화.

### [Phase 4 & 5] 폴리싱 및 웹 실운영 배포 (완료)
* **Nginx 리버스 프록시**: 웹 트래픽(Flutter Web PWA 빌드 정적 배포)과 API/웹소켓 트래픽(Node.js 4100포트 프록시)을 분기 처리.
* **HTTPS 적용**: Certbot(Let's Encrypt) 자동 갱신 인증서 추가.
* **PM2 관리**: secretbase-realtime 이름으로 서버 백그라운드 프로세스 등록 및 무중단 상태 확인 모니터링.

---

## 2. 주요 기능 기술 구현 디테일 (Technical Details)

### 2.1 실시간 통신 및 Presence 동기화 (Socket.IO + Redis)
1. **방 매핑 및 인증**:
   * 로그인한 커플은 고유한 RoomCode를 부여받는다.
   * socket.js에서는 커넥션 맺음과 동시에 socket.join(roomCode)을 실행하여 두 사용자만의 실시간 논리 채널을 형성한다.
2. **Presence Users 감지**:
   * Redis의 해시맵(HashMap) 구조를 활용하여 접속 중인 UserCode 목록을 실시간 기록한다.
   * 접속 해제 시 disconnecting 이벤트를 인터셉트하여 상대방에게 오프라인 이벤트를 즉각 브로드캐스트한다.

### 2.2 게임 엔진 상태 머신 (State Machines)
서버에서 관리하는 게임 객체들은 상태 머신에 기반하며, 클라이언트의 오동작이나 불법 입력을 방지하기 위해 **모든 핵심 연산은 서버**에서 수행된다.

* **윷놀이 엔진 (yut-engine.js)**:
  ```text
  [대기방] -> [선공 결정] -> [윷 던지기 대기] -> [윷 결과 판정] -> [말 선택 및 이동 연산] -> [턴 전환 혹은 추가 투척]
  ```
  * 말이 잡히거나 도착점에 골인하는 경우의 수가 복잡하므로, 서버의 메모리 상에 YutGame 클래스가 매 판의 상태(turn, boardState, rolledValue)를 저장한다.
* **UNO 엔진 (uno-engine.js)**:
  ```text
  [덱 108장 생성] -> [플레이어별 7장 배분] -> [공유 덱 & 버림 덱 설정] -> [플레이어 턴 제어] -> [카드 유효 검증]
  ```
  * 플레이어가 낸 카드가 버림 덱 맨 위 카드와 색상 혹은 숫자가 맞는지 확인하는 isValidMove() 연산이 핵심이다.
  * 특수 기능인 discard_all을 내면 핸드 내 동일 색상의 모든 카드를 한 번에 제거하는 다중 패 처리를 수행한다.
* **폭탄 돌리기 엔진 (bomb-engine.js)**:
  * 퀴즈는 공통 한국어 퀴즈 풀에서 서버가 랜덤 선정한다.
  * 서버 내 타이머 세션(setInterval)이 1초마다 동작하여 남은 시간을 차감하며, 0이 되는 시점에 bomb:explode 이벤트를 방 내 모든 사용자에게 보내 강제 종료시킨다.

### 2.3 Redis 기반 재접속 세션 복구 (State Restoration)
사용자가 네트워크 상태 불안정으로 연결이 끊어지거나 웹 브라우저를 새로고침하더라도 게임 진행 정보가 날아가지 않도록 **Ephemeral Redis Session Recovery**를 도입했다.

1. **상태 캐싱**: 게임의 주된 데이터 상태가 변할 때마다 Redis에 room:{roomCode}:game 키로 게임 상태 JSON 데이터를 백업한다. (TTL: 윷/UNO 1시간, 폭탄 5분)
2. **세션 복구 시나리오**:
   * 클라이언트 재접속 -> session:join 성공 -> session:restore 자동 호출.
   * 서버는 Redis에서 해당 방의 키를 검색하고 상태가 존재하면 이를 반환한다.
   * 클라이언트의 _restoreGameState()에서 반환된 원격 상태를 덮어쓰고 게임 보드를 복원한다.

---

## 3. 트러블슈팅 (Troubleshooting)

### 3.1 로컬 개발용 CORS 및 API 주소 리졸빙 이슈
* **문제**: 로컬 환경에서 Flutter Web을 실행(localhost:3000)하고, Node.js 서버(localhost:4100)에 API 요청을 보낼 때, 브라우저 환경에서 CORS(Cross-Origin Resource Sharing) 에러가 발생하며 404를 반환했다.
* **원인**: Uri.base.origin 기반으로 REST API Base URL을 호출하도록 일괄 구현되어 있어, 로컬 개발 환경에서도 프로덕션 환경처럼 요청이 날아가 발생한 문제였다.
* **해결**: server_config.dart 파일을 수정하여 실행 호스트를 체크하는 가드 절을 도입했다.
  ```dart
  // server_config.dart 수정 코드
  static String get apiBaseUrl {
    final String origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      // 로컬 개발 환경인 경우 dart-define의 SOCKET_URL 또는 로컬 4100 포트 지정
      return const String.fromEnvironment('SOCKET_URL', defaultValue: 'http://localhost:4100');
    }
    // 프로덕션 환경인 경우 현재 호스팅되는 오리진 그대로 사용 (Nginx 프록시)
    return origin;
  }
  ```
  이후 Flutter 개발 서버 기동 시 포트를 고정하고 Socket URL을 명시하여 해결했다.
  ```bash
  flutter run -d chrome --web-port=3000 --dart-define=SOCKET_URL=http://localhost:4100
  ```

### 3.2 MariaDB 연결 실패 및 DDL 마이그레이션 예외
* **문제**: 실 서버 환경 배포 후 MariaDB에 테이블 및 새로운 컬럼(StartDate)이 존재하지 않아 REST API 접근 시 서버가 크래시 및 500 에러를 뿜었다.
* **해결**: 백엔드 라우터 세팅 시점에 데이터베이스 테이블의 존재 유무를 점검하고 누락된 요소를 생성하는 ensureTables() 메서드를 추가하여 안전하게 구동되도록 해결했다.
  ```javascript
  // routes.js의 ensureTables 중 일부
  async function ensureTables() {
    try {
      // Couples 테이블에 StartDate 필드가 누락되어 있는지 확인하고 자동 추가
      const columns = await db.query("SHOW COLUMNS FROM Couples LIKE 'StartDate'");
      if (columns.length === 0) {
        await db.query("ALTER TABLE Couples ADD COLUMN StartDate DATE NULL");
        console.log("Added StartDate column to Couples table.");
      }
      
      // 아카이브용 테이블 스키마 확인 및 DDL 실행
      await db.query(`
        CREATE TABLE IF NOT EXISTS setlog_posts (
          id INT AUTO_INCREMENT PRIMARY KEY,
          couple_id INT NOT NULL,
          user_id INT NOT NULL,
          media_type VARCHAR(10) NOT NULL,
          media_url VARCHAR(255) NULL,
          caption TEXT NULL,
          tags JSON NULL,
          captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log("Database table integrity checked & restored.");
    } catch (err) {
      console.error("DDL Migration check failed:", err);
    }
  }
  ```
