import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 카드 가로:세로 비율(공용 PlayingCard와 같다).
const double kOldMaidCardAspect = 92 / 64;

/// 겹쳐 펼친 부채꼴 손패의 기하. 카드가 몇 장이든 [area] 안에 한 줄로 들어간다.
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

  /// 이웃 카드 간격. 넉넉하면 카드 폭의 86.5%(54px 카드에서 46.7px), 많으면 줄여서 한 줄에 맞춘다.
  double get step {
    if (count <= 1) return 0;
    return math.min(cardW * 0.865, (area.width - cardW) / (count - 1));
  }

  double get spanWidth => cardW + step * math.max(0, count - 1);
  double get startX => area.left + (area.width - spanWidth) / 2;

  /// -1(왼쪽 끝)…1(오른쪽 끝).
  double _t(int i) => count <= 1 ? 0 : i / (count - 1) * 2 - 1;

  /// 부채꼴이 휘는 정도(가장자리 카드가 내려가거나 올라가는 px).
  double get _arc =>
      (flipped ? 9.0 : 8.0) * math.min(1.0, math.max(0, count - 1) / 4);

  /// 가장자리 카드의 기울기: 6장 11°, 7장 13°를 넘지 않는다.
  double get _maxAngle => math.min(13, 1.9 * count) * math.pi / 180;

  /// i번째 카드의 기울기(라디안).
  double angleOf(int i) => _t(i) * _maxAngle * (flipped ? -1 : 1);

  /// 회전 중심: 상대 부채꼴은 위 가운데, 내 부채꼴은 아래 가운데에 핀을 꽂은 듯 돈다.
  Alignment get pivot => flipped ? Alignment.topCenter : Alignment.bottomCenter;

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

/// 한 화면 배치(스크롤 없음): 상대 캡슐 → 상대 부채꼴 → 가운데 무대 → 내 부채꼴 → 내 캡슐 → 주 버튼.
/// 시안(390×680)의 간격을 기준으로, 높이가 모자라면 간격부터 줄이고 카드도 같이 줄인다.
@immutable
class OldMaidTableLayout {
  final Size size;
  final double cardW;
  final double stageCardW;
  final Rect oppBar;
  final Rect oppFan;

  /// 가운데 무대(버린 짝 · 안내 · 타이머가 한 줄로 든 둥근 상자).
  final Rect panel;
  final Rect caption;
  final Rect myFan;
  final Rect myBar;
  final Rect dock;

  const OldMaidTableLayout._({
    required this.size,
    required this.cardW,
    required this.stageCardW,
    required this.oppBar,
    required this.oppFan,
    required this.panel,
    required this.caption,
    required this.myFan,
    required this.myBar,
    required this.dock,
  });

  factory OldMaidTableLayout.of(Size size) {
    final w = size.width, h = size.height;
    final cw = (h * 0.078).clamp(38.0, 58.0);
    final ch = cw * kOldMaidCardAspect;
    const capH = 48.0, dockH = 56.0, captionH = 22.0;
    final fanH = ch + 30;
    final panelH = (h * 0.231).clamp(112.0, 164.0);
    final elements = capH + fanH + panelH + captionH + fanH + capH + dockH;
    // 위 여백 8과 무대~문구 14는 고정. 나머지 여섯 틈은 시안 비율(11:27:29:9:12:28)로 나눈다.
    const fixed = 8.0 + 14.0;
    const weights = [11.0, 27.0, 29.0, 9.0, 12.0, 28.0];
    final spare = math.max(0.0, h - elements - fixed);
    final k = spare / 116;
    final g = [for (final x in weights) x * k];

    var y = 8.0;
    final oppBar = Rect.fromLTWH(0, y, w, capH);
    y = oppBar.bottom + g[0];
    final oppFan = Rect.fromLTWH(12, y, w - 24, fanH);
    y = oppFan.bottom + g[1];
    final panel = Rect.fromLTWH(20, y, w - 40, panelH);
    y = panel.bottom + 14;
    final caption = Rect.fromLTWH(20, y, w - 40, captionH);
    y = caption.bottom + g[2];
    final myFan = Rect.fromLTWH(12, y, w - 24, fanH);
    y = myFan.bottom + g[3];
    final myBar = Rect.fromLTWH(0, y, w, capH);
    y = myBar.bottom + g[4];
    final dock = Rect.fromLTWH(20, y, w - 40, dockH);
    return OldMaidTableLayout._(
      size: size,
      cardW: cw,
      stageCardW: (panelH * 0.53).clamp(52.0, 92.0),
      oppBar: oppBar,
      oppFan: oppFan,
      panel: panel,
      caption: caption,
      myFan: myFan,
      myBar: myBar,
      dock: dock,
    );
  }

  double get stageCardH => stageCardW * kOldMaidCardAspect;

  /// 공개 연출 카드가 서는 자리(무대 한가운데).
  Rect get stage => Rect.fromCenter(
    center: panel.center,
    width: stageCardW,
    height: stageCardH,
  );

  /// 버린 짝 더미 카드 자리(무대 왼쪽, 라벨 위).
  Rect get discardPile {
    final cw = math.min(54.0, cardW);
    final hh = cw * kOldMaidCardAspect;
    // 96px 칸 가운데, 라벨(약 24px)까지 합쳐 세로 가운데.
    final top = panel.center.dy - (hh + 8 + 18) / 2;
    return Rect.fromLTWH(panel.left + 12 + (96 - cw) / 2, top, cw, hh);
  }

  FanGeometry oppFanOf(int count) =>
      FanGeometry(area: oppFan, count: count, cardW: cardW, flipped: true);

  FanGeometry myFanOf(int count) =>
      FanGeometry(area: myFan, count: count, cardW: cardW);
}
