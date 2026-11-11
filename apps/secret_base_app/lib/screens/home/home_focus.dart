import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/today_api.dart';
import '../../v2/v2.dart';
import 'home_format.dart';

/// Whether today's fortune was opened on this device (home shows a dot and
/// asks once a day). Stored as the local ISO day it was last opened.
abstract final class HomeFortuneSeen {
  static const key = 'home_fortune_seen_day';

  static Future<bool> today() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) == isoDay(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static Future<void> mark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, isoDay(DateTime.now()));
    } catch (_) {}
  }
}

/// The one big "지금 할 일" card on 홈 (2.1). [background] fills the card;
/// text sits on a dark gradient so it is always white.
class HomeFocusCard extends StatelessWidget {
  const HomeFocusCard({
    super.key,
    required this.background,
    required this.kicker,
    required this.title,
    this.sub,
    this.step,
    this.steps = 0,
    this.action,
    this.actionIcon,
    this.onAction,
    this.busy = false,
    this.laterLabel,
    this.onLater,
    this.onTap,
    this.semanticLabel,
  });

  final Widget background;
  final String kicker;
  final String title;
  final String? sub;

  /// 1-based position in today's steps (shows the little progress bars).
  final int? step;
  final int steps;

  final String? action;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool busy;
  final String? laterLabel;
  final VoidCallback? onLater;

  /// Tapping anywhere on the card (used by the finished state).
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const height = 300.0;

  @override
  Widget build(BuildContext context) {
    final accent = V2Colors.rose600;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .34, .5, 1],
                  colors: [
                    Color(0x47000000),
                    Color(0x00000000),
                    Color(0x0D000000),
                    Color(0x8C000000),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kicker,
                          style: V2Text.label.copyWith(
                            color: Colors.white,
                            letterSpacing: 0,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (step != null && steps > 1)
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              for (var i = 1; i <= steps; i++)
                                Container(
                                  width: 16,
                                  height: 4,
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: i <= step!
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: .4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: V2Text.sans(
                      size: 21,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sub!,
                      style: V2Text.cap.copyWith(
                        color: Colors.white.withValues(alpha: .88),
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Pill(
                          label: action!,
                          icon: actionIcon,
                          color: accent,
                          busy: busy,
                          onTap: onAction,
                        ),
                        if (laterLabel != null && onLater != null) ...[
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: onLater,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(44, 44),
                            ),
                            child: Text(
                              laterLabel!,
                              style: V2Text.cap.copyWith(
                                color: Colors.white.withValues(alpha: .85),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.icon,
    this.busy = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = V2Colors.onPrimary;
    return Material(
      color: color,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: on),
                  )
                else if (icon != null)
                  Icon(icon, size: 19, color: on),
                if (busy || icon != null) const SizedBox(width: 8),
                Text(label, style: V2Text.buttonSm.copyWith(color: on)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Network/placeholder fill for a today moment.
Widget homeMomentFill(
  TodayMoment? m, {
  required String? baseUrl,
  required Object seed,
  bool blur = false,
  int? cacheWidth,
}) {
  Widget fill;
  final raw = m?.mediaUrl;
  final url = raw == null || baseUrl == null
      ? null
      : raw.startsWith('http')
      ? raw
      : '$baseUrl$raw';
  if (m != null &&
      !m.deleted &&
      url != null &&
      m.mediaType != 'video' &&
      m.mediaType != 'text') {
    fill = Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => V2PhotoPlaceholder(seed: seed),
    );
  } else {
    fill = V2PhotoPlaceholder(seed: seed);
  }
  if (!blur) return fill;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
    child: Transform.scale(scale: 1.15, child: fill),
  );
}

/// Dark card with a sealed envelope (today's fortune, not opened yet).
class HomeFortuneBackground extends StatelessWidget {
  const HomeFortuneBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF24203A),
      child: Align(
        alignment: const Alignment(.72, -.45),
        child: Transform.rotate(
          angle: -.1,
          child: SizedBox(
            width: 118,
            height: 82,
            child: CustomPaint(painter: _EnvelopePainter(V2Colors.rose600)),
          ),
        ),
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  _EnvelopePainter(this.seal);

  final Color seal;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawShadow(Path()..addRRect(r), Colors.black, 10, false);
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7E7CF), Color(0xFFE8CFA9)],
        ).createShader(Offset.zero & size),
    );
    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height * .58)
      ..close();
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawPath(flap, Paint()..color = const Color(0xFFE2C79E));
    canvas.restore();
    canvas.drawCircle(
      Offset(size.width / 2, size.height * .52),
      11,
      Paint()..color = seal,
    );
  }

  @override
  bool shouldRepaint(_EnvelopePainter old) => old.seal != seal;
}

/// Quiet list row under the focus card.
class HomeRow extends StatelessWidget {
  const HomeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    this.hot = false,
    this.dot = false,
    this.secondaryIcon = false,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;

  /// Sub line in the accent color (something to do).
  final bool hot;

  /// Small accent dot on the icon (not opened yet).
  final bool dot;

  /// Use the blue partner tint instead of the accent.
  final bool secondaryIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final fg = secondaryIcon ? p.partner : p.primary;
    final bg = secondaryIcon ? p.partner.withValues(alpha: .1) : p.primarySoft;
    return Semantics(
      button: onTap != null,
      label: '$title, $sub',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: V2Radius.ctlAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: fg, size: 22),
                      ),
                      if (dot)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: p.point,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.bg, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: V2Text.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.cap.copyWith(
                          color: hot ? p.primary : p.muted,
                          fontWeight: hot ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: p.control),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
