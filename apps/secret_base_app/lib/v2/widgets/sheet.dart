import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';

/// Opens a 2.0 bottom sheet (ds.css `.sheet`): drag handle, optional title
/// and subtitle, scrollable body, optional sticky [actions] at the bottom.
/// Applies the 2.0 theme itself, so it can be called from any screen.
///
/// ```dart
/// final place = await showV2Sheet<Place>(
///   context,
///   title: '장소 추가',
///   builder: (ctx) => PlaceForm(onDone: (p) => Navigator.pop(ctx, p)),
/// );
///
/// showV2Sheet<void>(context, title: '정렬', builder: (_) => ..., actions: [
///   V2Button(label: '적용', onPressed: apply),
/// ]);
/// ```
Future<T?> showV2Sheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  List<Widget> actions = const [],
  bool isDismissible = true,
  bool enableDrag = true,
  bool scrollable = true,
  bool dark = false,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: V2Colors.scrim,
    barrierLabel: '닫기',
    constraints: const BoxConstraints(maxWidth: 560),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (ctx) => V2Theme(
      dark: dark,
      child: V2SheetFrame(
        title: title,
        subtitle: subtitle,
        actions: actions,
        scrollable: scrollable,
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// The sheet chrome used by [showV2Sheet]. Use directly only for custom
/// modal flows.
class V2SheetFrame extends StatelessWidget {
  const V2SheetFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.scrollable = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.9;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Material(
          color: p.surface,
          shape: const RoundedRectangleBorder(borderRadius: V2Radius.sheetTop),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: p.line2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: V2Text.title.copyWith(color: p.ink),
                      ),
                    ),
                  ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text(
                      subtitle!,
                      style: V2Text.body.copyWith(color: p.sub),
                    ),
                  ),
                if (title != null || subtitle != null)
                  const SizedBox(height: 12),
                Flexible(
                  child: scrollable ? SingleChildScrollView(child: body) : body,
                ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          actions[i],
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
