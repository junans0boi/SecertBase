import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icons.dart';

enum V2BannerTone { neutral, info, ok, warn, err }

/// Inline status banner (ds.css `.banner`). Errors and warnings are
/// announced (live region).
///
/// ```dart
/// V2Banner(tone: V2BannerTone.warn, message: '위치 권한이 꺼져 있어요', actionLabel: '설정 열기', onAction: openSettings)
/// V2Banner.offline()
/// V2Banner(tone: V2BannerTone.info, title: '새 기능', message: '...', onDismiss: hide)
/// ```
class V2Banner extends StatelessWidget {
  const V2Banner({
    super.key,
    required this.message,
    this.tone = V2BannerTone.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  /// "인터넷 연결이 끊겼어요" banner for offline states.
  const V2Banner.offline({
    super.key,
    this.message = '인터넷 연결이 끊겼어요. 연결되면 자동으로 다시 불러와요.',
    this.actionLabel,
    this.onAction,
  }) : tone = V2BannerTone.warn,
       title = null,
       icon = V2Icons.offline,
       onDismiss = null;

  final String message;
  final V2BannerTone tone;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a close button ('닫기') when set.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final (V2ToneColors c, IconData defIcon) = switch (tone) {
      V2BannerTone.neutral => (
        V2ToneColors(p.primary, p.soft, p.sub),
        V2Icons.info,
      ),
      V2BannerTone.info => (V2ToneColors.of(V2Tone.sky), V2Icons.info),
      V2BannerTone.ok => (V2ToneColors.of(V2Tone.ok), V2Icons.ok),
      V2BannerTone.warn => (V2ToneColors.of(V2Tone.warn), V2Icons.warn),
      V2BannerTone.err => (V2ToneColors.of(V2Tone.err), V2Icons.error),
    };
    // Dark mode: keep tone soft fills readable with light text.
    final bg = p.dark ? p.soft : c.soft;
    final fg = p.dark ? p.ink : c.text;
    final iconColor = p.dark ? p.primary : c.text;

    return Semantics(
      container: true,
      liveRegion: tone == V2BannerTone.err || tone == V2BannerTone.warn,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 12, onDismiss == null ? 14 : 4, 12),
        decoration: BoxDecoration(color: bg, borderRadius: V2Radius.buttonAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? defIcon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: V2Text.buttonSm.copyWith(
                        color: fg,
                        height: 20 / 14,
                      ),
                    ),
                  Text(
                    message,
                    style: V2Text.body.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      color: fg,
                    ),
                  ),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          minimumSize: const Size(44, 36),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: V2Text.buttonSm.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: '닫기',
                icon: Icon(V2Icons.close, size: 18, color: fg),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
