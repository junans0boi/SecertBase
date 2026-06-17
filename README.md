# Secret Base (비밀기지)

두 사람만을 위한 프라이빗 실시간 게임 + 일상 아카이빙 플랫폼의 모노레포입니다.

## 현재 구현 상태

- **완료 (Phase 0 + Phase 1 일부)**  
  - Flutter(Web/Android) 앱 생성
  - Node.js + Socket.IO + Redis 실시간 서버 생성
  - 2인 제한 방 입장/접속자 동기화
  - Ping/Pong 지연 확인
  - 주사위/룰렛 이벤트 동기화

## 폴더 구조

```text
apps/
  secret_base_app/        # Flutter app (Web + Android)
services/
  realtime-server/        # Node.js + Socket.IO + Redis server
docs/
  PRODUCT_SPEC.md
  ROADMAP.md
  SOCKET_EVENTS.md
  WORKLOG.md
```

## 실행 방법

### 1) Redis 준비

```bash
docker run --name secretbase-redis -p 6379:6379 -d redis:7
```

### 2) 서버 실행

```bash
cd services/realtime-server
cp .env.example .env
npm install
npm run dev
```

### 3) Flutter 앱 실행 (웹)

```bash
cd apps/secret_base_app
flutter pub get
flutter run -d chrome --dart-define=SOCKET_URL=http://localhost:4100
```

## 다음 구현 우선순위

1. Reconnect 이후 상태 복구 정확도 강화
2. 룸 초대 코드 기반 입장 UX 추가
3. 모바일 윷놀이 / UNO / 폭탄 돌리기 코어 상태 머신 도입
