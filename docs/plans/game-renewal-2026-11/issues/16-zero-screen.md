# 16: 제로 2.0 화면 (별도 화면으로 분리)

**Type:** client

**Blocked by:** 02, 03, 15

**Status:** ready-for-agent

## What to build

제로를 가위바위보 화면에서 떼어 **`zero_screen.dart`로 분리**하고, 큰 손 카드와 칩 입력, "3 + 2 = 5" 공개 연출로 새로 만든다.

## Acceptance criteria

- [ ] `games/zero/zero_screen.dart` 신설. `rps_screen.dart`에서 제로 관련 코드 전부 삭제(가위바위보 동작 회귀 없음). 아케이드의 `zero` 진입을 새 화면으로 변경
- [ ] 입력: 손 카드 6장(0~5) 한 줄 크게(선택 시 커지고 흔들림) → "예측" 칩(내 숫자 ~ +5, 최대 6개) → 큰 "제출!" 버튼. `+`를 여러 번 누르는 스테퍼 제거
- [ ] 제출 뒤 요약("내 손 3 · 예측 5"), 상대 대기 표시
- [ ] 공개: "하나~둘~셋!" 카운트(글자 겹침 없이) → 두 손이 가운데로 올라오고 "3 + 2 = 5" 계산 → 판정 한 줄(정확 적중 / 근접 승 / 같은 거리) → 점수 진행 막대 5칸
- [ ] 서든데스 라운드 "마지막 한 판!" 배지
- [ ] 효과음: 카운트, 공개, 적중, 근접, 승리, 패배 (`recipes/zero.dart`)
- [ ] 결과 `GameResultSheet`(전적, 재대결). 로비 설명 문구 갱신("숫자를 숨기고 합계를 맞혀요. 5라운드 승부"), 게임 안 이중 시작 제거
- [ ] `GameMenuListener`/`GameScaffold(gameType: 'zero')`
- [ ] 위젯 테스트: 예측 칩이 내 숫자에 따라 범위가 바뀜, 판정 문구 3종, 서든데스 표시, 폭 360. 가위바위보 화면 테스트 회귀 통과
- [ ] 두 계정 실플레이 한 판(적중·근접·동거리·서든데스)을 확인하고 PR에 기록

## Notes

`rps_screen.dart`가 2,000줄이므로 삭제 diff가 크다. 가위바위보 기존 테스트를 먼저 돌려 기준선을 만든 뒤 진행한다.

## Likely files

- `apps/secret_base_app/lib/screens/arcade/games/zero/`
- `apps/secret_base_app/lib/screens/arcade/games/rps_screen.dart`
- `apps/secret_base_app/lib/screens/arcade/arcade_screen.dart`
