import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../features/moment_loop/data/video_frames.dart';
import '../../../../v2/v2.dart';
import '../moment_format.dart';
import 'editor_item.dart';

/// Video page of the editor: preview looping inside the kept range.
class VideoStage extends StatefulWidget {
  const VideoStage({
    super.key,
    required this.item,
    required this.active,
    this.preview = true,
  });

  final EditorItem item;

  /// Only the visible page plays.
  final bool active;

  /// Off in widget tests (no video platform there).
  final bool preview;

  @override
  State<VideoStage> createState() => VideoStageState();
}

class VideoStageState extends State<VideoStage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    if (widget.preview) unawaited(_open());
  }

  Future<void> _open() async {
    final path = widget.item.file.path;
    final c = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : VideoPlayerController.file(File(path));
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(false);
      c.addListener(_loop);
      if (!mounted) return;
      setState(() {});
      await seekToStart();
      if (widget.active) await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _loop() {
    final c = _controller;
    final v = widget.item.video;
    if (c == null || v == null || !c.value.isInitialized) return;
    if (c.value.position >= v.end || (c.value.isCompleted && !_paused)) {
      unawaited(seekToStart(play: !_paused));
    }
  }

  /// Jumps to the kept range's start (after the range changed).
  Future<void> seekToStart({bool play = false}) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(widget.item.video?.start ?? Duration.zero);
    if (play && widget.active) await c.play();
  }

  @override
  void didUpdateWidget(covariant VideoStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.active && !old.active && !_paused) unawaited(c.play());
    if (!widget.active && old.active) unawaited(c.pause());
  }

  @override
  void dispose() {
    _controller?.removeListener(_loop);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized && !_failed;
    return Semantics(
      label: _paused ? '영상 재생' : '영상 일시정지',
      button: ready,
      child: GestureDetector(
        onTap: ready
            ? () {
                setState(() => _paused = !_paused);
                _paused ? c.pause() : c.play();
              }
            : null,
        child: Center(
          child: ready
              ? AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayer(c),
                      if (_paused)
                        const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 72,
                          ),
                        ),
                    ],
                  ),
                )
              : _Placeholder(
                  failed: _failed || !widget.preview,
                  poster: widget.item.frames?.isNotEmpty == true
                      ? widget.item.frames!.first
                      : null,
                ),
        ),
      ),
    );
  }
}

/// Shown until the preview can play. iOS Safari often will not load a
/// video before the user taps it, so a filmstrip frame stands in.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.failed, this.poster});
  final bool failed;
  final Uint8List? poster;

  @override
  Widget build(BuildContext context) {
    final poster = this.poster;
    if (poster != null) {
      return Image.memory(poster, fit: BoxFit.contain, gaplessPlayback: true);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(V2Icons.video, color: Colors.white54, size: 48),
        const SizedBox(height: 8),
        Text(
          failed ? '미리보기를 열지 못했어요' : '영상을 여는 중',
          style: V2Text.cap.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

/// Filmstrip with a draggable kept range (max 1 minute, min 1 second).
class VideoTrimBar extends StatefulWidget {
  const VideoTrimBar({
    super.key,
    required this.item,
    required this.onChanged,
    this.onFrames,
    this.canTrim = true,
    this.loadFrames = true,
  });

  final EditorItem item;

  /// Called when a drag ends, so the preview can jump to the new start.
  final VoidCallback onChanged;

  /// Called once filmstrip frames are in (the preview uses the first one).
  final VoidCallback? onFrames;

  /// False when the device cannot cut clips (no on-device encoder).
  final bool canTrim;
  final bool loadFrames;

  static const maxRange = momentMaxVideo;
  static const minRange = Duration(seconds: 1);

  @override
  State<VideoTrimBar> createState() => _VideoTrimBarState();
}

enum _Drag { start, end, both }

class _VideoTrimBarState extends State<VideoTrimBar> {
  static const _handle = 18.0;
  static const _frameCount = 8;

  _Drag? _drag;
  Duration _startAtDrag = Duration.zero;
  Duration _endAtDrag = Duration.zero;
  double _dxAtDrag = 0;

  VideoEdit get _v => widget.item.video!;

  @override
  void initState() {
    super.initState();
    if (widget.loadFrames && widget.item.frames == null) {
      unawaited(_loadFrames());
    }
  }

  Future<void> _loadFrames() async {
    final frames = await videoFrames(
      widget.item.file.path,
      count: _frameCount,
      duration: _v.duration,
    );
    if (!mounted) return;
    setState(() => widget.item.frames = frames);
    widget.onFrames?.call();
  }

  Duration _at(double dx, double width) {
    final ms = (dx / width * _v.duration.inMilliseconds).round();
    return Duration(milliseconds: ms.clamp(0, _v.duration.inMilliseconds));
  }

  void _update(double dx, double width) {
    final d = (_at(dx, width) - _at(_dxAtDrag, width)).inMilliseconds;
    final total = _v.duration.inMilliseconds;
    final s0 = _startAtDrag.inMilliseconds;
    final e0 = _endAtDrag.inMilliseconds;
    final MomentTrimRange r;
    switch (_drag) {
      case _Drag.start || _Drag.end:
        final moved = _drag == _Drag.start;
        r = clampTrimRange(
          startMs: moved ? s0 + d : s0,
          endMs: moved ? e0 : e0 + d,
          durationMs: total,
          maxMs: VideoTrimBar.maxRange.inMilliseconds,
          movedStart: moved,
        );
      case _Drag.both:
        final start = (s0 + d).clamp(0, total - (e0 - s0));
        r = (startMs: start, endMs: start + (e0 - s0));
      case null:
        return;
    }
    setState(() {
      _v.start = Duration(milliseconds: r.startMs);
      _v.end = Duration(milliseconds: r.endMs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.item.video;
    if (v == null || !widget.canTrim) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          v == null ? '영상 길이를 읽지 못해 자를 수 없어요' : '이 기기에서는 영상을 자를 수 없어요',
          style: V2Text.cap.copyWith(color: Colors.white70),
        ),
      );
    }
    final frames = widget.item.frames ?? const <Uint8List>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.duration > momentMaxVideo + const Duration(milliseconds: 400))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '1분까지만 올라가요 · 구간을 옮겨 보세요',
              key: const Key('video_trim_hint'),
              textAlign: TextAlign.center,
              style: V2Text.cap.copyWith(color: Colors.white),
            ),
          ),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth - _handle * 2;
            final total = math.max(1, v.duration.inMilliseconds);
            final left = v.start.inMilliseconds / total * width;
            final right = v.end.inMilliseconds / total * width;
            return SizedBox(
              height: 60,
              child: Stack(
                children: [
                  Positioned(
                    left: _handle,
                    right: _handle,
                    top: 6,
                    bottom: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: frames.isEmpty
                          ? const ColoredBox(color: Color(0xFF3A3A3C))
                          : Row(
                              children: [
                                for (final f in frames)
                                  Expanded(
                                    child: Image.memory(
                                      f,
                                      fit: BoxFit.cover,
                                      height: 48,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  // Dim outside the kept range.
                  Positioned(
                    left: _handle,
                    width: left,
                    top: 6,
                    bottom: 6,
                    child: const ColoredBox(color: Color(0xAA000000)),
                  ),
                  Positioned(
                    left: _handle + right,
                    right: _handle,
                    top: 6,
                    bottom: 6,
                    child: const ColoredBox(color: Color(0xAA000000)),
                  ),
                  // Kept range: drag the middle to slide it.
                  Positioned(
                    left: left,
                    width: right - left + _handle * 2,
                    top: 0,
                    bottom: 0,
                    child: _rangeBox(width),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${durationLabel(v.start)} – ${durationLabel(v.end)} · ${v.length.inSeconds}초',
          key: const Key('video_trim_label'),
          textAlign: TextAlign.center,
          style: V2Text.cap.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _rangeBox(double width) {
    void begin(_Drag d, DragStartDetails s) {
      _drag = d;
      _startAtDrag = _v.start;
      _endAtDrag = _v.end;
      _dxAtDrag = s.globalPosition.dx;
    }

    void move(DragUpdateDetails s) => _update(s.globalPosition.dx, width);
    void end(DragEndDetails _) {
      _drag = null;
      widget.onChanged();
    }

    Widget handle(_Drag d, String label, bool left) => Semantics(
      label: label,
      slider: true,
      child: GestureDetector(
        key: Key(left ? 'video_trim_start' : 'video_trim_end'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (s) => begin(d, s),
        onHorizontalDragUpdate: move,
        onHorizontalDragEnd: end,
        child: Container(
          width: _handle,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(left ? 6 : 0),
              right: Radius.circular(left ? 0 : 6),
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 3,
              height: 18,
              child: ColoredBox(color: Color(0xFF8E8E93)),
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        handle(_Drag.start, '시작 ${durationLabel(_v.start)}', true),
        Expanded(
          child: GestureDetector(
            key: const Key('video_trim_range'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (s) => begin(_Drag.both, s),
            onHorizontalDragUpdate: move,
            onHorizontalDragEnd: end,
            child: Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
        ),
        handle(_Drag.end, '끝 ${durationLabel(_v.end)}', false),
      ],
    );
  }
}
