import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:secret_base_app/v2/v2.dart';

import 'share_image_stub.dart' if (dart.library.html) 'share_image_web.dart';

/// A 1:1 card for sharing. Never put names, birthdays or the four pillar
/// characters on it: only the kind of reading and a short, gentle line.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.kind,
    required this.title,
    required this.line,
    this.art,
    this.gradient = V2Gradients.hero,
  });

  final String kind;
  final String title;
  final String line;
  final Widget? art;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(V2Radius.card),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind,
              style: V2Text.label.copyWith(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (art != null)
              Expanded(child: Center(child: art))
            else
              const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V2Text.serif(size: 26, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              line,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: V2Text.body.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              '비밀기지',
              style: V2Text.label.copyWith(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview + "이미지로 저장" (web: download; elsewhere: copy the caption).
Future<void> showShareCardSheet(
  BuildContext context, {
  required Widget card,
  required String caption,
  required String fileName,
}) {
  return showV2Sheet<void>(
    context,
    title: '카드로 공유',
    subtitle: '이름이나 생일은 카드에 들어가지 않아요.',
    builder: (ctx) =>
        _ShareSheetBody(card: card, caption: caption, fileName: fileName),
  );
}

class _ShareSheetBody extends StatefulWidget {
  const _ShareSheetBody({
    required this.card,
    required this.caption,
    required this.fileName,
  });

  final Widget card;
  final String caption;
  final String fileName;

  @override
  State<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends State<_ShareSheetBody> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no data');
      final result = await saveOrShareImage(
        data.buffer.asUint8List(),
        widget.fileName,
        widget.caption,
      );
      if (!mounted) return;
      showV2Snack(context, switch (result) {
        ShareImageResult.downloaded => '이미지를 저장했어요',
        ShareImageResult.copiedText => '이 기기에서는 이미지 저장이 어려워 문구를 복사했어요',
        ShareImageResult.failed => '저장하지 못했어요. 다시 시도해 주세요.',
      }, tone: result == ShareImageResult.failed ? V2Tone.err : V2Tone.neutral);
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '저장하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: RepaintBoundary(key: _key, child: widget.card),
          ),
        ),
        const SizedBox(height: 16),
        V2Button(
          label: '이미지로 저장',
          icon: V2Icons.download,
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}
