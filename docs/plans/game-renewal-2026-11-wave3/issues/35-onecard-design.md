# 35: 원카드 디자인

**Type:** client

**Blocked by:** –

**Status:** done (PR #253)

## What to build

원카드 전 화면(카드 앞뒷면, 손패, 테이블, 색 고르기, 결과, 로비)을 확정된 목업("끝판왕")대로 구현한다. 규칙·서버는 그대로.

## Acceptance criteria

- [x] 카드 앞뒷면·손패 부채꼴·더미·공격 쌓임 표시·색 고르기·원카드/잡기 버튼·결과 시트·새 로비
- [x] 게임 전용 테마(`onecard_ui.dart`), 공용 테마 파일 미수정
- [x] 위젯 테스트, 두 계정 실제 화면 확인

## Likely files
- `apps/secret_base_app/lib/screens/arcade/games/onecard/`, `lib/screens/arcade/game_lobby_screen.dart`
