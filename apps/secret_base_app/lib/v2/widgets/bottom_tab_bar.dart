import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'badge.dart';
import 'icons.dart';

/// One tab of [V2BottomTabBar].
class V2TabItem {
  const V2TabItem({required this.label, required this.icon, this.activeIcon});
  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

/// 5-tab bottom bar with Korean labels and a rose top indicator
/// (ds.css `.tabbar`). Widget only; navigation state lives in the shell.
///
/// ```dart
/// V2BottomTabBar(
///   currentIndex: index,
///   onTap: (i) => setState(() => index = i),
///   badges: const {1: 2},      // 기록 탭에 2
///   dots: const {4},           // 더보기 탭에 점
/// )
/// ```
class V2BottomTabBar extends StatelessWidget {
  const V2BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = defaultItems,
    this.badges = const {},
    this.dots = const {},
    this.dark = false,
  });

  /// 홈 · 기록 · 지도 · 놀이 · 더보기
  static const defaultItems = [
    V2TabItem(
      label: '홈',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    V2TabItem(
      label: '기록',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
    ),
    V2TabItem(
      label: '지도',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
    V2TabItem(
      label: '놀이',
      icon: Icons.sports_esports_outlined,
      activeIcon: Icons.sports_esports_rounded,
    ),
    V2TabItem(label: '더보기', icon: V2Icons.more, activeIcon: V2Icons.more),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<V2TabItem> items;

  /// Tab index → unread count.
  final Map<int, int> badges;

  /// Tab indexes showing an unread dot.
  final Set<int> dots;

  /// Black bar for full-bleed photo tabs (기록).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final duration = V2Motion.of(context, V2Motion.fast);
    return Material(
      color: dark ? const Color(0xFF0C0C0E) : p.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark ? Colors.white.withValues(alpha: .08) : p.line,
            ),
          ),
          boxShadow: p.dark || dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0F3C1428),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _Tab(
                      item: items[i],
                      selected: i == currentIndex,
                      index: i,
                      count: items.length,
                      badge: badges[i],
                      dot: dots.contains(i),
                      dark: dark,
                      duration: duration,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.index,
    required this.count,
    required this.badge,
    required this.dot,
    required this.dark,
    required this.duration,
    required this.onTap,
  });

  final bool dark;
  final V2TabItem item;
  final bool selected;
  final int index;
  final int count;
  final int? badge;
  final bool dot;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    // 2.1: the selected tab is ink on a soft pill; the accent stays for
    // content, not navigation.
    final color = dark
        ? (selected ? Colors.white : Colors.white.withValues(alpha: .55))
        : (selected ? p.ink : p.muted);
    final icon = Icon(
      selected ? (item.activeIcon ?? item.icon) : item.icon,
      size: 26,
      color: color,
    );
    final hasBadge = badge != null && badge! > 0;
    final extra = hasBadge ? ', 새 소식 $badge개' : (dot ? ', 새 소식' : '');
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '${item.label}, 탭 ${index + 1}/$count$extra',
      // Same onTap as the InkWell: the label below is excluded, so the
      // semantic tap must be declared here too (Flutter web needs it).
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        hoverColor: p.primary.withValues(alpha: 0.05),
        highlightColor: p.primary.withValues(alpha: 0.08),
        splashColor: p.primary.withValues(alpha: 0.10),
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: duration,
                          width: 56,
                          height: 30,
                          decoration: BoxDecoration(
                            color: !selected
                                ? Colors.transparent
                                : dark
                                ? Colors.white.withValues(alpha: .14)
                                : p.soft2,
                            borderRadius: V2Radius.pillAll,
                          ),
                          alignment: Alignment.center,
                          child: icon,
                        ),
                        if (hasBadge)
                          Positioned(
                            top: -3,
                            left: 32,
                            child: V2Badge(count: badge),
                          )
                        else if (dot)
                          Positioned(
                            top: 2,
                            right: 12,
                            child: V2Badge.dot(borderColor: p.surface),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: 1.2),
                      style: V2Text.label.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
