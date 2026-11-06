import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';

bool isVideoName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return const ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp'].contains(ext);
}

/// Reads a clip's length on the device before upload. Returns null when the
/// platform cannot tell (the server still enforces the 10-second rule).
Future<Duration?> probeVideoDuration(XFile file) async {
  VideoPlayerController? controller;
  try {
    controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(file.path))
        : VideoPlayerController.file(File(file.path));
    await controller.initialize().timeout(const Duration(seconds: 6));
    final duration = controller.value.duration;
    return duration == Duration.zero ? null : duration;
  } catch (_) {
    return null;
  } finally {
    unawaited(controller?.dispose());
  }
}

final _videoThumbCache = <String, Uint8List?>{};

/// First frame of a remote clip (mobile only; web shows a calm placeholder).
class MomentVideoThumb extends StatefulWidget {
  final String url;
  final Object seed;

  const MomentVideoThumb({super.key, required this.url, required this.seed});

  @override
  State<MomentVideoThumb> createState() => _MomentVideoThumbState();
}

class _MomentVideoThumbState extends State<MomentVideoThumb> {
  late final Future<Uint8List?> _future = _load();

  Future<Uint8List?> _load() async {
    if (kIsWeb) return null;
    if (_videoThumbCache.containsKey(widget.url)) {
      return _videoThumbCache[widget.url];
    }
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 60,
      );
      _videoThumbCache[widget.url] = bytes;
      return bytes;
    } catch (_) {
      _videoThumbCache[widget.url] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (_, snap) {
        final bytes = snap.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              V2PhotoPlaceholder(seed: widget.seed, radius: 0),
            const Center(child: _PlayBadge()),
          ],
        );
      },
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: V2Colors.ink.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

/// Square-ish preview of one moment group: photo, clip or text card.
class MomentTile extends StatelessWidget {
  final Moment moment;
  final String baseUrl;
  final int count;
  final String authorName;
  final bool isMine;
  final double radius;
  final bool showAuthor;

  const MomentTile({
    super.key,
    required this.moment,
    required this.baseUrl,
    required this.authorName,
    required this.isMine,
    this.count = 1,
    this.radius = V2Radius.ctl,
    this.showAuthor = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    Widget body;
    if (moment.todayLocked) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          V2PhotoPlaceholder(seed: moment.id, radius: 0),
          Center(
            child: Icon(
              V2Icons.lock,
              color: Colors.white.withValues(alpha: 0.95),
              size: 26,
            ),
          ),
        ],
      );
    } else if (moment.hasMedia && moment.isVideo) {
      body = MomentVideoThumb(
        url: _url(moment.mediaUrl),
        seed: moment.id,
      );
    } else if (moment.hasMedia) {
      body = Image.network(
        _url(moment.mediaUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => V2PhotoPlaceholder(
          seed: moment.id,
          icon: V2Icons.image,
          radius: 0,
        ),
      );
    } else {
      final caption = (moment.caption ?? '').trim();
      body = Container(
        color: isMine ? p.primarySoft : V2Colors.skySoft,
        padding: const EdgeInsets.all(10),
        alignment: Alignment.topLeft,
        child: Text(
          caption.isEmpty ? '말없이 남긴 순간' : caption,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: V2Text.cap.copyWith(
            color: isMine ? p.onPrimarySoft : V2Colors.skyText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (showAuthor)
            Positioned(
              left: 6,
              bottom: 6,
              child: MomentAuthorDot(name: authorName, isMine: isMine),
            ),
          if (count > 1)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: V2Colors.ink.withValues(alpha: 0.55),
                  borderRadius: V2Radius.pillAll,
                ),
                child: Text(
                  '$count',
                  style: V2Text.label.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _url(String? raw) {
    final url = raw?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$baseUrl$url';
  }
}

/// 24px initial badge on tiles (민 / 서).
class MomentAuthorDot extends StatelessWidget {
  final String name;
  final bool isMine;

  const MomentAuthorDot({super.key, required this.name, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMine ? V2Avatar.meColor : V2Avatar.partnerColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          initial,
          textScaler: TextScaler.noScaling,
          style: V2Text.sans(
            size: 12,
            weight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
