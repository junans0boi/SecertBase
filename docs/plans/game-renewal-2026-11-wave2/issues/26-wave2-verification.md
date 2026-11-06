# 26: 통합·리뷰·실플레이·빌드

**Type:** verification

**Blocked by:** 21, 22, 23, 24, 25

**Status:** ready-for-agent

## What to build

다섯 작업 브랜치를 합치고, 독립 리뷰와 두 계정 실플레이로 확인한 뒤 빌드·PR까지 마친다.

## Acceptance criteria
- [ ] 다섯 브랜치 병합, 충돌 정리, 25 화투를 24 화면에 연결
- [ ] `node --test`·`flutter analyze`·`flutter test` 통과(알려진 환경 실패 제외)
- [ ] 독립 코드 리뷰 지적 반영
- [ ] 두 계정 실플레이(네 게임 시작·핵심 장면·결과·재대결)
- [ ] 5050 빌드, `docs/SOCKET_EVENTS.md` 링크, PR
