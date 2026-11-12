import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../features/moment_loop/data/video_shrinker.dart';
import '../../../../v2/v2.dart';
import '../moment_format.dart';
import 'editor_item.dart';
import 'photo_filters.dart';
import 'photo_render.dart';
import 'photo_stage.dart';
import 'text_layer_editor.dart';
import 'video_stage.dart';

/// One finished file from the editor.
class EditedMedia {
  final EditorItem item;
  final String name;
  final Uint8List bytes;

  /// Small first frame for video tiles in the composer.
  final Uint8List? thumb;

  const EditedMedia({
    required this.item,
    required this.name,
    required this.bytes,
    this.thumb,
  });
}

class EditorOutcome {
  final List<EditedMedia> media;

  /// Why some videos were left out (shown as a banner in the composer).
  final String? issue;

  const EditorOutcome(this.media, {this.issue});
}

/// Instagram-style edit step between picking and the caption screen:
/// photos get crop / rotate / filter / text, videos get a 1-minute trim.
class MomentEditorPage extends StatefulWidget {
  const MomentEditorPage({
    super.key,
    required this.items,
    required this.shrinker,
    this.videoPreview = true,
  });

  final List<EditorItem> items;

  /// Cuts and shrinks clips on the device (web: WebCodecs, Android: Media3).
  final VideoShrinker shrinker;

  /// Video playback and filmstrips (off in widget tests).
  final bool videoPreview;

  static Future<EditorOutcome?> open(
    BuildContext context,
    List<EditorItem> items, {
    required VideoShrinker shrinker,
    bool videoPreview = true,
  }) {
    return Navigator.of(context).push<EditorOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MomentEditorPage(
          items: items,
          shrinker: shrinker,
          videoPreview: videoPreview,
        ),
      ),
    );
  }

  @override
  State<MomentEditorPage> createState() => _MomentEditorPageState();
}

class _MomentEditorPageState extends State<MomentEditorPage> {
  final _pages = PageController();
  final _images = <int, ui.Image>{};
  final _stageKeys = <int, GlobalKey<VideoStageState>>{};
  int _index = 0;
  PhotoTool _tool = PhotoTool.none;

  // Finishing.
  bool _busy = false;
  String? _progress;
  String? _job;
  var _jobSeq = 0;
  EditorItem get _item => widget.items[_index];

  /// Edits as they were when the editor opened, restored on close.
  late final _before = [
    for (final item in widget.items)
      (edit: item.edit.copy(), start: item.video?.start, end: item.video?.end),
  ];

  void _close() {
    for (final (i, item) in widget.items.indexed) {
      final b = _before[i];
      item.edit.restore(b.edit);
      final v = item.video;
      if (v != null) {
        v.start = b.start!;
        v.end = b.end!;
      }
    }
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _before;
    for (final (i, item) in widget.items.indexed) {
      if (!item.isVideo) unawaited(_decode(i, item));
    }
  }

  Future<void> _decode(int i, EditorItem item) async {
    try {
      final image = await decodeEditorPhoto(item.photo!);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _images[i] = image);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final image in _images.values) {
      image.dispose();
    }
    final job = _job;
    if (job != null) widget.shrinker.cancel(job);
    super.dispose();
  }

  // ── Photo tools ──────────────────────────────────────────────────────────

  void _rotate() {
    final image = _images[_index];
    if (image == null) return;
    setState(() {
      final e = _item.edit;
      e.quarterTurns = (e.quarterTurns + 1) % 4;
      e.crop = fitCrop(
        rotatedSize(
          Size(image.width.toDouble(), image.height.toDouble()),
          e.quarterTurns,
        ),
        e.aspect.ratio,
      );
    });
  }

  void _setAspect(CropAspect aspect) {
    final image = _images[_index];
    if (image == null) return;
    setState(() {
      final e = _item.edit;
      e.aspect = aspect;
      e.crop = fitCrop(
        rotatedSize(
          Size(image.width.toDouble(), image.height.toDouble()),
          e.quarterTurns,
        ),
        aspect.ratio,
      );
    });
  }

  Future<void> _addText([TextLayer? existing]) async {
    setState(() => _tool = PhotoTool.none);
    final result = await showTextLayerEditor(context, existing: existing);
    if (!mounted || result == null) return;
    setState(() {
      final texts = _item.edit.texts;
      if (result.deleted) {
        texts.remove(existing);
      } else if (existing == null) {
        texts.add(result.layer!);
      }
    });
  }

  // ── Finish ───────────────────────────────────────────────────────────────

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    return stem.isEmpty ? 'moment' : stem;
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _tool = PhotoTool.none;
      _progress = null;
    });
    final out = <EditedMedia>[];
    String? issue;
    final videos = widget.items.where((i) => i.needsConvert).length;
    var videoNo = 0;
    try {
      for (final (i, item) in widget.items.indexed) {
        if (!item.isVideo) {
          final image = _images[i];
          final bytes = item.edit.isEmpty || image == null
              ? item.photo!
              : await renderEditedPhoto(image, item.edit);
          out.add(
            EditedMedia(
              item: item,
              name: '${_stem(item.name)}.jpg',
              bytes: bytes,
            ),
          );
          continue;
        }
        final thumb = item.frames?.isNotEmpty == true
            ? item.frames!.first
            : null;
        if (!item.needsConvert) {
          out.add(
            EditedMedia(
              item: item,
              name: item.name,
              bytes: await item.file.readAsBytes(),
              thumb: thumb,
            ),
          );
          continue;
        }
        videoNo++;
        final job = _job =
            'edit_${DateTime.now().microsecondsSinceEpoch}_${_jobSeq++}';
        void show(double p) {
          if (!mounted) return;
          setState(() {
            final count = videos > 1 ? '$videoNo/$videos · ' : '';
            _progress = '$count${(p * 100).round()}%';
          });
        }

        show(0);
        try {
          final v = item.video;
          final cut =
              v != null && (v.start > Duration.zero || v.end < v.duration);
          final bytes = await widget.shrinker.shrink(
            id: job,
            path: item.file.path,
            startMs: cut ? v.start.inMilliseconds : null,
            endMs: cut ? v.end.inMilliseconds : null,
            onProgress: show,
          );
          if (bytes.length > momentMaxBytes) {
            issue = momentMediaIssueLabel(MomentMediaIssue.tooLarge);
            continue;
          }
          out.add(
            EditedMedia(
              item: item,
              name: '${_stem(item.name)}.mp4',
              bytes: bytes,
              thumb: thumb,
            ),
          );
        } on VideoShrinkException catch (e) {
          if (e.cancelled) rethrow;
          issue = e.code == 'unsupported'
              ? momentMediaIssueLabel(MomentMediaIssue.cannotShrink)
              : '영상을 줄이지 못했어요. 다시 시도해 주세요';
        }
      }
    } on VideoShrinkException {
      // 취소: stay in the editor with the edits as they are.
      if (mounted) setState(() => _busy = false);
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showV2Snack(context, '편집한 파일을 만들지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
      return;
    } finally {
      _job = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop(EditorOutcome(out, issue: issue));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(count),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      physics: _tool == PhotoTool.crop || _busy
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: count,
                      onPageChanged: (i) => setState(() {
                        _index = i;
                        _tool = PhotoTool.none;
                      }),
                      itemBuilder: (context, i) => _page(i),
                    ),
                  ),
                  if (count > 1) _dots(count),
                  _toolbar(),
                ],
              ),
              if (_busy && _progress != null) _progressOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('moment_editor_close'),
            tooltip: '닫기',
            onPressed: _busy ? null : _close,
            icon: const Icon(V2Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Text(
              count > 1 ? '편집 ${_index + 1}/$count' : '편집',
              textAlign: TextAlign.center,
              style: V2Text.bodyStrong.copyWith(color: Colors.white),
            ),
          ),
          Material(
            color: V2Colors.rose600,
            shape: const StadiumBorder(),
            child: InkWell(
              key: const Key('moment_editor_next'),
              customBorder: const StadiumBorder(),
              onTap: _busy ? null : _finish,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy && _progress == null)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: V2Colors.onPrimary,
                          ),
                        )
                      else
                        Text(
                          '다음',
                          style: V2Text.buttonSm.copyWith(
                            color: V2Colors.onPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(int i) {
    final item = widget.items[i];
    if (item.isVideo) {
      final key = _stageKeys.putIfAbsent(i, GlobalKey<VideoStageState>.new);
      return VideoStage(
        key: key,
        item: item,
        active: i == _index && !_busy,
        preview: widget.videoPreview,
      );
    }
    final image = _images[i];
    if (image == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: PhotoStage(
        image: image,
        edit: item.edit,
        tool: i == _index ? _tool : PhotoTool.none,
        onChanged: () => setState(() {}),
        onEditText: _addText,
      ),
    );
  }

  Widget _dots(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _index ? Colors.white : Colors.white38,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final item = _item;
    final Widget body;
    if (item.isVideo) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: VideoTrimBar(
          key: ValueKey('trim_$_index'),
          item: item,
          canTrim: widget.shrinker.supported,
          loadFrames: widget.videoPreview,
          onChanged: () {
            setState(() {});
            unawaited(
              _stageKeys[_index]?.currentState?.seekToStart(play: true),
            );
          },
        ),
      );
    } else if (_tool == PhotoTool.crop) {
      body = _cropBar();
    } else if (_tool == PhotoTool.filter) {
      body = _filterBar();
    } else {
      body = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            key: const Key('editor_tool_crop'),
            icon: Icons.crop_rounded,
            label: '자르기',
            onTap: () => setState(() => _tool = PhotoTool.crop),
          ),
          _ToolButton(
            key: const Key('editor_tool_rotate'),
            icon: Icons.rotate_90_degrees_cw_outlined,
            label: '회전',
            onTap: _rotate,
          ),
          _ToolButton(
            key: const Key('editor_tool_filter'),
            icon: Icons.auto_awesome_outlined,
            label: '필터',
            onTap: () => setState(() => _tool = PhotoTool.filter),
          ),
          _ToolButton(
            key: const Key('editor_tool_text'),
            icon: Icons.text_fields_rounded,
            label: '글자',
            onTap: () => unawaited(_addText()),
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 112),
      child: Center(child: body),
    );
  }

  Widget _cropBar() {
    final e = _item.edit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final a in CropAspect.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: Key('crop_aspect_${a.name}'),
                    label: Text(a.label),
                    selected: e.aspect == a,
                    showCheckmark: false,
                    onSelected: (_) => _setAspect(a),
                    labelStyle: V2Text.buttonSm.copyWith(
                      color: e.aspect == a ? Colors.black : Colors.white,
                    ),
                    selectedColor: Colors.white,
                    backgroundColor: const Color(0xFF2C2C2E),
                    side: BorderSide.none,
                  ),
                ),
              IconButton(
                tooltip: '회전',
                onPressed: _rotate,
                icon: const Icon(
                  Icons.rotate_90_degrees_cw_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '끌어서 옮기고, 두 손가락으로 크기를 바꿔요',
          style: V2Text.cap.copyWith(color: Colors.white60),
        ),
        _doneButton(),
      ],
    );
  }

  Widget _filterBar() {
    final image = _images[_index];
    if (image == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in photoFilters)
                FilterThumb(
                  key: Key('photo_filter_${f.id}'),
                  image: image,
                  edit: _item.edit,
                  filter: f,
                  selected: _item.edit.filter == f.id,
                  onTap: () => setState(() => _item.edit.filter = f.id),
                ),
            ],
          ),
        ),
        _doneButton(),
      ],
    );
  }

  Widget _doneButton() => TextButton(
    key: const Key('editor_tool_done'),
    onPressed: () => setState(() => _tool = PhotoTool.none),
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(64, 44),
    ),
    child: Text('완료', style: V2Text.buttonSm.copyWith(color: Colors.white)),
  );

  Widget _progressOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '영상을 준비하고 있어요',
                style: V2Text.bodyStrong.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                _progress!,
                key: const Key('moment_editor_progress'),
                style: V2Text.cap.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextButton(
                key: const Key('moment_editor_cancel'),
                onPressed: () {
                  final job = _job;
                  if (job != null) widget.shrinker.cancel(job);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 44),
                ),
                child: Text(
                  '취소',
                  style: V2Text.buttonSm.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(height: 6),
                Text(label, style: V2Text.cap.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
