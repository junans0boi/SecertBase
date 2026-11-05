import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 카드 가로:세로 비율(공용 PlayingCard와 같다).
const double kOldMaidCardAspect = 92 / 64;

/// 겹쳐 펼친 부채꼴 손패의 기하. 카드가 몇 장이든 [width] 안에 한 줄로 들어간다.
@immutable
class FanGeometry {
  final Rect area;
  final int count;
  final double cardW;

  /// true면 위쪽(상대) 부채꼴: 가장자리 카드가 위로 올라가고 기울기가 반대다.
  final bool flipped;

  const FanGeometry({
    required this.area,
    required this.count,
    required this.cardW,
    this.flipped = false,
  });

  double get cardH => cardW * kOldMaidCardAspect;

  /// 이웃 카드 간격. 넉넉하면 카드 폭의 66%, 좁으면 줄여서 한 줄에 맞춘다.
  double get step {
    if (count <= 1) return 0;
    return math.min(cardW * 0.66, (area.width - cardW) / (count - 1));
  }

  double get spanWidth => cardW + step * math.max(0, count - 1);
  double get startX => area.left + (area.width - spanWidth) / 2;

  /// -1(왼쪽 끝)…1(오른쪽 끝).
  double _t(int i) => count <= 1 ? 0 : i / (count - 1) * 2 - 1;

  double get _arc => math.min(10, 1.0 + count * 0.7);
  double get _maxAngle => math.min(0.16, 0.012 * count);

  /// i번째 카드의 기울기(라디안).
  double angleOf(int i) => _t(i) * _maxAngle * (flipped ? -1 : 1);

  /// i번째 카드의 사각형(회전 전). [lift]만큼 손패 바깥쪽(가운데 방향)으로 띄운다.
  Rect rectOf(int i, {double lift = 0}) {
    final t = _t(i);
    final x = startX + step * i;
    final sag = _arc * t * t;
    final y = flipped
        ? area.top + (area.height - cardH) / 2 - sag + lift
        : area.top + (area.height - cardH) / 2 + sag - lift;
    return Rect.fromLTWH(x, y, cardW, cardH);
  }

  /// 가로 위치 [x]에 보이는 카드 번호(겹친 부분은 위에 놓인 오른쪽 카드).
  int? indexAt(double x) {
    if (count <= 0) return null;
    if (x < startX - 8 || x > startX + spanWidth + 8) return null;
    if (count == 1 || step <= 0) return 0;
    final i = ((x - startX) / step).floor();
    return i.clamp(0, count - 1);
  }
}

/// 한 화면 배치(360×740에서 스크롤 없이): 상대 줄 → 상대 부채꼴 → 가운데 → 내 부채꼴 → 내 줄.
@immutable
class OldMaidTableLayout {
  final Size size;
  final double pad;
  final double oppCardW;
  final double myCardW;
  final double stageCardW;
  final Rect oppBar;
  final Rect oppFan;
  final Rect center;
  final Rect myFan;
  final Rect myBar;

  const OldMaidTableLayout._({
    required this.size,
    required this.pad,
    required this.oppCardW,
    required this.myCardW,
    required this.stageCardW,
    required this.oppBar,
    required this.oppFan,
    required this.center,
    required this.myFan,
    required this.myBar,
  });

  factory OldMaidTableLayout.of(Size size) {
    final w = size.width, h = size.height;
    const pad = 12.0;
    final oppCardW = (h * 0.072).clamp(38.0, 56.0);
    final myCardW = (h * 0.088).clamp(44.0, 66.0);
    const barH = 50.0;
    final oppFanH = oppCardW * kOldMaidCardAspect + 26;
    final myFanH = myCardW * kOldMaidCardAspect + 30;
    final oppBar = Rect.fromLTWH(pad, 2, w - pad * 2, barH);
    final oppFan = Rect.fromLTWH(pad, oppBar.bottom, w - pad * 2, oppFanH);
    final myBar = Rect.fromLTWH(pad, h - barH - 2, w - pad * 2, barH);
    final myFan = Rect.fromLTWH(pad, myBar.top - myFanH, w - pad * 2, myFanH);
    final center = Rect.fromLTRB(pad, oppFan.bottom, w - pad, myFan.top);
    final stageCardW = (center.height * 0.30).clamp(52.0, 92.0);
    return OldMaidTableLayout._(
      size: size,
      pad: pad,
      oppCardW: oppCardW,
      myCardW: myCardW,
      stageCardW: stageCardW,
      oppBar: oppBar,
      oppFan: oppFan,
      center: center,
      myFan: myFan,
      myBar: myBar,
    );
  }

  double get stageCardH => stageCardW * kOldMaidCardAspect;

  /// 공개 연출 카드가 서는 자리(가운데 구역 위쪽 중앙).
  Rect get stage {
    final top = center.top + 26;
    return Rect.fromLTWH(
      center.center.dx - stageCardW / 2,
      top,
      stageCardW,
      stageCardH,
    );
  }

  /// 버린 짝 더미(가운데 왼쪽).
  Rect get discardPile {
    final w = math.min(78.0, stageCardW * 0.86);
    final hh = w * kOldMaidCardAspect;
    return Rect.fromLTWH(center.left + 4, stage.center.dy - hh / 2, w, hh);
  }

  /// 공개 카드 아래 문구·버튼 자리.
  Rect get caption => Rect.fromLTWH(
    center.left,
    stage.bottom + 8,
    center.width,
    math.max(0, center.bottom - stage.bottom - 8),
  );

  FanGeometry oppFanOf(int count) => FanGeometry(
    area: oppFan.deflate(2),
    count: count,
    cardW: oppCardW,
    flipped: true,
  );

  FanGeometry myFanOf(int count) =>
      FanGeometry(area: myFan.deflate(2), count: count, cardW: myCardW);
}
