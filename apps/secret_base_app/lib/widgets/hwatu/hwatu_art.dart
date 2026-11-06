/// 벡터 화투 카드 위젯.
///
/// 48장 앞면과 뒷면을 모두 `CustomPainter`로 그린다(자산 PNG 없음).
/// 카드 그림은 id마다 한 번 `ui.Picture`로 기록해 캐시하고, 그릴 때는
/// 확대 재생 + 모서리 색인(종류 배지·월 숫자)만 그리므로 다시 그리기가 싸다.
///
/// ## 카드 정체성
/// 서버 엔진(`services/realtime-server/src/gostop-engine.js`)의 카드 맵
/// `{id, month, type, subtype}`을 그대로 받는다. id가 정본이며
/// ([kHwatuDeck]), 호환 id `m1_animal`(홍단 띠)·`m7_animal_2`(초단 띠)도
/// 엔진과 같게 해석한다. `card == null` 또는 `id == 'back'`이면 뒷면.
///
/// ## 기존 `lib/ui/hwatu_card.dart`에 붙이는 법
/// `HwatuCard`의 공개 API(`card`, `width`, `highlighted`, `selected`,
/// `onTap`, `onLongPress`)는 그대로 두고 그림만 바꾸면 된다.
/// `HwatuCard.build`의 `ClipRRect(child: _isBack ? … : _buildFace())`를
///
/// ```dart
/// HwatuArt(card: card, width: width, highlighted: highlighted)
/// ```
///
/// 로 바꾸고, `HwatuArt`가 테두리·둥근 모서리·하이라이트 빛을 직접
/// 그리므로 `AnimatedContainer`의 `boxShadow` 하이라이트와 `ClipRRect`는
/// 빼고 그림자만 남긴다(모서리 반지름은 [hwatuCornerRadius]). 비율은
/// 기존과 같은 [kHwatuAspect](91/60)라 배치는 바뀌지 않는다. 새 게임
/// 화면에서는 `HwatuArt`를 바로 쓰면 되며, 고를 수 없는 패는
/// `dimmed: true`, 덮인 패는 `faceUp: false`로 그린다. 교체 뒤에는
/// `assets/images/hwatu/`와 `hwatuCardAssetPath`, PNG 대조 테스트
/// (`test/hwatu_card_test.dart`)를 지워도 된다.
library;

import 'package:flutter/widgets.dart';

import 'hwatu_deck.dart';
import 'hwatu_kit.dart';
import 'hwatu_painter.dart';

/// 화투 한 장(앞면 또는 뒷면).
class HwatuArt extends StatelessWidget {
  /// [card]는 엔진 카드 맵, [cardId]는 id만 알 때. 둘 다 없으면 뒷면.
  const HwatuArt({
    super.key,
    this.card,
    this.cardId,
    required this.width,
    this.faceUp = true,
    this.highlighted = false,
    this.dimmed = false,
  });

  /// 뒷면.
  const HwatuArt.back({
    super.key,
    required this.width,
    this.highlighted = false,
    this.dimmed = false,
  }) : card = null,
       cardId = null,
       faceUp = false;

  final Map<String, dynamic>? card;
  final String? cardId;

  /// 카드 가로 폭(논리 픽셀). 세로는 `width * kHwatuAspect`.
  final double width;

  /// false면 카드가 무엇이든 뒷면을 그린다.
  final bool faceUp;

  /// 금빛 테와 빛(먹을 수 있는 패 등).
  final bool highlighted;

  /// 어둡게 눌러 그림(고를 수 없는 패 등).
  final bool dimmed;

  /// 이 위젯이 그릴 카드 정체성. 뒷면이면 null.
  HwatuCardSpec? get spec {
    if (!faceUp) return null;
    if (card != null) return hwatuSpecFromCard(card);
    return hwatuSpecById(cardId);
  }

  @override
  Widget build(BuildContext context) {
    final s = spec;
    final size = Size(width, width * kHwatuAspect);
    return Semantics(
      label: s?.label ?? '화투 뒷면',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: s == null
              ? HwatuBackPainter(highlighted: highlighted, dimmed: dimmed)
              : HwatuFacePainter(s, highlighted: highlighted, dimmed: dimmed),
        ),
      ),
    );
  }
}
