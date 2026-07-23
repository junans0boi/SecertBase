# 비밀기지 (Secret Base)

> 우리 둘만의 공간 — 실시간 커플 게임 플랫폼

**배포 주소**: [https://secertbase.kro.kr](https://secertbase.kro.kr)

---

## 소개

비밀기지는 커플 두 사람만을 위한 프라이빗 실시간 게임 앱입니다.  
커플 코드 하나로 연결하고, 함께 10가지 미니게임을 즐길 수 있습니다.

---

## 기능

### 커플 연결
- 이메일 로그인 / Google OAuth
- 커플 코드로 1:1 실시간 연결
- 연결 상태 실시간 표시

### 아케이드
인스타 스토리 스타일 게임 탭 — 아이콘을 탭하면 하단에 게임 상세 카드가 펼쳐집니다.

| 게임 | 설명 |
|------|------|
| 윷놀이 | 말 업기·잡기, 보너스 던지기(윷·모), 캐릭터 토큰 |
| 원카드 | go_wild 모드, +2/+4 스택 방어, ALL 카드 |
| 폭탄 돌리기 | 문제를 맞히고 폭탄 넘기기 |
| 가위바위보 | 단판·3판·묵찌빠 |
| 주사위 | 실시간 동시 굴리기 |
| 룰렛 | 커스텀 선택지 룰렛 |
| 텔레파시 | 같은 답을 고르면 성공 |
| 해적 룰렛 | 칼 꽂기 벌칙 게임 |
| 그림 맞히기 | 직접 그린 그림 정답 맞히기 |
| 제로 | 숫자+합계 예측 심리전 |

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프론트엔드 | Flutter Web |
| 백엔드 | Node.js + Express + Socket.IO |
| 실시간 | Redis Pub/Sub |
| 데이터베이스 | MariaDB / MySQL |
| 배포 | Nginx + PM2, 자체 서버 |

---

## 서버 배포

```bash
ssh ubuntu@<서버 IP>
cd ~/SecertBase
git pull origin main
./scripts/deploy_server.sh
```

배포 스크립트는 테스트 → Flutter 웹 빌드 → rsync → PM2 재시작 순으로 실행됩니다.

---

## 폴더 구조

```
apps/
  secret_base_app/        # Flutter 앱 (Web)
services/
  realtime-server/        # Node.js + Socket.IO 백엔드
    src/
      uno-engine.js       # 원카드 게임 엔진
      yut-engine.js       # 윷놀이 게임 엔진
      socket.js           # 소켓 이벤트 핸들러
      index.js            # 서버 진입점
    test/                 # 단위 테스트 (78개)
scripts/
  deploy_server.sh        # 서버 배포 스크립트
docs/                     # ADR, 워크플로우 문서
```

---

## 테스트

```bash
cd services/realtime-server
npm test
```

---

© 2026 SteadyToVivid — LeeJunHwan  
이 소프트웨어 및 소스 코드는 SteadyToVivid의 지식재산입니다.  
저작권자의 명시적 서면 허가 없이 복제·배포·상업적 이용을 금합니다.  
Unauthorized reproduction, distribution, or commercial use is strictly prohibited without the express written permission of SteadyToVivid.
