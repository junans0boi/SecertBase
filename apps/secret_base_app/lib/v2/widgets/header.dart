import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'icon_button.dart';
import 'icons.dart';

/// Top bar in three styles (ds.css `.hdr`):
///
/// * tab root: big left title — `V2Header(title: '기록', actions: [...])`
/// * sub page: back + centered title — `V2Header(title: '알림 설정', showBack: true)`
/// * large title: back row + 28px title under it —
///   `V2Header(title: '개인정보·권한', showBack: true, large: true)`
///
/// Usable as `Scaffold.appBar`. When [showBack] is null the back button is
/// shown automatically if the route can pop.
class V2Header extends StatelessWidget implements PreferredSizeWidget {
  const V2Header({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack,
    this.onBack,
    this.actions = const [],
    this.large = false,
    this.backgroundColor,
    this.backTooltip = '뒤로 가기',
  });

  final String title;

  /// Optional caption under the title (tab and large styles).
  final String? subtitle;
  final bool? showBack;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Usually [V2IconButton]s (max 2).
  final List<Widget> actions;
  final bool large;
  final Color? backgroundColor;
  final String backTooltip;

  @override
  Size get preferredSize =>
      Size.fromHeight(large ? 52 + (subtitle == null ? 44 : 64) : 52);

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final back = showBack ?? canPop;
    final backBtn = V2IconButton(
      icon: V2Icons.back,
      size: 22,
      tooltip: backTooltip,
      onPressed: onBack ?? () => Navigator.maybePop(context),
    );
    Widget titleText(TextStyle style, {TextAlign align = TextAlign.start}) =>
        Semantics(
          header: true,
          child: Text(
            title,
            style: style.copyWith(color: p.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
          ),
        );
    Widget? sub() => subtitle == null
        ? null
        : Text(
            subtitle!,
            style: V2Text.cap.copyWith(color: p.sub),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    Widget bar;
    if (large) {
      bar = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [if (back) backBtn, const Spacer(), ...actions],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleText(V2Text.display), ?sub()],
            ),
          ),
        ],
      );
    } else if (back) {
      bar = SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              backBtn,
              Expanded(
                child: titleText(V2Text.headerBack, align: TextAlign.center),
              ),
              if (actions.isEmpty) const SizedBox(width: 44) else ...actions,
            ],
          ),
        ),
      );
    } else {
      bar = SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText(subtitle == null ? V2Text.title : V2Text.head),
                    ?sub(),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      );
    }
    return Material(
      color: backgroundColor ?? p.bg,
      child: SafeArea(bottom: false, child: bar),
    );
  }
}
