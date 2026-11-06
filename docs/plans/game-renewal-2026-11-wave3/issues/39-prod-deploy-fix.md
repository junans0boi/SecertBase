# 39: 운영 배포 — 0049 마이그레이션 ENUM 오류 수정

**Type:** server

**Blocked by:** –

**Status:** in-progress (PR #255 — CI 통과, 병합 대기)

## What to build

PR #253 병합 후 운영 배포가 DB 마이그레이션에서 멈췄다(`Data truncated for column 'stat_key'`). 0049가 달빛 윷 효과로 쓰는 `yut_backdo_shield_pct`가 0019에서 ENUM에서 빠져 있었다. 배포는 마이그레이션 단계에서 중단돼 **운영 서비스는 이전 버전 그대로**다.

## Acceptance criteria

- [x] 0049 안에서 `item_stats.stat_key` ENUM에 `yut_backdo_shield_pct`를 다시 허용(기존 값 유지, 멱등)
- [x] 마이그레이션을 순서대로 따라가며 모든 `item_stats` INSERT의 키가 그 시점 ENUM에 있는지 검사하는 테스트(원래 0049에서 실패, 수정본에서 통과)
- [ ] #255 병합 후 "Deploy to Production Server" 성공
- [ ] 배포 후 확인: 기존 윷 아이템이 같은 등급 새 스킨으로 전환됐는지, 소유 아이템이 사라지지 않았는지, 윷놀이 첫 판(능력치·스킨·테마)

## Likely files
- `services/realtime-server/migrations/0049_yut_system.sql`, `test/migration-stat-keys.test.js`
