import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/auth_service.dart';
import '../../../core/http/api_client.dart';
import '../../../features/moment_loop/data/media_upload_service.dart'
    show MomentLoopException;
import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'moment_format.dart';

const _emojiOptions = ['❤️', '😍', '🥰', '😂', '😮'];

typedef MomentToggleReaction =
    Future<List<MomentReaction>> Function(String sessionId, String emoji);

/// 상세 보기: 사진/영상 페이저, 반응 5개, 댓글 요약, 글쓴이 기준 메뉴.
class MomentDetailPage extends StatefulWidget {
  final List<Moment> group;
  final int? myUserId;
  final int? initialPostId;
  final String myName;
  final String partnerName;
  final Future<void> Function(Moment post) onEdit;

  /// Returns true when the post was removed.
  final Future<bool> Function(Moment post) onDelete;
  final MomentToggleReaction onReaction;
  final Future<void> Function(int postId) onDesignateToday;
  final Future<void> Function() onRemoveTodayDesignation;
  final AuthService? auth;

  const MomentDetailPage({
    super.key,
    required this.group,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onEdit,
    required this.onDelete,
    required this.onReaction,
    required this.onDesignateToday,
    required this.onRemoveTodayDesignation,
    this.initialPostId,
    this.auth,
  });

  @override
  State<MomentDetailPage> createState() => _MomentDetailPageState();
}

class _MomentDetailPageState extends State<MomentDetailPage> {
  late final PageController _pages;
  late final AuthService _auth = widget.auth ?? AuthService();
  int _current = 0;
  late List<MomentReaction> _reactions;
  bool _reacting = false;
  bool _busy = false;
  final Map<int, int> _commentCounts = {};
  ApiClient? _api;

  String get _sessionId => widget.group.first.sessionId?.trim() ?? '';
  Moment get _post => widget.group[_current];
  bool _isMine(Moment m) => m.userId == widget.myUserId;

  @override
  void initState() {
    super.initState();
    final target = widget.group.indexWhere((p) => p.id == widget.initialPostId);
    _current = target < 0 ? 0 : target;
    _pages = PageController(initialPage: _current);
    _reactions = List.of(widget.group.first.reactions);
    unawaited(_loadCommentCount(_post.id));
  }

  @override
  void dispose() {
    _pages.dispose();
    _api?.close();
    super.dispose();
  }

  Future<void> _loadCommentCount(int postId) async {
    if (_commentCounts.containsKey(postId)) return;
    try {
      _api ??= ApiClient(
        baseUrl: _auth.baseUrl,
        tokenProvider: () => _auth.token,
      );
      final body = await _api!.getJson('/api/setlog/$postId/comments');
      final list = body['comments'];
      if (mounted && list is List) {
        setState(() => _commentCounts[postId] = list.length);
      }
    } catch (_) {
      // The summary row simply stays "댓글 보기".
    }
  }

  String? get _myEmoji {
    for (final r in _reactions) {
      if (r.userId == widget.myUserId) return r.emoji;
    }
    return null;
  }

  Future<void> _toggleReaction(String emoji) async {
    if (_sessionId.isEmpty || _reacting) return;
    setState(() => _reacting = true);
    try {
      final updated = await widget.onReaction(_sessionId, emoji);
      if (mounted) setState(() => _reactions = updated);
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '반응을 남기지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String done,
    required String Function(Object) failure,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showV2Snack(context, done);
    } catch (e) {
      if (mounted) showV2Snack(context, failure(e), tone: V2Tone.err);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMenu() async {
    final post = _post;
    final locked = post.mediaEditLocked;
    final choice = await showV2Sheet<String>(
      context,
      title: '이 순간',
      dark: true,
      builder: (ctx) => V2List(
        children: [
          V2ListTile(
            key: const Key('moment_menu_edit'),
            icon: V2Icons.edit,
            title: '고치기',
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          if (post.todayMoment)
            V2ListTile(
              key: const Key('moment_menu_today_off'),
              icon: V2Icons.sparkle,
              tone: V2Tone.honey,
              title: '오늘의 순간에서 빼기',
              onTap: () => Navigator.pop(ctx, 'today_off'),
            )
          else
            V2ListTile(
              key: const Key('moment_menu_today_on'),
              icon: V2Icons.sparkle,
              tone: V2Tone.honey,
              title: '오늘의 순간으로 정하기',
              onTap: () => Navigator.pop(ctx, 'today_on'),
            ),
          V2ListTile(
            key: const Key('moment_menu_delete'),
            icon: V2Icons.delete,
            title: '지우기',
            subtitle: locked ? '열린 오늘의 순간은 지울 수 없어요' : null,
            destructive: true,
            onTap: locked ? null : () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'edit':
        await widget.onEdit(post);
        if (mounted) setState(() {});
      case 'today_on':
        await _run(
          () => widget.onDesignateToday(post.id),
          done: '오늘의 순간으로 정했어요',
          failure: (e) => e is MomentLoopException
              ? switch (e.code) {
                  'today_loop_locked' => '둘의 순간이 열린 뒤에는 바꿀 수 없어요',
                  'today_moment_not_found' => '오늘 남긴 내 순간만 정할 수 있어요',
                  _ => '오늘의 순간으로 정하지 못했어요',
                }
              : '연결을 확인하고 다시 시도해 주세요',
        );
      case 'today_off':
        await _run(
          widget.onRemoveTodayDesignation,
          done: '오늘의 순간에서 뺐어요',
          failure: (e) =>
              e is MomentLoopException && e.code == 'today_loop_locked'
              ? '둘의 순간이 열린 뒤에는 뺄 수 없어요'
              : '오늘의 순간에서 빼지 못했어요',
        );
      case 'delete':
        final ok = await showV2ConfirmDestructiveSheet(
          context,
          title: '이 순간을 지울까요?',
          consequences: const [
            '사진과 한 줄이 사라져요',
            '받은 반응과 댓글도 함께 사라져요',
            '되돌릴 수 없어요',
          ],
          confirmLabel: '지우기',
        );
        if (!ok || !mounted) return;
        final removed = await widget.onDelete(post);
        if (removed && mounted) Navigator.of(context).pop();
    }
  }

  void _openComments() {
    final post = _post;
    showV2Sheet<void>(
      context,
      title: '댓글',
      dark: true,
      builder: (_) => MomentCommentSheet(
        postId: post.id,
        myUserId: widget.myUserId,
        auth: _auth,
        onCount: (n) {
          if (mounted) setState(() => _commentCounts[post.id] = n);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      dark: true,
      child: Builder(
        builder: (context) {
          final p = V2Palette.of(context);
          final post = _post;
          final mine = _isMine(post);
          final author = mine
              ? widget.myName
              : (post.userName ?? widget.partnerName);
          final day = momentDay(post);
          final caption = (post.caption ?? '').trim();
          final count = _commentCounts[post.id];
          final myEmoji = _myEmoji;
          return Scaffold(
            backgroundColor: p.bg,
            appBar: V2Header(
              title: day == null ? '순간' : longDate(day),
              showBack: true,
              backTooltip: '닫기',
              actions: [
                if (mine)
                  V2IconButton(
                    key: const Key('moment_detail_menu'),
                    icon: V2Icons.menu,
                    tooltip: '더 보기',
                    onPressed: _busy ? null : _openMenu,
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.group.length,
                    onPageChanged: (i) {
                      setState(() => _current = i);
                      unawaited(_loadCommentCount(widget.group[i].id));
                    },
                    itemBuilder: (context, i) =>
                        _Page(moment: widget.group[i], baseUrl: _auth.baseUrl),
                  ),
                ),
                Container(
                  color: p.bg,
                  padding: EdgeInsets.fromLTRB(
                    V2Space.page,
                    V2Space.x3,
                    V2Space.page,
                    MediaQuery.paddingOf(context).bottom + V2Space.x3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.group.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < widget.group.length; i++)
                              AnimatedContainer(
                                duration: V2Motion.of(context, V2Motion.fast),
                                width: i == _current ? 16 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: i == _current ? p.ink : p.line2,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: V2Space.x3),
                      ],
                      Row(
                        children: [
                          V2Avatar(
                            name: author,
                            color: mine
                                ? V2Avatar.meColor
                                : V2Avatar.partnerColor,
                            size: V2AvatarSize.sm,
                          ),
                          const SizedBox(width: V2Space.x2),
                          Expanded(
                            child: Text(
                              [
                                author,
                                clockLabel(momentTime(post)),
                                if (post.linkedPlaceName != null)
                                  post.linkedPlaceName!,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V2Text.cap.copyWith(color: p.sub),
                            ),
                          ),
                        ],
                      ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: V2Space.x2),
                        Text(
                          caption,
                          style: V2Text.body.copyWith(color: p.ink),
                        ),
                      ],
                      if (_sessionId.isNotEmpty) ...[
                        const SizedBox(height: V2Space.x3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final emoji in _emojiOptions)
                              _ReactionChip(
                                emoji: emoji,
                                count: _reactions
                                    .where((r) => r.emoji == emoji)
                                    .length,
                                selected: myEmoji == emoji,
                                onTap: () => _toggleReaction(emoji),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: V2Space.x2),
                      V2Button(
                        key: const Key('moment_comment_summary'),
                        label: count == null
                            ? '댓글 보기'
                            : count == 0
                            ? '댓글 남기기'
                            : '댓글 $count개',
                        icon: V2Icons.chat,
                        variant: V2ButtonVariant.soft,
                        size: V2ButtonSize.sm,
                        onPressed: _openComments,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final label = '$emoji 반응${count > 0 ? ' $count명' : ''}';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? p.primarySoft : p.soft,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? p.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 52,
                minHeight: V2Space.tap,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: V2Space.x3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: V2Text.label.copyWith(color: p.ink),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final Moment moment;
  final String baseUrl;
  const _Page({required this.moment, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    if (moment.hasMedia && !moment.isVideo) {
      return InteractiveViewer(
        child: Image.network(
          mediaUrlFor(baseUrl, moment.mediaUrl),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(V2Icons.image, color: p.muted, size: 40),
                const SizedBox(height: V2Space.x2),
                Text('사진을 불러오지 못했어요', style: V2Text.cap.copyWith(color: p.sub)),
              ],
            ),
          ),
        ),
      );
    }
    if (moment.hasMedia && moment.isVideo) {
      return MomentVideoPlayer(url: mediaUrlFor(baseUrl, moment.mediaUrl));
    }
    final caption = (moment.caption ?? '').trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(V2Space.x8),
        child: Text(
          caption.isEmpty ? '말없이 남긴 순간' : caption,
          textAlign: TextAlign.center,
          style: V2Text.title.copyWith(color: p.ink, height: 1.5),
        ),
      ),
    );
  }
}

class MomentVideoPlayer extends StatefulWidget {
  final String url;
  const MomentVideoPlayer({super.key, required this.url});

  @override
  State<MomentVideoPlayer> createState() => _MomentVideoPlayerState();
}

class _MomentVideoPlayerState extends State<MomentVideoPlayer> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _ctrl
            ..setLooping(true)
            ..play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    if (_failed) {
      return Center(
        child: Text('영상을 불러오지 못했어요', style: V2Text.cap.copyWith(color: p.sub)),
      );
    }
    if (!_ready) {
      return const Center(
        child: V2SkeletonBox(height: 200, radius: V2Radius.card),
      );
    }
    void toggle() {
      setState(() => _muted = !_muted);
      _ctrl.setVolume(_muted ? 0 : 1);
    }

    return Semantics(
      button: true,
      label: _muted ? '소리 켜기' : '소리 끄기',
      onTap: toggle,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: toggle,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _ctrl.value.aspectRatio,
                child: VideoPlayer(_ctrl),
              ),
              Positioned(
                right: V2Space.x4,
                bottom: V2Space.x4,
                child: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 댓글 목록 + 입력. Reports the count to the viewer.
class MomentCommentSheet extends StatefulWidget {
  final int postId;
  final int? myUserId;
  final AuthService auth;
  final ValueChanged<int> onCount;

  const MomentCommentSheet({
    super.key,
    required this.postId,
    required this.myUserId,
    required this.auth,
    required this.onCount,
  });

  @override
  State<MomentCommentSheet> createState() => _MomentCommentSheetState();
}

class _MomentCommentSheetState extends State<MomentCommentSheet> {
  late final ApiClient _api;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _failed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      baseUrl: widget.auth.baseUrl,
      tokenProvider: () => widget.auth.token,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _api.close();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final body = await _api.getJson('/api/setlog/${widget.postId}/comments');
      if (!mounted) return;
      final list = body['comments'];
      setState(() {
        _comments = list is List
            ? list.map((c) => Map<String, dynamic>.from(c as Map)).toList()
            : [];
        _loading = false;
      });
      widget.onCount(_comments.length);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final body = await _api.postJson(
        '/api/setlog/${widget.postId}/comments',
        body: {'body': text},
      );
      if (!mounted) return;
      final comment = body['comment'];
      if (comment != null) {
        setState(
          () => _comments.add(Map<String, dynamic>.from(comment as Map)),
        );
        widget.onCount(_comments.length);
      }
      _ctrl.clear();
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '댓글을 남기지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    final id = comment['id'];
    try {
      await _api.deleteJson('/api/setlog/${widget.postId}/comments/$id');
      if (!mounted) return;
      setState(() => _comments.removeWhere((c) => c['id'] == id));
      widget.onCount(_comments.length);
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '댓글을 지우지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const V2SkeletonList(count: 2)
        else if (_failed)
          V2ErrorState(title: '댓글을 불러오지 못했어요', onRetry: _load)
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: V2Space.x6),
            child: Center(
              child: Text(
                '아직 댓글이 없어요',
                style: V2Text.cap.copyWith(color: p.sub),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _comments.length,
              itemBuilder: (_, i) {
                final c = _comments[i];
                final mine = '${c['user_id']}' == '${widget.myUserId}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: V2Space.x2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? '나' : '${c['author'] ?? '상대'}',
                              style: V2Text.label.copyWith(color: p.sub),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c['body']}',
                              style: V2Text.body.copyWith(color: p.ink),
                            ),
                          ],
                        ),
                      ),
                      if (mine)
                        V2IconButton(
                          icon: V2Icons.close,
                          tooltip: '댓글 지우기',
                          onPressed: () => _delete(c),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: V2Space.x2),
        V2TextField(
          key: const Key('moment_comment_field'),
          label: '댓글',
          hint: '한마디 남기기',
          controller: _ctrl,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          suffix: V2IconButton(
            icon: V2Icons.send,
            tooltip: '댓글 보내기',
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
