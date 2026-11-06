import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icons.dart';

/// Grouped list container with hairline dividers (ds.css `.list`).
///
/// ```dart
/// V2List(children: [
///   V2ListTile(icon: V2Icons.bell, title: '알림', onTap: openNotif),
///   V2ListTile(icon: V2Icons.lock, title: '개인정보·권한', onTap: openPrivacy),
/// ])
/// ```
class V2List extends StatelessWidget {
  const V2List({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, thickness: 1, color: p.line));
      }
      items.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: V2Radius.cardAll,
        border: Border.all(color: p.line),
      ),
      child: ClipRRect(
        borderRadius: V2Radius.cardAll,
        child: Material(
          type: MaterialType.transparency,
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// Settings-style row (ds.css `.li`): icon bubble, title, subtitle,
/// trailing widget or chevron. Min height 56. Whole row is one button.
///
/// ```dart
/// V2ListTile(icon: V2Icons.event, title: '기념일', subtitle: '다음: 500일 · 88일 남음', onTap: open)
/// V2ListTile(title: '알림 받기', trailing: V2Toggle(value: on, onChanged: set, semanticLabel: '알림 받기'))
/// V2ListTile(icon: V2Icons.logout, title: '로그아웃', destructive: true, onTap: logout)
/// ```
class V2ListTile extends StatelessWidget {
  const V2ListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = V2Tone.rose,
    this.leading,
    this.trailing,
    this.showChevron,
    this.destructive = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Icon inside a 36px soft bubble.
  final IconData? icon;

  /// Bubble tone (soft fill + base icon color).
  final V2Tone tone;

  /// Replaces the icon bubble (e.g. a [V2Avatar]).
  final Widget? leading;
  final Widget? trailing;

  /// Defaults to true when [onTap] is set and there is no [trailing].
  final bool? showChevron;

  /// Err-colored title and icon (로그아웃, 탈퇴).
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2ToneColors.of(destructive ? V2Tone.err : tone);
    final titleColor = destructive ? p.err : p.ink;
    final chevron = showChevron ?? (onTap != null && trailing == null);

    final lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.dark ? p.soft : t.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: p.dark ? p.primary : t.base),
              ));

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: V2Text.bodyStrong.copyWith(color: titleColor),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: V2Text.cap.copyWith(color: p.sub),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (chevron)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(V2Icons.chevron, color: p.control, size: 22),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}
