# 테스터 환경 격리 설정 가이드

이 문서는 `test.secertbase.kro.kr` 테스터 환경을 운영과 완전히 격리해 구성하는 방법을 설명한다.

**최신 업데이트: 2026-07-15 (이슈 #14)**

## 격리 요건 체크리스트

| 항목 | 운영 | 테스터 | 상태 |
|---|---|---|---|
| PM2 프로세스 | `secretbase-realtime` | `secretbase-test` | ⬜ 서버에서 설정 필요 |
| MariaDB DB | `secretbase` | `secretbase_test` | ⬜ 서버에서 설정 필요 |
| Redis | 기본 네임스페이스 | `test:` prefix 또는 별도 DB | ⬜ 서버에서 설정 필요 |
| 업로드 루트 | `/var/www/secretbase/uploads` | `/var/www/secretbase-test/uploads` | ⬜ 서버에서 설정 필요 |
| 백엔드 .env | `.env` | `.env.test` | ⬜ 서버에서 설정 필요 |
| 프론트엔드 빌드 | `/var/www/secretbase` | `/var/www/secretbase-test` | ✅ Caddy 설정 완료 |
| Caddy 라우팅 | `secertbase.kro.kr` | `test.secertbase.kro.kr` | ✅ 완료 |
| 배포 스크립트 백엔드 검증 | `npm test` + `npm run check` | `npm test` + `npm run check` | ✅ `scripts/deploy_test_server.sh` 업데이트 |

## 서버에서 테스터 격리 설정 절차

### 1. MariaDB 테스터 스키마 생성

```bash
mysql -u root -p
```

```sql
CREATE DATABASE IF NOT EXISTS secretbase_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON secretbase_test.* TO 'junzzang'@'localhost';
FLUSH PRIVILEGES;
```

### 2. 테스터 전용 .env 파일 생성

서버 `~/SecertBase/services/realtime-server/.env.test` 를 생성한다.
기존 `.env` 를 복사하고 아래 항목만 변경한다:

```bash
cp ~/SecertBase/services/realtime-server/.env \
   ~/SecertBase/services/realtime-server/.env.test
```

`.env.test` 에서 수정할 항목:

```
DATABASE_URL=mysql://junzzang:<password>@127.0.0.1:3306/secretbase_test
UPLOADS_ROOT=/var/www/secretbase-test/uploads
PORT=4101
# Redis 네임스페이스 분리 (선택)
REDIS_KEY_PREFIX=test:
```

> 주의: `.env.test` 는 절대 커밋하지 않는다. 키/비밀번호가 포함된다.

### 3. 테스터 PM2 프로세스 시작

```bash
cd ~/SecertBase/services/realtime-server
# 테스터 전용 .env.test 를 활성화해 별도 포트로 시작
cp .env .env.prod_backup
cp .env.test .env
pm2 start src/index.js --name secretbase-test
cp .env.prod_backup .env
pm2 save
```

### 4. Caddy 설정 확인

`/etc/caddy/Caddyfile` 에서 두 도메인이 각자의 백엔드 포트로 연결되는지 확인한다:

```caddy
secertbase.kro.kr {
  root * /var/www/secretbase
  # ... /api, /socket.io → 127.0.0.1:4100
}

test.secertbase.kro.kr {
  root * /var/www/secretbase-test
  # ... /api, /socket.io → 127.0.0.1:4101
}
```

포트가 분리되었으면:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

### 5. 배포

격리 설정 완료 후 일반 배포:

```bash
cd ~/SecertBase
./scripts/deploy_test_server.sh
```

스크립트가 수행하는 작업:
1. 작업 트리 청결 확인
2. `origin/main` pull
3. `npm ci` + `npm test` + `npm run check` (백엔드 검증)
4. Flutter 빌드 (`KAKAO_REVIEW_AUTO_LOGIN=false`)
5. `/var/www/secretbase-test/` 동기화
6. `.env.test` 가 있으면 `secretbase-test` PM2 재시작
7. `/health` 엔드포인트 검증

## 데이터 격리 검증

```bash
# 운영 DB와 테스터 DB가 독립적인지 확인
mysql -u junzzang -p secretbase      -e "SELECT COUNT(*) FROM Users;"
mysql -u junzzang -p secretbase_test -e "SELECT COUNT(*) FROM Users;"

# PM2 프로세스가 별도인지 확인
pm2 list

# Caddy가 각 포트로 라우팅하는지 확인
curl -s https://secertbase.kro.kr/health
curl -s https://test.secertbase.kro.kr/health
```

## 운영 데이터 경로

| 항목 | 운영 경로 | 테스터 경로 |
|---|---|---|
| 프론트엔드 | `/var/www/secretbase/` | `/var/www/secretbase-test/` |
| 백엔드 | `PORT=4100` | `PORT=4101` |
| MariaDB DB | `secretbase` | `secretbase_test` |
| 업로드 파일 | `/var/www/secretbase/uploads/` | `/var/www/secretbase-test/uploads/` |
| PM2 프로세스 | `secretbase-realtime` | `secretbase-test` |
| 백엔드 .env | `services/realtime-server/.env` | `services/realtime-server/.env.test` |

> 경고: 테스터 환경에서 운영 DB URL을 절대 사용하지 않는다. 자동화 테스트가 운영 데이터를 변경할 수 있다.
