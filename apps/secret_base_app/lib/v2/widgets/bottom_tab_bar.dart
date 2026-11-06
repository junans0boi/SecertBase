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
  });

  /// 홈 · 기록 · 지도 · 놀이 · 더보기
  static const defaultItems = [
    V2TabItem(label: '홈', icon: Icons.home_outlined, activeIcon: V2Icons.home),
    V2TabItem(
      label: '기록',
      icon: Icons.auto_stories_outlined,
      activeIcon: V2Icons.record,
    ),
    V2TabItem(label: '지도', icon: Icons.map_outlined, activeIcon: V2Icons.map),
    V2TabItem(
      label: '놀이',
      icon: Icons.sports_esports_outlined,
      activeIcon: V2Icons.play,
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

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final duration = V2Motion.of(context, V2Motion.fast);
    return Material(
      color: p.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.line)),
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
    required this.duration,
    required this.onTap,
  });

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
    final color = selected ? p.primary : p.muted;
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
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              AnimatedContainer(
                duration: duration,
                width: selected ? 28 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        icon,
                        if (hasBadge)
                          Positioned(
                            top: -4,
                            left: 16,
                            child: V2Badge(count: badge),
                          )
                        else if (dot)
                          Positioned(
                            top: -1,
                            right: -3,
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
