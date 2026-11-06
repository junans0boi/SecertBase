import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'icons.dart';

/// Floating dark snackbar (ds.css `.snack`). Replaces the previous one.
/// Needs a [ScaffoldMessenger] above (MaterialApp provides it).
///
/// ```dart
/// showV2Snack(context, '기록을 남겼어요');
/// showV2Snack(context, '기록을 지웠어요', actionLabel: '되돌리기', onAction: undo);
/// showV2Snack(context, '저장하지 못했어요', tone: V2Tone.err);
/// ```
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showV2Snack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  V2Tone? tone,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.hideCurrentSnackBar();
  final IconData? icon = switch (tone) {
    V2Tone.ok => V2Icons.ok,
    V2Tone.err => V2Icons.error,
    V2Tone.warn => V2Icons.warn,
    _ => null,
  };
  final Color iconColor = switch (tone) {
    V2Tone.ok => const Color(0xFF8FE0B4),
    V2Tone.err => const Color(0xFFFF9B9B),
    V2Tone.warn => const Color(0xFFF5C978),
    _ => Colors.white,
  };
  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: V2Colors.snack,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.buttonAll),
      duration:
          duration ??
          (actionLabel != null
              ? const Duration(seconds: 6)
              : const Duration(seconds: 4)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  message,
                  style: V2Text.buttonSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar(
                    reason: SnackBarClosedReason.action,
                  );
                  onAction?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: V2Colors.roseSoft,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: V2Text.buttonSm,
                ),
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    ),
  );
}
