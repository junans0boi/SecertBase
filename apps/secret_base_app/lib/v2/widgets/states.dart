import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart';
import 'icons.dart';
import 'illustration.dart';

/// Empty state (ds.css `.state`): illustration, title, body, one CTA.
///
/// ```dart
/// V2EmptyState(
///   illustration: const V2SceneIllustration(V2Scene.hearts),
///   title: '아직 남긴 기록이 없어요',
///   body: '오늘의 순간을 서윤과 나눠 보세요.',
///   actionLabel: '첫 기록 남기기',
///   onAction: openComposer,
/// )
/// ```
class V2EmptyState extends StatelessWidget {
  const V2EmptyState({
    super.key,
    required this.title,
    this.body,
    this.illustration,
    this.icon = V2Icons.sparkle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// "아직 연결되지 않았어요" preset for features that need a partner.
  const V2EmptyState.unpaired({
    super.key,
    this.title = '아직 연결되지 않았어요',
    this.body = '상대와 연결하면 함께 쓸 수 있어요.',
    this.actionLabel = '연결하러 가기',
    required this.onAction,
  }) : illustration = const V2SceneIllustration(V2Scene.couple),
       icon = V2Icons.couple,
       secondaryLabel = null,
       onSecondary = null;

  final String title;
  final String? body;

  /// Defaults to a [V2Art] with [icon].
  final Widget? illustration;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              illustration ?? V2Art(icon: icon),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: V2Text.head.copyWith(color: p.ink),
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: V2Text.body.copyWith(color: p.sub),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                V2Button(
                  label: actionLabel!,
                  onPressed: onAction,
                  size: V2ButtonSize.sm,
                ),
              ],
              if (secondaryLabel != null)
                V2Button(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                  variant: V2ButtonVariant.text,
                  fullWidth: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with retry. Message is announced.
///
/// ```dart
/// V2ErrorState(onRetry: reload)
/// V2ErrorState(title: '지도를 불러오지 못했어요', onRetry: reload)
/// V2ErrorState.offline(onRetry: reload)
/// ```
class V2ErrorState extends StatelessWidget {
  const V2ErrorState({
    super.key,
    this.title = '불러오지 못했어요',
    this.body = '잠시 후 다시 시도해 주세요.',
    required this.onRetry,
    this.retryLabel = '다시 시도',
  }) : _offline = false;

  const V2ErrorState.offline({
    super.key,
    this.title = '인터넷에 연결되어 있지 않아요',
    this.body = '연결을 확인한 뒤 다시 시도해 주세요.',
    required this.onRetry,
    this.retryLabel = '다시 시도',
  }) : _offline = true;

  final String title;
  final String? body;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool _offline;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _offline
                    ? const V2SceneIllustration(V2Scene.offline, width: 140)
                    : const V2Art(icon: V2Icons.error, tone: V2Tone.err),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: V2Text.head.copyWith(color: p.ink),
                ),
                if (body != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: V2Text.body.copyWith(color: p.sub),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  V2Button(
                    label: retryLabel,
                    icon: V2Icons.refresh,
                    onPressed: onRetry,
                    variant: V2ButtonVariant.ghost,
                    size: V2ButtonSize.sm,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
