# 31: 윷놀이 시스템 — 캐릭터 능력치·윷 스킨·마이그레이션

**Type:** server+client

**Blocked by:** –

**Status:** done (PR #253)

## What to build

말은 캐릭터 3명(홍길동·미호·놀부)으로 고정하고 능력치 5개를 규칙에 적용한다. 상점에는 윷 스킨만 남기고 등급마다 겉모습과 효과를 다르게 한다. 기존 아이템은 같은 등급 새 스킨으로 전환한다.

## Acceptance criteria

- [x] 능력치 5개(던지기 힘·침착·방어·행운·기세), 세 캐릭터 합 15, 서버가 상한 적용 후 효과를 계산해 `game:yut:state`로 전달
- [x] 윷 스킨 9종(110–118, B~SSS) + 무료 기본 윷, 효과 키는 기존 상한 안에서 합산
- [x] 말 스킨(`yut_piece`) 폐지, 기존 윷·말 아이템 은퇴(`yut_legacy`), 소유·장착 전환 마이그레이션 `0049_yut_system.sql`(멱등)
- [x] 공정성 시뮬레이션: 최강 장비 대 최약 ≤55%, 캐릭터 맞대결 45~55%
- [x] 로비 캐릭터 선택(상대와 겹치지 않음), 능력치 표시, 상점 윷 스킨 화면
- [x] 서버·클라이언트 테스트, `docs/socket-events/yut.md`, `27-yut-system.md`

## Likely files
- `services/realtime-server/src/yut-engine.js`, `src/games/yut.js`, `migrations/0049_yut_system.sql`
- `apps/secret_base_app/lib/screens/arcade/games/yut/`, 상점 화면
