import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/upload_image.dart';
import '../../../features/moment_loop/application/moment_loop_controller.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'editor/native_video_preview.dart';
import 'moment_days.dart';
import 'moment_detail.dart' show MomentVideoPlayer;
import 'moment_format.dart';

/// Everything one day holds, both of us, in time order. Swipe or tap the
/// thumbnails; nothing advances on its own.
class MomentDayViewer extends StatefulWidget {
  const MomentDayViewer({
    super.key,
    required this.controller,
    required this.day,
    required this.baseUrl,
    required this.myUserId,
    required this.partnerName,
    required this.onComments,
    required this.onMore,
    this.initialPostId,
  });

  final MomentLoopController controller;
  final DateTime day;
  final String baseUrl;
  final int? myUserId;
  final String partnerName;
  final Future<void> Function(Moment post) onComments;

  /// The ⋯ menu (edit / 오늘의 순간 / delete) for one post.
  final Future<void> Function(Moment post) onMore;
  final int? initialPostId;

  @override
  State<MomentDayViewer> createState() => _MomentDayViewerState();
}

class _MomentDayViewerState extends State<MomentDayViewer> {
  late final PageController _pages;
  final _thumbs = ScrollController();
  int _index = 0;

  List<Moment> get _items {
    final key = dayKey(dateOnly(widget.day));
    return widget.controller.state.moments.where((m) {
      final d = momentDay(m);
      if (d == null || dayKey(d) != key) return false;
      return !(m.todayLocked && m.userId != widget.myUserId);
    }).toList()..sort(momentTimeOrder);
  }

  @override
  void initState() {
    super.initState();
    final i = _items.indexWhere((m) => m.id == widget.initialPostId);
    _index = i < 0 ? 0 : i;
    _pages = PageController(initialPage: _index);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _pages.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_items.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index = _index.clamp(0, _items.length - 1));
  }

  void _go(int i) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      i,
      duration: V2Motion.of(context, V2Motion.base),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _heart(Moment m) async {
    try {
      await widget.controller.toggleReaction(
        sessionId: m.sessionKey,
        emoji: '❤️',
      );
    } catch (_) {
      if (mounted) showV2Snack(context, '하트를 보내지 못했어요', tone: V2Tone.err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final i = _index.clamp(0, items.length - 1);
    final cur = items[i];
    final mine = cur.userId == widget.myUserId;
    final who = mine ? '나' : widget.partnerName;
    final liked = cur.reactions.any(
      (r) => r.userId == widget.myUserId && r.emoji == '❤️',
    );
    final caption = (cur.caption ?? '').trim();
    final p = V2Palette.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (var j = 0; j < items.length; j++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: j <= i ? Colors.white : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 4),
              child: Row(
                children: [
                  _Dot(color: mine ? p.me : p.partner),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$who · ${clockLabel(momentTime(cur))}',
                      key: const Key('moment_viewer_who'),
                      style: V2Text.bodyStrong.copyWith(color: Colors.white),
                    ),
                  ),
                  if (mine)
                    IconButton(
                      key: const Key('moment_viewer_more'),
                      tooltip: '더보기',
                      onPressed: () => widget.onMore(cur),
                      icon: const Icon(V2Icons.menu, color: Colors.white),
                    ),
                  IconButton(
                    key: const Key('moment_viewer_close'),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(V2Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('moment_viewer_pages'),
                controller: _pages,
                itemCount: items.length,
                onPageChanged: (j) {
                  setState(() => _index = j);
                  if (_thumbs.hasClients) {
                    _thumbs.animateTo(
                      (j * 56.0 - 120).clamp(
                        0,
                        _thumbs.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                },
                itemBuilder: (context, j) => _Page(
                  key: ValueKey('viewer_${items[j].id}'),
                  moment: items[j],
                  baseUrl: widget.baseUrl,
                  active: j == i,
                ),
              ),
            ),
            SizedBox(
              height: 66,
              child: ListView.separated(
                key: const Key('moment_viewer_thumbs'),
                controller: _thumbs,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, j) {
                  final m = items[j];
                  return Semantics(
                    button: true,
                    selected: j == i,
                    label: '${j + 1}번째 보기',
                    child: GestureDetector(
                      key: Key('moment_viewer_thumb_$j'),
                      onTap: () => _go(j),
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: j == i ? 1 : .55,
                          child: Container(
                            width: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: j == i
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MomentFill(
                                    moment: m,
                                    baseUrl: widget.baseUrl,
                                    cacheWidth: 160,
                                  ),
                                  Positioned(
                                    left: 3,
                                    top: 3,
                                    child: _Dot(
                                      color: m.userId == widget.myUserId
                                          ? p.me
                                          : p.partner,
                                      size: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      caption.isEmpty ? momentFeedDayLong(widget.day) : caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.body.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    key: const Key('moment_viewer_heart'),
                    tooltip: liked ? '하트 취소' : '하트',
                    onPressed: () => unawaited(_heart(cur)),
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: liked ? p.point : Colors.white,
                    ),
                  ),
                  if (cur.reactions.isNotEmpty)
                    Text(
                      '${cur.reactions.length}',
                      style: V2Text.cap.copyWith(color: Colors.white70),
                    ),
                  IconButton(
                    key: const Key('moment_viewer_comments'),
                    tooltip: '댓글',
                    onPressed: () => unawaited(widget.onComments(cur)),
                    icon: const Icon(V2Icons.chat, color: Colors.white),
                  ),
                  if (cur.commentCount > 0)
                    Text(
                      '${cur.commentCount}',
                      style: V2Text.cap.copyWith(color: Colors.white70),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 10});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}

class _Page extends StatefulWidget {
  const _Page({
    super.key,
    required this.moment,
    required this.baseUrl,
    required this.active,
  });

  final Moment moment;
  final String baseUrl;
  final bool active;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  NativeVideoController? _native;

  @override
  void didUpdateWidget(covariant _Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) _native?.pause();
  }

  @override
  void dispose() {
    _native?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.moment;
    final url = mediaUrlFor(widget.baseUrl, m.mediaUrl);
    if (m.isVideo && url.isNotEmpty) {
      if (kIsWeb && nativeVideoPreviewAvailable) {
        // iOS Safari loads a clip only after a tap on a real <video>.
        final native = _native ??= NativeVideoController();
        return Stack(
          fit: StackFit.expand,
          children: [
            nativeVideoPreview(url: url, controller: native),
            IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: native.paused,
                builder: (context, paused, _) => paused
                    ? const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 72,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }
      return widget.active
          ? MomentVideoPlayer(url: url)
          : MomentFill(moment: m, baseUrl: widget.baseUrl);
    }
    if (!m.hasMedia) {
      return MomentFill(moment: m, baseUrl: widget.baseUrl);
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: UploadImage(
          raw: m.mediaUrl!,
          baseUrl: widget.baseUrl,
          pixelWidth: 1080,
          fit: BoxFit.contain,
          error: V2PhotoPlaceholder(seed: m.id, radius: 0),
        ),
      ),
    );
  }
}
