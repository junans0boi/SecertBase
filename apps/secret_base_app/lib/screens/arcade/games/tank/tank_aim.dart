import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 슬링샷식 조준 계산. 손가락을 조준 방향의 '반대쪽'으로 당기면 그 방향으로 쏜다.
/// 그래서 손가락이 궤적 가이드 위가 아니라 탱크 반대편·아래쪽에 놓여 궤적을 가리지 않는다.
class TankAim {
  const TankAim._();

  /// 당김 거리 → 파워 100에 해당하는 픽셀 길이.
  static double reach(Size size) =>
      math.max(80.0, math.min(size.width, size.height) * 0.42);

  /// [pull] = 고정점 − 손가락. 위로 쏠수록 손가락이 아래로 간다.
  static ({double angle, double power}) fromPull(Offset pull, double reach) {
    var angle = math.atan2(-pull.dy, pull.dx) * 180 / math.pi;
    if (angle < 0) angle = pull.dx >= 0 ? 0.0 : 180.0;
    final power = (pull.distance / reach * 100).clamp(1.0, 100.0);
    return (angle: angle.roundToDouble(), power: power.roundToDouble());
  }

  /// 터치 시작 시 현재 각도·파워를 그대로 유지하도록 하는 가상 고정점.
  static Offset anchorFor(
    Offset touch, {
    required double angle,
    required double power,
    required double reach,
  }) {
    final rad = angle * math.pi / 180;
    final len = power / 100 * reach;
    return touch + Offset(math.cos(rad), -math.sin(rad)) * len;
  }
}
