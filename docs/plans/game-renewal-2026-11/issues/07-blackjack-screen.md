# 07: 블랙잭 2.0 화면

**Type:** client

**Blocked by:** 01, 02, 03, 06

**Status:** ready-for-agent

## What to build

블랙잭 화면을 민트 펠트 테이블 + 딜·뒤집기 연출 + 효과음으로 새로 만든다.

## Acceptance criteria

- [ ] `games/blackjack/` 폴더(테이블, 손, HUD, 결과 모듈) + 기존 `blackjack_screen.dart`는 얇은 진입점
- [ ] 위=상대, 아래=나(항상 같은 위치). 상대 업카드·히트 카드 표시, 홀카드는 뒷면, 상대 상태 배지("스탠드!", "버스트!"), "공개 카드 합 + ?"
- [ ] 상단: 라운드 승수 ●○, 남은 시간 링(30초). 영문 병기(`Hit`, `Stand`) 제거
- [ ] 연출: 딜(덱에서 날아옴), 홀카드 뒤집기, 버스트 흔들림, 블랙잭 반짝임, 라운드 종료 시 숨은 카드 순서대로 공개, 턴 배너
- [ ] 효과음: 딜, 뒤집기, 버스트, 블랙잭, 승리, 패배, 타이머 경고(공용 엔진 + `recipes/cards.dart`)
- [ ] 라운드 결과 시트 + 양쪽 "다음 라운드" 준비 버튼(상대 준비 표시). 최종 결과는 `GameResultSheet`(전적·재대결 요청)
- [ ] 로비 설명을 "숨은 카드 한 장으로 겨루는 1:1 21점 대결"로 수정, 게임 안 별도 시작 화면 제거(로비 시작이 곧 시작)
- [ ] `GameMenuListener`로 감싸 재시작 합의 연결, `GameScaffold(gameType: 'blackjack')`
- [ ] 위젯 테스트: 내 차례/상대 차례/라운드 결과/최종 결과, 폭 360에서 오버플로 없음
- [ ] 두 계정 실플레이 한 판(2:0, 2:1, 무승부 라운드 포함)을 확인하고 PR에 기록

## Notes

다크 네이비 배경을 쓰지 않는다. 카드는 티켓 01의 `PlayingCard`만 사용.

## Likely files

- `apps/secret_base_app/lib/screens/arcade/games/blackjack/`
- `apps/secret_base_app/lib/screens/arcade/arcade_screen.dart`
