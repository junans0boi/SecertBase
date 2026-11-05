import 'dart:math' as math;
import 'dart:ui';

import 'tank_data.dart';

/// 화면에 보이는 전장 범위. 칸(cell) 좌표 → 화면 픽셀 변환을 맡는다.
/// 칸 좌표는 서버와 같다: 열 c의 중심이 x=c, 지표면은 y = 40 - 높이 - 0.5.
class TankView {
  /// 화면 왼쪽 끝의 칸 x.
  final double left;

  /// 화면 위쪽 끝의 칸 y(음수면 하늘 위쪽까지 보인다).
  final double top;

  /// 한 칸의 픽셀 크기(가로·세로 같음: 비율이 깨지지 않는다).
  final double scale;

  const TankView(this.left, this.top, this.scale);

  Offset toScreen(double x, double y) =>
      Offset((x - left) * scale, (y - top) * scale);

  Offset toWorld(Offset p) => Offset(p.dx / scale + left, p.dy / scale + top);

  TankView lerpTo(TankView target, double k) => TankView(
    left + (target.left - left) * k,
    top + (target.top - top) * k,
    scale + (target.scale - scale) * k,
  );

  bool closeTo(TankView other) =>
      (left - other.left).abs() < 0.02 &&
      (top - other.top).abs() < 0.02 &&
      (scale - other.scale).abs() < 0.005;
}

class TankCamera {
  TankCamera._();

  /// 화면 [size]와 HUD·조작부가 가리는 위·아래 높이로 목표 시점을 정한다.
  /// [focus]는 칸 좌표의 관심 지점(조준 중인 전차, 날아가는 포탄 등).
  /// [overview]면 전장 가로 전체를 보여준다.
  static TankView target({
    required Size size,
    required double insetTop,
    required double insetBottom,
    required Offset focus,
    bool overview = false,
  }) {
    final w = math.max(1.0, size.width);
    final h = math.max(1.0, size.height);
    final band = math.max(80.0, h - insetTop - insetBottom);
    final fitWidth = w / kTerrainW;

    final double scale;
    if (overview) {
      scale = math.min(fitWidth, band / 18);
    } else {
      // 폰에서는 약 55칸만 보여 전차를 크게, PC처럼 넓은 화면은 전장 전체를 보여준다.
      final desiredCols = w < 600
          ? 55.0
          : w < 900
          ? 75.0
          : 100.0;
      scale = math.max(fitWidth, math.min(band / 22, w / desiredCols));
    }

    final viewCols = w / scale;
    final double left;
    if (viewCols >= kTerrainW) {
      left = -0.5 - (viewCols - kTerrainW) / 2;
    } else {
      left = (focus.dx - viewCols / 2).clamp(-0.5, kTerrainW - 0.5 - viewCols);
    }

    // 세로: 초점을 보이는 띠의 60% 높이에 두되, 땅 밑바닥이 띠 위로 올라오지 않게 한다.
    final focusTop = focus.dy - (insetTop + band * 0.6) / scale;
    final maxTop = kTerrainH - (h - insetBottom) / scale;
    const minTop = -60.0;
    final top = math.min(maxTop, math.max(minTop, focusTop));
    return TankView(left, top, scale);
  }

  /// 프레임 간 부드러운 추적 계수(dt초, 빠르기 [speed]).
  static double smoothing(double dt, {double speed = 6}) =>
      1 - math.exp(-dt * speed);
}
