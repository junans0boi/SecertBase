# 02: 효과음 공용화 (`game_sfx`) + 탱크 이전

**Type:** client

**Blocked by:** 외부: PR #216 머지

**Status:** ready-for-agent

## What to build

탱크의 합성 효과음 엔진을 **모든 게임이 쓰는 공용 모듈**로 옮긴다. 탱크 동작은 그대로여야 한다.

## Acceptance criteria

- [ ] `lib/core/game_sfx/synth_core.dart`: `TankSynth`의 빌딩 블록(톤·노이즈·노트·페이드·WAV 래핑)을 공개 API로 이동
- [ ] `game_sfx.dart` + `game_sfx_web.dart` + `game_sfx_stub.dart`: 일반화된 재생기(`play(recipe, {volume})`, `muted`, `setMuted`, `init()` 미리 합성). 웹에서만 소리, 테스트에서는 무음
- [ ] 음소거 키를 `game_sfx_muted` 하나로 합치고 옛 `tank_sfx_muted`를 처음 한 번 읽어 옮긴다
- [ ] 탱크 레시피는 `tank/`에 남기고 새 합성기를 사용한다. **탱크 오디오 출력이 이전과 같다**(샘플 비교 테스트)
- [ ] 새 레시피 파일 틀: `recipes/{cards,duel,pirate,soccer,zero,common}.dart` — 이 티켓에서는 빈 틀 + 공통 레시피(클릭·타이머 경고·보상)만
- [ ] 레시피 테스트: 모든 레시피가 무음이 아니고 클리핑되지 않으며 결정적(`tank_engine_ui_test.dart`의 합성음 테스트와 같은 방식)
- [ ] 탱크 화면의 음소거 버튼이 공용 설정으로 동작하고 기존 탱크 테스트가 모두 통과

## Notes

기능 추가가 아니라 이동이다. 이동 전에 탱크 소리 샘플을 저장해 두고 이동 후 같은지 비교한다. 새 의존성 없음.

## Likely files

- `apps/secret_base_app/lib/core/game_sfx/`
- `apps/secret_base_app/lib/screens/arcade/games/tank/tank_synth.dart,tank_sfx*.dart`
- `apps/secret_base_app/test/tank_engine_ui_test.dart`
