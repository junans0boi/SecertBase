import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart';

/// A button row entry for [showV2Dialog].
class V2DialogAction<T> {
  const V2DialogAction({
    required this.label,
    this.value,
    this.variant = V2ButtonVariant.primary,
  });

  final String label;

  /// Returned from the dialog when tapped.
  final T? value;
  final V2ButtonVariant variant;
}

/// Centered 2.0 dialog (ds.css `.dialog`). Actions stack full width,
/// first = primary. Prefer sheets for anything longer than two sentences.
///
/// ```dart
/// final choice = await showV2Dialog<String>(context,
///   title: '사진을 저장했어요',
///   message: '앨범에서 확인할 수 있어요.',
///   actions: const [V2DialogAction(label: '확인', value: 'ok')],
/// );
/// ```
Future<T?> showV2Dialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  List<V2DialogAction<T>> actions = const [],
  bool barrierDismissible = true,
  IconData? icon,
  V2Tone iconTone = V2Tone.rose,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: V2Colors.scrim,
    barrierLabel: '닫기',
    builder: (ctx) => V2Theme(
      child: Builder(
        builder: (ctx) {
          final p = V2Palette.of(ctx);
          final tone = V2ToneColors.of(iconTone);
          return Dialog(
            backgroundColor: p.surface,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (icon != null) ...[
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: tone.soft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(icon, color: tone.base, size: 28),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: V2Text.head.copyWith(color: p.ink),
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: V2Text.body.copyWith(color: p.sub),
                        ),
                      ],
                      if (content != null) ...[
                        const SizedBox(height: 16),
                        content,
                      ],
                      const SizedBox(height: 20),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        V2Button(
                          label: actions[i].label,
                          variant: actions[i].variant,
                          onPressed: () =>
                              Navigator.of(ctx).pop(actions[i].value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Yes/no confirmation. Returns true only when confirmed.
///
/// ```dart
/// if (await showV2Confirm(context, title: '기록을 지울까요?',
///     message: '지운 기록은 되돌릴 수 없어요.', confirmLabel: '지우기', destructive: true)) {
///   await delete();
/// }
/// ```
Future<bool> showV2Confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool destructive = false,
}) async {
  final result = await showV2Dialog<bool>(
    context,
    title: title,
    message: message,
    actions: [
      V2DialogAction(
        label: confirmLabel,
        value: true,
        variant: destructive ? V2ButtonVariant.danger : V2ButtonVariant.primary,
      ),
      V2DialogAction(
        label: cancelLabel,
        value: false,
        variant: V2ButtonVariant.text,
      ),
    ],
  );
  return result ?? false;
}
