# 10: 도둑잡기 2.0 화면

**Type:** client

**Blocked by:** 01, 02, 03, 05, 09

**Status:** ready-for-agent

## What to build

뽑은 카드가 보이고 손패가 정렬되며 한 화면에 들어오는 도둑잡기를 만든다. 분석의 O1~O9를 모두 해결한다.

## Acceptance criteria

- [ ] 테마 **동화책 티파티**: 크림 종이 질감 + 수채 번짐 + 레이스 테두리, 버건디·골드·라일락 포인트. 조커를 뽑으면 카드가 살짝 웃고 잉크가 번지는 연출. 색·배경은 `GameTheme`/`GameBackdrop`(티켓 03)만 사용, 탱크 2.0 이상의 완성도(질감·조명·모션)
- [ ] `games/oldmaid/` 폴더 + 얇은 진입점
- [ ] 한 화면, 스크롤 없음: 상대 부채꼴(뒷면 `PlayingCard`) → 중앙(버린 짝 더미 "N쌍" + 뽑기 연출 + 최근 한 줄) → 내 부채꼴 → 리액션 줄
- [ ] 내 손패: 랭크순 정렬, 조커 맨 오른쪽, 겹쳐 펼침(13장 이상도 한 줄), 새 카드 "NEW"와 빛
- [ ] 뽑기 연출: 탭한 카드가 올라오고 → 중앙에서 크게 뒤집힘 → 손패로 이동 또는 짝이면 "짝!" 이펙트와 함께 더미로. 뺏긴 쪽은 카드가 사라지고 "◯◯을 뺏겼어요" 토스트
- [ ] 조커: 뽑는 순간 어두운 소리 + 붉은 흔들림, 내 손패 조커는 붉은 테두리
- [ ] `ReactionBar` 연동(`game:reaction`), 상대 말풍선 3초
- [ ] 효과음: 카드 딜, 뒤집기, 짝, 조커, 승리, 패배 (`recipes/cards.dart`)
- [ ] 결과 `GameResultSheet`(조커를 든 사람 패배, 전적, 재대결). `GameMenuListener`/`GameScaffold(gameType:)` 연결
- [ ] 게임 안 별도 시작 화면 제거
- [ ] 위젯 테스트: `drawn` 이벤트 두 종류(뽑은 쪽/뺏긴 쪽)의 표시, 정렬, 20장 손패에서 오버플로 없음, 폭 360
- [ ] 두 계정 실플레이 한 판(조커 승/패 둘 다)을 확인하고 PR에 기록

## Notes

분석 문서 O2~O4가 사용자가 말한 "옥에티"일 가능성이 가장 크다. 구현 PR에서 사용자에게 한 번 더 확인한다.

## Likely files

- `apps/secret_base_app/lib/screens/arcade/games/oldmaid/`
- `apps/secret_base_app/lib/core/socket_service.dart`
