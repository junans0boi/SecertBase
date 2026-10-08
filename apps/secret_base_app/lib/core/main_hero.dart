import 'package:flutter/material.dart';

import 'main_design.dart';

const kMainCream = Color(0xFFFFF2F6);

const kHeroRoseGrad = LinearGradient(
  colors: [Color(0xFFFF8BBE), Color(0xFFFF6F9F), Color(0xFFFF9670)],
  stops: [0, 0.55, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Gradient hero with soft blobs and a curved bottom edge that melts into the page.
class MainHero extends StatelessWidget {
  final Widget child;
  final Widget? trailing;
  final Gradient gradient;
  final Color curveColor;

  const MainHero({
    super.key,
    required this.child,
    this.trailing,
    this.gradient = kHeroRoseGrad,
    this.curveColor = kMainCream,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: _blob(210, const BorderRadius.all(Radius.circular(120))),
            ),
            Positioned(
              bottom: 10,
              left: -40,
              child: _blob(150, const BorderRadius.all(Radius.circular(80))),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, top + 22, 20, 52),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: child),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: 30,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: curveColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.elliptical(220, 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: radius,
      ),
    );
  }
}

/// Translucent round slot for the mascot in a hero.
class HeroMascot extends StatelessWidget {
  final double size;
  const HeroMascot({super.key, this.size = 108});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(46),
        border: Border.all(color: Colors.white.withAlpha(110), width: 2),
      ),
      child: Center(child: CozyMascot(size: size * 0.86)),
    );
  }
}

/// White page header used by tabs without a hero (MomentLoop, Arcade, More).
class MainTabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final bool safeTop;

  const MainTabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.color = kMainRose,
    this.trailing,
    this.safeTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = safeTop ? MediaQuery.paddingOf(context).top : 0.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 14),
      decoration: const BoxDecoration(
        color: kMainPaper,
        border: Border(bottom: BorderSide(color: kMainLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: mainTitle(size: 30, color: color)),
                if (subtitle != null)
                  Text(subtitle!, style: mainBody(size: 12, color: kMainMuted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
