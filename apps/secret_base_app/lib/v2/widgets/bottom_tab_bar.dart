import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'badge.dart';
import 'icons.dart';

/// One tab of [V2BottomTabBar].
class V2TabItem {
  const V2TabItem({required this.label, required this.icon, this.activeIcon});
  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

/// 5-tab floating pill bar (icons, Korean labels for screen readers and
/// tooltips). Widget only; navigation state lives in the shell, which
/// should set `Scaffold.extendBody` so the page shows around the pill.
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

  /// Height of the floating pill (without the gap under it).
  static const pillHeight = 62.0;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final duration = V2Motion.of(context, V2Motion.fast);
    final glass = dark || p.dark
        ? const Color(0xD91C1C1E)
        : Colors.white.withValues(alpha: .86);
    final edge = dark || p.dark
        ? Colors.white.withValues(alpha: .10)
        : Colors.black.withValues(alpha: .06);
    // A floating glass pill (2.2): the page shows around it, the shell
    // lets 기록 run underneath.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(pillHeight / 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(pillHeight / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: glass,
                    borderRadius: BorderRadius.circular(pillHeight / 2),
                    border: Border.all(color: edge),
                  ),
                  child: SizedBox(
                    height: pillHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
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
                                dark: dark || p.dark,
                                duration: duration,
                                onTap: () => onTap(i),
                              ),
                            ),
                        ],
                      ),
                    ),
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
    // 2.2: icons only (the label stays for screen readers); the selected
    // tab sits on a soft pill inside the floating bar.
    final color = dark
        ? (selected ? Colors.white : Colors.white.withValues(alpha: .6))
        : (selected ? p.ink : p.ink.withValues(alpha: .62));
    final hasBadge = badge != null && badge! > 0;
    final extra = hasBadge ? ', 새 소식 $badge개' : (dot ? ', 새 소식' : '');
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '${item.label}, 탭 ${index + 1}/$count$extra',
      onTap: onTap,
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: InkWell(
          key: Key('v2_tab_$index'),
          onTap: onTap,
          customBorder: const StadiumBorder(),
          hoverColor: color.withValues(alpha: .06),
          highlightColor: color.withValues(alpha: .08),
          splashColor: color.withValues(alpha: .10),
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                color: !selected
                    ? Colors.transparent
                    : dark
                    ? Colors.white.withValues(alpha: .16)
                    : Colors.black.withValues(alpha: .07),
                borderRadius: V2Radius.pillAll,
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    selected ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 27,
                    color: color,
                  ),
                  if (hasBadge)
                    Positioned(top: -6, left: 16, child: V2Badge(count: badge))
                  else if (dot)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: V2Badge.dot(
                        borderColor: dark ? const Color(0xFF1C1C1E) : p.surface,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
