# 17: 최종 검증과 문서 갱신

**Type:** verification

**Blocked by:** 06, 07, 09, 10, 11, 12, 13, 14, 15, 16

**Status:** ready-for-agent

## What to build

다섯 게임을 두 계정으로 끝까지 해 보고 문서와 테스트를 마무리한다.

## Acceptance criteria

- [ ] 두 계정으로 5종 각각: 승/패/무, 재대결 수락·거절, 도중 나가기(잠수 기권), 재접속 복원
- [ ] 서버 테스트 전체 통과(기존 대비 실패 증가 없음), `flutter analyze` 0건, `dart format` 통과, `flutter test` 전체 통과(알려진 환경 의존 실패 제외)
- [ ] 균형 테스트가 목표 범위(블랙잭 무승부 < 3%, 제로 갈림 > 65% · 한 판 ≤ 7라운드, 패널티킥 선방 30~36%)
- [ ] `docs/SOCKET_EVENTS.md`, `docs/GAME_AUDIT_2026-11-04.md`(5종 결과), `docs/plans/game-renewal-2026-11/`의 상태 갱신
- [ ] 탱크 회귀: 공용 효과음 이전 후 탱크가 그대로 동작
- [ ] 아케이드 목록 설명 문구가 실제 규칙과 일치
- [ ] 분석 문서 §8의 "확인하지 못한 것"을 실제로 확인해 결과를 기록

## Notes

사용자 확인 뒤에 마지막 PR을 머지한다. 머지 순서와 배포 영향은 `03-wayfinder-map.md`를 따른다.

## Likely files

- `docs/`
- `services/realtime-server/test/`
- `apps/secret_base_app/test/`
