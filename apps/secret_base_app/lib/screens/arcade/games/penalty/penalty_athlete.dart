import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 선수 한 명의 유니폼(팀 색 + 등번호).
@immutable
class PenaltyKit {
  final Color color;
  final int number;

  const PenaltyKit({required this.color, required this.number});

  @override
  bool operator ==(Object other) =>
      other is PenaltyKit && other.color == color && other.number == number;

  @override
  int get hashCode => Object.hash(color, number);
}

/// 관절 15개짜리 2D 자세. 단위는 키(1.0), 원점은 골반 아래 땅, y는 아래가 +.
@immutable
class AthletePose {
  final List<Offset> j;

  const AthletePose(this.j);

  static const head = 0,
      neck = 1,
      shL = 2,
      shR = 3,
      elL = 4,
      elR = 5,
      haL = 6,
      haR = 7,
      pelvis = 8,
      hipL = 9,
      hipR = 10,
      knL = 11,
      knR = 12,
      ftL = 13,
      ftR = 14;

  Offset operator [](int i) => j[i];

  AthletePose lerp(AthletePose b, double t) {
    if (t <= 0) return this;
    if (t >= 1) return b;
    return AthletePose([
      for (int i = 0; i < j.length; i++) Offset.lerp(j[i], b.j[i], t)!,
    ]);
  }

  /// 좌우를 뒤집는다(왼쪽 다이브 = 오른쪽 다이브의 거울).
  AthletePose mirrored() {
    Offset m(Offset o) => Offset(-o.dx, o.dy);
    const swap = [0, 1, 3, 2, 5, 4, 7, 6, 8, 10, 9, 12, 11, 14, 13];
    return AthletePose([for (final s in swap) m(j[s])]);
  }

  AthletePose shifted(Offset d) => AthletePose([for (final o in j) o + d]);
}

AthletePose _p(List<double> v) =>
    AthletePose([for (int i = 0; i < v.length; i += 2) Offset(v[i], v[i + 1])]);

/// 키커(뒤에서 본 모습, 오른발잡이: 화면 오른쪽 다리가 차는 발).
abstract final class KickerPoses {
  // head, neck, shL, shR, elL, elR, haL, haR, pelvis, hipL, hipR, knL, knR, ftL, ftR
  static final ready = _p([
    0, -0.925, 0, -0.848, -0.118, -0.805, 0.118, -0.805, //
    -0.168, -0.655, 0.168, -0.655, -0.19, -0.515, 0.19, -0.515, //
    0, -0.5, -0.058, -0.5, 0.058, -0.5, -0.085, -0.272, 0.085, -0.272, //
    -0.1, -0.035, 0.1, -0.035,
  ]);
  static final run1 = _p([
    0.01, -0.9, 0.01, -0.825, -0.11, -0.785, 0.125, -0.79, //
    -0.15, -0.64, 0.19, -0.7, -0.12, -0.56, 0.16, -0.8, //
    0, -0.49, -0.056, -0.49, 0.056, -0.49, -0.075, -0.3, 0.08, -0.26, //
    -0.06, -0.09, 0.075, -0.24,
  ]);
  static final run2 = run1.mirrored().shifted(const Offset(0.02, 0));
  static final plant = _p([
    -0.02, -0.905, -0.015, -0.83, -0.13, -0.79, 0.11, -0.8, //
    -0.27, -0.72, 0.2, -0.64, -0.38, -0.7, 0.22, -0.52, //
    0, -0.49, -0.058, -0.49, 0.058, -0.49, -0.095, -0.27, 0.11, -0.34, //
    -0.1, -0.035, 0.12, -0.5,
  ]);
  static final strike = _p([
    -0.03, -0.91, -0.025, -0.835, -0.135, -0.79, 0.105, -0.805, //
    -0.29, -0.74, 0.2, -0.66, -0.4, -0.74, 0.25, -0.56, //
    0, -0.5, -0.058, -0.5, 0.058, -0.5, -0.1, -0.272, 0.07, -0.27, //
    -0.1, -0.035, 0.035, -0.06,
  ]);
  static final follow = _p([
    -0.04, -0.935, -0.035, -0.857, -0.15, -0.81, 0.095, -0.83, //
    -0.31, -0.8, 0.18, -0.72, -0.42, -0.82, 0.26, -0.66, //
    0, -0.52, -0.058, -0.52, 0.058, -0.52, -0.1, -0.29, 0.05, -0.44, //
    -0.1, -0.035, 0.01, -0.56,
  ]);
  static final celebrate = _p([
    0, -0.94, 0, -0.86, -0.12, -0.82, 0.12, -0.82, //
    -0.22, -0.96, 0.22, -0.96, -0.3, -1.12, 0.3, -1.12, //
    0, -0.51, -0.058, -0.51, 0.058, -0.51, -0.1, -0.28, 0.1, -0.28, //
    -0.12, -0.035, 0.12, -0.035,
  ]);
  static final despair = _p([
    0, -0.91, 0, -0.835, -0.118, -0.795, 0.118, -0.795, //
    -0.22, -0.9, 0.22, -0.9, -0.05, -0.97, 0.05, -0.97, //
    0, -0.49, -0.058, -0.49, 0.058, -0.49, -0.08, -0.27, 0.08, -0.27, //
    -0.09, -0.035, 0.09, -0.035,
  ]);
}

/// 키퍼(앞에서 본 모습). 오른쪽 다이브 자세를 기준으로 왼쪽은 거울.
abstract final class KeeperPoses {
  static final ready = _p([
    0, -0.87, 0, -0.79, -0.125, -0.75, 0.125, -0.75, //
    -0.26, -0.63, 0.26, -0.63, -0.31, -0.5, 0.31, -0.5, //
    0, -0.46, -0.062, -0.46, 0.062, -0.46, -0.18, -0.26, 0.18, -0.26, //
    -0.15, -0.035, 0.15, -0.035,
  ]);
  static final set = _p([
    0, -0.83, 0, -0.75, -0.125, -0.71, 0.125, -0.71, //
    -0.27, -0.6, 0.27, -0.6, -0.33, -0.48, 0.33, -0.48, //
    0, -0.42, -0.062, -0.42, 0.062, -0.42, -0.21, -0.24, 0.21, -0.24, //
    -0.17, -0.035, 0.17, -0.035,
  ]);

  /// 몸을 쭉 편 다이브(아직 회전 전, 팔이 머리 위). 오른쪽으로 기울일 것.
  static final stretch = _p([
    0.02, -0.93, 0.015, -0.85, -0.1, -0.83, 0.13, -0.81, //
    -0.05, -1.03, 0.14, -1.0, 0.02, -1.2, 0.1, -1.21, //
    0, -0.5, -0.06, -0.5, 0.06, -0.5, -0.07, -0.27, 0.12, -0.3, //
    -0.06, -0.035, 0.16, -0.1,
  ]);
  static final lying = _p([
    0.02, -0.92, 0.015, -0.84, -0.11, -0.82, 0.13, -0.8, //
    -0.08, -1.0, 0.15, -0.98, 0.0, -1.16, 0.12, -1.17, //
    0, -0.5, -0.06, -0.5, 0.06, -0.5, -0.06, -0.27, 0.13, -0.29, //
    -0.04, -0.035, 0.22, -0.12,
  ]);
  static final jump = _p([
    0, -0.93, 0, -0.85, -0.12, -0.82, 0.12, -0.82, //
    -0.16, -1.02, 0.16, -1.02, -0.1, -1.2, 0.1, -1.2, //
    0, -0.5, -0.06, -0.5, 0.06, -0.5, -0.13, -0.3, 0.13, -0.3, //
    -0.1, -0.11, 0.1, -0.11,
  ]);
  static final catchBall = _p([
    0, -0.9, 0, -0.82, -0.125, -0.78, 0.125, -0.78, //
    -0.19, -0.66, 0.19, -0.66, -0.055, -0.74, 0.055, -0.74, //
    0, -0.48, -0.062, -0.48, 0.062, -0.48, -0.14, -0.26, 0.14, -0.26, //
    -0.13, -0.035, 0.13, -0.035,
  ]);
  static final blockLow = _p([
    0, -0.74, 0, -0.66, -0.125, -0.63, 0.125, -0.63, //
    -0.19, -0.45, 0.19, -0.45, -0.1, -0.27, 0.1, -0.27, //
    0, -0.36, -0.062, -0.36, 0.062, -0.36, -0.24, -0.2, 0.24, -0.2, //
    -0.26, -0.035, 0.26, -0.035,
  ]);
}

/// 납작한 벡터 운동선수를 그린다. 캔버스는 이미 (발밑 원점, 키=1) 좌표로 옮겨져 있어야 한다.
class AthletePainter {
  static const _skin = Color(0xFFD7A07A);
  static const _skinShade = Color(0xFFB98260);
  static const _hair = Color(0xFF221915);
  static const _boot = Color(0xFF121722);
  static const _lime = Color(0xFFC8F53A);

  static final Map<String, TextPainter> _numbers = {};
  static bool _listening = false;

  /// [front]가 참이면 앞모습(키퍼), 아니면 뒷모습(키커).
  static void paint(
    Canvas canvas,
    AthletePose p,
    PenaltyKit kit, {
    required bool front,
    required bool keeper,
    TextStyle? numberStyle,
  }) {
    final base = kit.color;
    final shirt = keeper
        ? Color.lerp(base, const Color(0xFF0B1020), 0.32)!
        : base;
    final shirtLight = Color.lerp(shirt, Colors.white, 0.22)!;
    final shirtDark = Color.lerp(shirt, Colors.black, 0.35)!;
    final shorts = keeper ? const Color(0xFF151B2B) : const Color(0xFFF2F5FA);
    final shortsShade = keeper
        ? const Color(0xFF0C101B)
        : const Color(0xFFC9D1DE);
    final socks = keeper ? const Color(0xFF151B2B) : base;
    final trim = keeper ? _lime : Colors.white;

    // 다리(먼 쪽을 조금 어둡게).
    for (final left in [true, false]) {
      final far = front ? !left : left;
      final hip = p[left ? AthletePose.hipL : AthletePose.hipR];
      final knee = p[left ? AthletePose.knL : AthletePose.knR];
      final foot = p[left ? AthletePose.ftL : AthletePose.ftR];
      final skin = far ? _skinShade : _skin;
      _limb(canvas, hip, knee, 0.088, 0.066, skin);
      _limb(canvas, knee, foot, 0.064, 0.046, skin);
      final sockTop = Offset.lerp(knee, foot, 0.22)!;
      _limb(
        canvas,
        sockTop,
        foot,
        0.068,
        0.05,
        far ? Color.lerp(socks, Colors.black, 0.2)! : socks,
      );
      // 양말 띠.
      _band(
        canvas,
        Offset.lerp(knee, foot, 0.27)!,
        Offset.lerp(knee, foot, 0.33)!,
        0.066,
        keeper ? Color.lerp(base, Colors.white, 0.1)! : Colors.white,
      );
      // 축구화.
      final dir = (foot - knee);
      final n = dir.distance == 0 ? const Offset(0, 1) : dir / dir.distance;
      final toe = front
          ? foot + Offset(left ? -0.025 : 0.025, 0.03)
          : foot + n * 0.018;
      _limb(canvas, foot, toe, 0.06, 0.052, _boot);
      if (!front) {
        canvas.drawCircle(foot + n * 0.012, 0.012, Paint()..color = _lime);
      }
    }

    // 반바지.
    final hipL = p[AthletePose.hipL];
    final hipR = p[AthletePose.hipR];
    final thighL = Offset.lerp(hipL, p[AthletePose.knL], 0.46)!;
    final thighR = Offset.lerp(hipR, p[AthletePose.knR], 0.46)!;
    _limb(canvas, hipL, thighL, 0.12, 0.105, shortsShade);
    _limb(canvas, hipR, thighR, 0.12, 0.105, shorts);
    final waist = Path()
      ..moveTo(hipL.dx - 0.07, hipL.dy - 0.045)
      ..lineTo(hipR.dx + 0.07, hipR.dy - 0.045)
      ..lineTo(hipR.dx + 0.06, hipR.dy + 0.06)
      ..lineTo(hipL.dx - 0.06, hipL.dy + 0.06)
      ..close();
    canvas.drawPath(waist, Paint()..color = shorts);
    // 반바지 옆선.
    final stripe = Paint()
      ..color = keeper ? _lime.withValues(alpha: 0.8) : base
      ..strokeWidth = 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(hipL.dx - 0.066, hipL.dy - 0.03),
      thighL + const Offset(-0.05, 0),
      stripe,
    );
    canvas.drawLine(
      Offset(hipR.dx + 0.066, hipR.dy - 0.03),
      thighR + const Offset(0.05, 0),
      stripe,
    );

    void arms() {
      for (final left in [true, false]) {
        final far = front ? !left : left;
        final sh = p[left ? AthletePose.shL : AthletePose.shR];
        final el = p[left ? AthletePose.elL : AthletePose.elR];
        final ha = p[left ? AthletePose.haL : AthletePose.haR];
        final sleeve = far ? shirtDark : shirt;
        if (keeper) {
          _limb(canvas, sh, el, 0.078, 0.064, sleeve);
          _limb(canvas, el, ha, 0.062, 0.052, sleeve);
          // 장갑.
          final g =
              ha + (ha - el) / math.max(0.001, (ha - el).distance) * 0.025;
          canvas.drawCircle(g, 0.058, Paint()..color = Colors.white);
          canvas.drawCircle(
            g,
            0.058,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.014
              ..color = const Color(0xFFDDE3EC),
          );
          _band(
            canvas,
            Offset.lerp(el, ha, 0.74)!,
            Offset.lerp(el, ha, 0.86)!,
            0.064,
            _lime,
          );
        } else {
          final skin = far ? _skinShade : _skin;
          final cuff = Offset.lerp(sh, el, 0.5)!;
          _limb(canvas, cuff, el, 0.054, 0.046, skin);
          _limb(canvas, el, ha, 0.046, 0.036, skin);
          canvas.drawCircle(ha, 0.03, Paint()..color = skin);
          _limb(canvas, sh, cuff, 0.084, 0.072, sleeve);
          _band(canvas, Offset.lerp(sh, el, 0.43)!, cuff, 0.074, trim);
        }
      }
    }

    if (!front) arms();

    // 몸통(유니폼).
    final neck = p[AthletePose.neck];
    final shL = p[AthletePose.shL];
    final shR = p[AthletePose.shR];
    final torso = Path()
      ..moveTo(neck.dx - 0.045, neck.dy + 0.004)
      ..quadraticBezierTo(
        shL.dx + 0.01,
        shL.dy - 0.03,
        shL.dx - 0.036,
        shL.dy + 0.03,
      )
      ..lineTo(shL.dx - 0.01, shL.dy + 0.13)
      ..quadraticBezierTo(
        hipL.dx - 0.045,
        (shL.dy + hipL.dy) / 2 + 0.08,
        hipL.dx - 0.068,
        hipL.dy - 0.02,
      )
      ..lineTo(hipR.dx + 0.068, hipR.dy - 0.02)
      ..quadraticBezierTo(
        hipR.dx + 0.045,
        (shR.dy + hipR.dy) / 2 + 0.08,
        shR.dx + 0.01,
        shR.dy + 0.13,
      )
      ..lineTo(shR.dx + 0.036, shR.dy + 0.03)
      ..quadraticBezierTo(
        shR.dx - 0.01,
        shR.dy - 0.03,
        neck.dx + 0.045,
        neck.dy + 0.004,
      )
      ..close();
    final bounds = torso.getBounds();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [shirtLight, shirt, shirtDark],
          stops: const [0, 0.45, 1],
        ).createShader(bounds),
    );
    // 어깨 트림.
    final trimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round
      ..color = trim.withValues(alpha: 0.9);
    canvas.drawPath(
      Path()
        ..moveTo(neck.dx - 0.045, neck.dy + 0.006)
        ..quadraticBezierTo(
          shL.dx + 0.01,
          shL.dy - 0.026,
          shL.dx - 0.03,
          shL.dy + 0.028,
        ),
      trimPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(neck.dx + 0.045, neck.dy + 0.006)
        ..quadraticBezierTo(
          shR.dx - 0.01,
          shR.dy - 0.026,
          shR.dx + 0.03,
          shR.dy + 0.028,
        ),
      trimPaint,
    );
    // 옷깃.
    final collar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.016
      ..strokeCap = StrokeCap.round
      ..color = trim;
    if (front) {
      canvas.drawPath(
        Path()
          ..moveTo(neck.dx - 0.04, neck.dy + 0.006)
          ..lineTo(neck.dx, neck.dy + 0.05)
          ..lineTo(neck.dx + 0.04, neck.dy + 0.006),
        collar,
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
          center: neck + const Offset(0, -0.004),
          width: 0.09,
          height: 0.03,
        ),
        0.15,
        math.pi - 0.3,
        false,
        collar,
      );
    }
    // 등번호(뒤) / 가슴 번호(앞).
    final pelvis = p[AthletePose.pelvis];
    final mid = Offset.lerp(neck, pelvis, front ? 0.3 : 0.44)!;
    final tp = _number(
      '${kit.number}',
      front ? 0.075 : 0.19,
      keeper ? _lime : Colors.white,
      numberStyle,
    );
    final at = front ? mid + const Offset(0.045, 0) : mid;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final s = (front ? 0.075 : 0.19) / 100;
    canvas.scale(s);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();

    if (front) arms();

    // 목 + 머리.
    final head = p[AthletePose.head];
    _limb(canvas, neck + const Offset(0, 0.01), head, 0.05, 0.05, _skinShade);
    const r = 0.068;
    canvas.drawCircle(head, r, Paint()..color = _skin);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: head, radius: r)));
    if (front) {
      canvas.drawCircle(
        head + const Offset(0, -0.05),
        r * 0.9,
        Paint()..color = _hair,
      );
      // 얼굴 그늘(조명 반대쪽).
      canvas.drawCircle(
        head + const Offset(r * 1.25, 0.01),
        r,
        Paint()..color = const Color(0x22000000),
      );
    } else {
      canvas.drawCircle(
        head + const Offset(0, -0.016),
        r * 1.0,
        Paint()..color = _hair,
      );
    }
    canvas.restore();
    if (!front) {
      canvas.drawOval(
        Rect.fromCenter(
          center: head + const Offset(-r * 0.98, 0.008),
          width: 0.022,
          height: 0.034,
        ),
        Paint()..color = _skinShade,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: head + const Offset(r * 0.98, 0.008),
          width: 0.022,
          height: 0.034,
        ),
        Paint()..color = _skinShade,
      );
    }
  }

  static TextPainter _number(
    String n,
    double size,
    Color color,
    TextStyle? style,
  ) {
    if (!_listening) {
      // 웹 폰트가 늦게 도착하면 등번호를 다시 잰다.
      _listening = true;
      PaintingBinding.instance.systemFonts.addListener(_numbers.clear);
    }
    final key = '$n|${color.toARGB32()}';
    final hit = _numbers[key];
    if (hit != null) return hit;
    if (_numbers.length > 24) _numbers.clear();
    final tp = TextPainter(
      text: TextSpan(
        text: n,
        style: (style ?? const TextStyle(fontWeight: FontWeight.w900)).copyWith(
          fontSize: 100,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _numbers[key] = tp;
  }

  /// 끝이 각진 띠(소매·양말 줄무늬).
  static void _band(Canvas canvas, Offset a, Offset b, double w, Color c) {
    final d = b - a;
    final len = d.distance;
    if (len < 1e-4) return;
    final n = Offset(-d.dy, d.dx) / len * (w / 2);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx + n.dx, a.dy + n.dy)
        ..lineTo(b.dx + n.dx, b.dy + n.dy)
        ..lineTo(b.dx - n.dx, b.dy - n.dy)
        ..lineTo(a.dx - n.dx, a.dy - n.dy)
        ..close(),
      Paint()..color = c,
    );
  }

  /// 끝이 둥근 테이퍼 막대(팔·다리).
  static void _limb(
    Canvas canvas,
    Offset a,
    Offset b,
    double wa,
    double wb,
    Color c,
  ) {
    final paint = Paint()..color = c;
    final d = b - a;
    final len = d.distance;
    if (len < 1e-4) {
      canvas.drawCircle(a, math.max(wa, wb) / 2, paint);
      return;
    }
    final n = Offset(-d.dy, d.dx) / len;
    final path = Path()
      ..moveTo(a.dx + n.dx * wa / 2, a.dy + n.dy * wa / 2)
      ..lineTo(b.dx + n.dx * wb / 2, b.dy + n.dy * wb / 2)
      ..lineTo(b.dx - n.dx * wb / 2, b.dy - n.dy * wb / 2)
      ..lineTo(a.dx - n.dx * wa / 2, a.dy - n.dy * wa / 2)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(a, wa / 2, paint);
    canvas.drawCircle(b, wb / 2, paint);
  }
}
