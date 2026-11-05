# 01: 벡터 카드 위젯 (PlayingCard)

**Type:** client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

블랙잭·도둑잡기가 같이 쓰는 **글자 없는 카드 그림**을 만든다. `🂠`와 `♠♥♦♣` 글자에 의존하지 않아 어떤 환경에서도 같은 모양이 나온다.

## Acceptance criteria

- [ ] `lib/widgets/play_kit/playing_card.dart`: `PlayingCard`(앞면 / 뒷면 / 조커, 크기 3종 small·medium·large, `highlight`, `newBadge` 옵션)
- [ ] `SuitPainter`: 무늬 4종을 `Path`로 그린다(글자·이모지 사용 금지)
- [ ] `CardBackPainter`: 하트 패턴 뒷면(앱 파스텔 톤)
- [ ] 숫자·문자는 앱 글꼴로, 모서리 인덱스(좌상/우하) + 중앙 무늬
- [ ] 모든 크기에서 글자가 잘리지 않는다(10, J, Q, K, A 포함)
- [ ] 위젯 테스트: 앞면 52장 + 조커 + 뒷면이 예외 없이 그려진다 / 글리프 문자(♠♥♦♣🂠)가 위젯 트리에 없다
- [ ] 로컬 스크린샷(`GAME_SHOTS=1`)으로 4무늬·조커·뒷면을 눈으로 확인

## Notes

한 장짜리 시각 부품이라 서버 변경 없음. 기존 화면(블랙잭·도둑잡기)은 이 티켓에서 바꾸지 않는다(각 화면 티켓에서 교체).

## Likely files

- `apps/secret_base_app/lib/widgets/play_kit/`
- `apps/secret_base_app/test/play_kit_card_test.dart`
