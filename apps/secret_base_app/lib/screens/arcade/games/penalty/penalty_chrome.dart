import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/game_sfx/game_sfx.dart';

/// 패널티킥 로비·결과 화면이 같이 쓰는 "야간 방송" 톤(목업 안 A).
/// 경기 화면(피치·HUD)은 그대로 두고, 그 앞뒤 화면만 이 팔레트로 맞춘다.
abstract final class PenaltyNight {
  static const bg = Color(0xFF070B14);
  static const glow = Color(0xFF14223A);
  static const panel = Color(0x0FFFFFFF); // white 6%
  static const line = Color(0x21FFFFFF); // white 13%
  static const ink = Color(0xFFF1F5FA);
  static const sub = Color(0xFF8A97AB);
  static const accent = Color(0xFFD3F34A);
  static const accentInk = Color(0xFF0B1200);
  static const opponent = Color(0xFFFF6B5B);
  static const me = Color(0xFFE4ECF8);

  /// UI 서체: Noto Sans KR. [spacing]은 em 단위(CSS letter-spacing과 같다).
  static TextStyle ui(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w700,
    double spacing = 0,
    double? height,
  }) => GoogleFonts.notoSansKr(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: spacing * size,
    height: height,
  );

  /// "승리!" 같은 큰 제목용 Black Han Sans.
  static TextStyle display(double size, {Color color = ink}) =>
      GoogleFonts.blackHanSans(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w400,
        height: 1.15,
      );

  static BoxDecoration card({double radius = 20}) => BoxDecoration(
    color: panel,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: line),
  );
}

/// 밤 하늘색 바탕 + 위쪽 투광등 빛.
class PenaltyNightBackdrop extends StatelessWidget {
  final Widget child;

  const PenaltyNightBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: PenaltyNight.bg),
        const RepaintBoundary(child: CustomPaint(painter: _GlowPainter())),
        child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // radial-gradient(80% 36% at 50% 0, glow 0, transparent 70%)
    final rx = size.width * 0.8;
    final ry = size.height * 0.36;
    canvas.save();
    canvas.translate(size.width / 2, 0);
    canvas.scale(1, ry / rx);
    final rect = Rect.fromCircle(center: Offset.zero, radius: rx);
    canvas.drawRect(
      Rect.fromLTRB(-size.width, 0, size.width, rx),
      Paint()
        ..shader = const RadialGradient(
          colors: [PenaltyNight.glow, Color(0x0014223A)],
          stops: [0, 0.7],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 얇은 상단바: 뒤로 / 제목 + 칸 수 칩 / 규칙 / 소리.
class PenaltyTopBar extends StatelessWidget {
  final String chip;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const PenaltyTopBar({
    super.key,
    required this.chip,
    required this.onBack,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _BarButton(
              tooltip: '게임 나가기',
              icon: Icons.chevron_left_rounded,
              size: 30,
              onPressed: onBack,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '패널티킥',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PenaltyNight.ui(
                          17,
                          weight: FontWeight.w800,
                          spacing: -0.02,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PenaltyNight.line),
                      ),
                      child: Text(
                        chip,
                        style: PenaltyNight.ui(
                          12,
                          color: PenaltyNight.sub,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onHelp != null)
              _BarButton(
                tooltip: '규칙 보기',
                icon: Icons.help_outline_rounded,
                size: 22,
                onPressed: onHelp,
              ),
            const _MuteBarButton(),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: size, color: PenaltyNight.sub),
        onPressed: onPressed,
      ),
    );
  }
}

class _MuteBarButton extends StatefulWidget {
  const _MuteBarButton();

  @override
  State<_MuteBarButton> createState() => _MuteBarButtonState();
}

class _MuteBarButtonState extends State<_MuteBarButton> {
  @override
  void initState() {
    super.initState();
    // 저장된 음소거 설정만 읽어 온다(소리는 미리 만들지 않는다).
    GameSfx.instance.init(const []).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final sfx = GameSfx.instance;
    return _BarButton(
      tooltip: sfx.muted ? '소리 켜기' : '소리 끄기',
      icon: sfx.muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
      size: 22,
      onPressed: () async {
        await sfx.setMuted(!sfx.muted);
        if (!sfx.muted) sfx.play(GameSound.tap);
        if (mounted) setState(() {});
      },
    );
  }
}

/// 하단 단일 주 버튼(형광 노랑 단색). [onPressed]가 없으면 비활성 톤.
class PenaltyMainButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PenaltyMainButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: enabled ? PenaltyNight.accent : PenaltyNight.panel,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PenaltyNight.ui(
                    17,
                    weight: FontWeight.w800,
                    color: enabled ? PenaltyNight.accentInk : PenaltyNight.sub,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
