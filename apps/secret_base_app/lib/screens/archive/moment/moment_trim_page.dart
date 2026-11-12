import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../v2/v2.dart';
import 'moment_format.dart';

/// The part of a clip the author keeps, in milliseconds of the source.
typedef MomentTrimRange = ({int startMs, int endMs});

const _minSpanMs = 1000;

/// Keeps a dragged range valid: inside the clip, at least a second long and
/// at most [maxMs]. When one end is dragged past the limit, the other end
/// follows it, so the handle under the finger never jumps.
MomentTrimRange clampTrimRange({
  required int startMs,
  required int endMs,
  required int durationMs,
  required int maxMs,
  bool movedStart = false,
}) {
  var start = startMs.clamp(0, durationMs);
  var end = endMs.clamp(0, durationMs);
  final span = durationMs < _minSpanMs ? durationMs : _minSpanMs;
  if (end - start < span) {
    if (movedStart) {
      start = (end - span).clamp(0, durationMs);
      end = start + span;
    } else {
      end = (start + span).clamp(0, durationMs);
      start = end - span;
    }
  }
  if (end - start > maxMs) {
    if (movedStart) {
      end = start + maxMs;
    } else {
      start = end - maxMs;
    }
  }
  return (startMs: start, endMs: end);
}

String _clock(int ms) => durationLabel(Duration(milliseconds: ms));

/// "1분", "90초".
String _limitLabel(Duration d) =>
    d.inSeconds % 60 == 0 ? '${d.inMinutes}분' : '${d.inSeconds}초';

/// Full-screen trimmer for a clip longer than the one-minute limit: a
/// preview that loops the chosen part and a range bar capped at a minute.
/// Pops with the chosen [MomentTrimRange], or null when cancelled.
class MomentTrimPage extends StatefulWidget {
  const MomentTrimPage({
    super.key,
    required this.path,
    required this.duration,
    this.maxDuration = momentMaxVideo,
    this.previewController,
  });

  /// The picked file's path (a `blob:` URL on the web).
  final String path;
  final Duration duration;
  final Duration maxDuration;

  /// Injected in tests, where no video plugin exists.
  final VideoPlayerController? Function(String path)? previewController;

  @override
  State<MomentTrimPage> createState() => _MomentTrimPageState();
}

class _MomentTrimPageState extends State<MomentTrimPage> {
  VideoPlayerController? _video;
  bool _previewFailed = false;
  late int _startMs;
  late int _endMs;

  int get _durationMs => widget.duration.inMilliseconds;
  int get _maxMs => widget.maxDuration.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _startMs = 0;
    _endMs = _durationMs < _maxMs ? _durationMs : _maxMs;
    unawaited(_openPreview());
  }

  Future<void> _openPreview() async {
    VideoPlayerController? controller;
    try {
      controller = widget.previewController != null
          ? widget.previewController!(widget.path)
          : kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
          : VideoPlayerController.file(File(widget.path));
      if (controller == null) throw StateError('no preview');
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted) {
        unawaited(controller.dispose());
        return;
      }
      controller.addListener(_loop);
      await controller.seekTo(Duration(milliseconds: _startMs));
      await controller.play();
      setState(() => _video = controller);
    } catch (_) {
      unawaited(controller?.dispose());
      if (mounted) setState(() => _previewFailed = true);
    }
  }

  // Plays only the chosen part, over and over.
  void _loop() {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    if (video.value.position.inMilliseconds >= _endMs) {
      unawaited(video.seekTo(Duration(milliseconds: _startMs)));
    }
  }

  @override
  void dispose() {
    _video?.removeListener(_loop);
    unawaited(_video?.dispose());
    super.dispose();
  }

  void _onChanged(RangeValues values) {
    final movedStart = values.start.round() != _startMs;
    final next = clampTrimRange(
      startMs: values.start.round(),
      endMs: values.end.round(),
      durationMs: _durationMs,
      maxMs: _maxMs,
      movedStart: movedStart,
    );
    setState(() {
      _startMs = next.startMs;
      _endMs = next.endMs;
    });
    unawaited(
      _video?.seekTo(Duration(milliseconds: movedStart ? _startMs : _endMs)),
    );
  }

  void _onChangeEnd(RangeValues _) {
    final video = _video;
    if (video == null) return;
    unawaited(
      video.seekTo(Duration(milliseconds: _startMs)).then((_) => video.play()),
    );
  }

  void _togglePlay() {
    final video = _video;
    if (video == null) return;
    setState(() {
      video.value.isPlaying ? video.pause() : video.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final video = _video;
    final span = _endMs - _startMs;
    return V2Theme(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            '영상 자르기',
            style: V2Text.head.copyWith(color: Colors.white),
          ),
          leading: IconButton(
            key: const Key('moment_trim_cancel'),
            tooltip: '취소',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              key: const Key('moment_trim_done'),
              onPressed: () => Navigator.of(
                context,
              ).pop<MomentTrimRange>((startMs: _startMs, endMs: _endMs)),
              child: Text(
                '완료',
                style: V2Text.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Center(
                    child: video != null
                        ? AspectRatio(
                            aspectRatio: video.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(video),
                                ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: video,
                                  builder: (context, value, _) =>
                                      value.isPlaying
                                      ? const SizedBox.shrink()
                                      : const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 64,
                                          color: Colors.white70,
                                        ),
                                ),
                              ],
                            ),
                          )
                        : _previewFailed
                        ? Text(
                            '미리보기를 불러오지 못했어요.\n구간은 그대로 고를 수 있어요.',
                            textAlign: TextAlign.center,
                            style: V2Text.body.copyWith(color: Colors.white70),
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  V2Space.page,
                  V2Space.x3,
                  V2Space.page,
                  V2Space.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_limitLabel(widget.maxDuration)}까지 남길 수 있어요. '
                      '남길 부분을 골라 주세요.',
                      textAlign: TextAlign.center,
                      style: V2Text.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: V2Space.x2),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: p.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                        trackHeight: 6,
                      ),
                      child: RangeSlider(
                        key: const Key('moment_trim_range'),
                        min: 0,
                        max: _durationMs.toDouble(),
                        values: RangeValues(
                          _startMs.toDouble(),
                          _endMs.toDouble(),
                        ),
                        onChanged: _onChanged,
                        onChangeEnd: _onChangeEnd,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _clock(_startMs),
                          key: const Key('moment_trim_start'),
                          style: V2Text.cap.copyWith(color: Colors.white70),
                        ),
                        const Spacer(),
                        Text(
                          '${(span / 1000).toStringAsFixed(1)}초',
                          key: const Key('moment_trim_span'),
                          style: V2Text.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _clock(_endMs),
                          key: const Key('moment_trim_end'),
                          style: V2Text.cap.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
