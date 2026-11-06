# 32: 윷놀이 새 디자인 — 낮/밤 랜덤

**Type:** client

**Blocked by:** 31

**Status:** done (PR #253)

## What to build

"게임 같은" 모던 캐주얼 디자인(2.5D 말판, 캐릭터 전신, 도장 연출). 낮·밤 두 테마를 서버가 판마다 정해 두 사람이 같은 것을 본다.

## Acceptance criteria

- [x] 서버가 시작·재대결마다 `theme: 'day'|'night'`를 정하고 복구 시에도 유지(테스트 주입 가능)
- [x] 말판 2.5D 타일, 캐릭터 전신 말, 카드의 큰 캐릭터 상반신, 점 표시 말 현황, 효과 칩
- [x] 던지기 연출(매트 위 윷가락, 결과 도장), 캡처·골인 연출, 결과 화면, 로비, 상점 윷 스킨
- [x] 360×640·390×844 위젯 테스트, 두 계정 실제 플레이 확인(밤 테마)

## Likely files
- `apps/secret_base_app/lib/screens/arcade/games/yut/`, `lib/widgets/play_kit/game_theme.dart`
