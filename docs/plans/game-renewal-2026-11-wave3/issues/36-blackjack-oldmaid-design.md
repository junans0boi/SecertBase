# 36: 블랙잭·도둑잡기 디자인·글꼴

**Type:** client

**Blocked by:** –

**Status:** done (PR #253)

## What to build

두 게임을 확정 목업대로 다시 그리고, "2007년 귀혼풍"이던 글꼴을 현대적인 글꼴로 바꾼다.

## Acceptance criteria

- [x] 로비 제목·카운트다운의 만화체(Gaegu) 제거 → Gowun Batang + Noto Sans KR
- [x] 게임 본문의 영문 전용 글꼴 → Noto Sans KR(`GameTheme.bodyFont`, lounge·storybook만)
- [x] 블랙잭 대칭 정렬, 카드 앞뒷면, 도둑잡기 열쇠 구멍 카드·도둑 조커
- [x] 위젯 테스트, 두 계정 실제 화면 확인
- [ ] (범위 밖) 놀이 탭 게임 목록의 Gaegu 글꼴

## Likely files
- `apps/secret_base_app/lib/screens/arcade/games/blackjack/`, `oldmaid/`, `lib/screens/arcade/game_lobby_themed.dart`, `lib/widgets/play_kit/`
