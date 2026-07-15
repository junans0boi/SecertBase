# 데이터베이스 및 업로드 파일 암호화 백업/복구 운영 가이드

비밀기지(Secret Base) 프로젝트의 데이터 무결성을 보장하기 위해 암호화 백업 및 무결성 검증 복구 체계를 구축하였다.

## 1. 백업 시스템 개요

- **대상:** MariaDB 데이터베이스 전체 스키마, 사용자 업로드 미디어 디렉토리 (`UPLOADS_ROOT`)
- **주기:** 매일 1회 실행 권장 (크론탭 연동)
- **보관 기한:** 정확히 **30세대(30일)** 보관하며, 30개 초과 시 가장 오래된 백업부터 자동 삭제한다.
- **보안:** `AES-256-CBC` 대칭키 암호화 (`pbkdf2` 및 `100000` 반복 횟수 적용)를 사용하여 보관 중 데이터가 유출되더라도 복호화가 불가능하도록 보호한다.

## 2. 사용법

### 2.1 백업 실행 (`scripts/backup.sh`)

백업을 수동 실행하거나 크론탭에 등록하여 사용한다.

```bash
# 환경 변수 설정 후 백업 실행
export BACKUP_ENCRYPTION_KEY="당신의암호화대칭키"
# (선택) DATABASE_URL 및 UPLOADS_ROOT를 다르게 지정하려면 설정
# export DATABASE_URL="mysql://user:pass@host/database"
# export UPLOADS_ROOT="/path/to/uploads"
# export BACKUP_DIR="/path/to/backups"

./scripts/backup.sh
```

**동작 프로세스:**
1. `DATABASE_URL`을 파싱하여 DB 연결 정보를 추출한다.
2. `mysqldump`를 사용하여 데이터베이스의 논리 덤프를 임시 공간에 생성한다 (TCP 연결 실패 시 로컬 소켓 자동 펄백 지원).
3. `UPLOADS_ROOT` 디렉토리의 파일들을 임시 폴더에 모은다.
4. 두 대상을 묶어 tar로 압축하는 동시에 `openssl`로 대칭키 암호화 처리를 진행한다.
5. 백업 디렉토리 내의 암호화된 백업 파일 목록을 최근 순으로 정렬하여, 30세대 초과분을 청소한다.

### 2.2 복구 및 무결성 검증 (`scripts/restore.sh`)

복구 스크립트는 암호화 해독, DB 및 파일 복구, 그리고 복구된 리소스에 대한 **무결성 검증**을 원스톱으로 처리한다.

> [!CAUTION]
> 운영 환경의 데이터베이스(`secretbase`)를 덮어씌우는 것을 기본 방지한다. 프로덕션 DB에 강제 복구해야 하는 경우 `FORCE_RESTORE=true` 설정이 요구된다.

```bash
export BACKUP_ENCRYPTION_KEY="당신의암호화대칭키"

# 복구 대상 환경 지정 (복구 전용 임시/격리 환경 권장)
./scripts/restore.sh <백업파일.tar.enc> [복구대상_DATABASE_URL] [복구대상_UPLOADS_ROOT]
```

**예시:**
```bash
./scripts/restore.sh backups/backup_20260715_120000.tar.enc \
  mysql://junzzang:0427@127.0.0.1/secretbase_restore_test \
  /var/www/secretbase-test/uploads_restore
```

**무결성 검증 항목:**
- 복구된 데이터베이스에 필수 테이블 (`Users`, `Couples`, `map_pins`, `setlog_posts`)이 유실 없이 모두 복구되었는지 확인한다.
- 각 테이블의 레코드 로우 수를 리스팅하여 검증한다.
- 아카이브 백업 원본 내의 파일 수와 실제 복구된 대상 디렉토리의 미디어 파일 개수를 대조하여 미디어 데이터 유실 유무를 최종 검증한다.

### 2.3 배포 파이프라인 통합

배포 스크립트(`deploy_server.sh` 및 `deploy_test_server.sh`) 실행 전 백업 성공 여부를 게이트 조건으로 설정할 수 있다.

```bash
# 배포 실행 시 환경 변수 전달
REQUIRE_BACKUP_BEFORE_DEPLOY=true \
BACKUP_ENCRYPTION_KEY="당신의암호화대칭키" \
./scripts/deploy_server.sh
```
백업이 정상적으로 완료되지 않거나 에러가 나면 배포 파이프라인은 진행을 즉시 중단(exit code 1)한다.

## 3. 일일 자동 백업 크론탭(Cron) 설정 예시

매일 새벽 3시에 백업을 자동 실행하도록 설정하는 예시이다.

```bash
crontab -e
```

```cron
0 3 * * * export BACKUP_ENCRYPTION_KEY="당신의암호화대칭키"; /Users/junzzang/backup/workspace/secertbase/scripts/backup.sh >> /Users/junzzang/backup/workspace/secertbase/backups/backup.log 2>&1
```
