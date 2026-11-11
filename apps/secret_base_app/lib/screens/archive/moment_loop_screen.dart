import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/today_api.dart';
import '../../features/moment_loop/application/moment_loop_controller.dart';
import '../../features/moment_loop/application/upload_outbox.dart';
import '../../features/moment_loop/data/moment_loop_repository.dart';
import '../../features/moment_loop/domain/moment.dart';
import '../../features/moment_loop/domain/moment_edit.dart';
import '../../v2/v2.dart';
import 'moment/couple_names.dart';
import 'moment/moment_composer.dart';
import 'moment/moment_detail.dart';
import 'moment/moment_feed.dart';
import 'moment/moment_format.dart';
import 'moment/moment_sheets.dart';
import 'moment/moment_story_feed.dart';

/// 기록 (2.1): 하루 한 장 피드 + 스토리 줄 + "내 순간 올리기", 모아보기 달력, 작성기.
class MomentLoopScreen extends StatefulWidget {
  final http.Client? client;
  final String? baseUrl;
  final int? userId;
  final MomentLoopController? controller;
  final UploadOutbox? outbox;
  final int? initialPostId;
  final String? initialDraftId;
  final Future<List<MomentMedia>> Function()? mediaPicker;

  /// Opens the composer right away with 오늘의 순간 switched on.
  final bool openComposer;

  /// Pre-links a 비밀지도 place in the composer ("이 장소에서 순간 남기기").
  final int? initialPinId;
  final String? initialPinName;

  /// Where the "연결하러 가기" button of the unpaired state goes.
  final VoidCallback? onGoPairing;

  const MomentLoopScreen({
    super.key,
    this.client,
    this.baseUrl,
    this.userId,
    this.controller,
    this.outbox,
    this.initialPostId,
    this.initialDraftId,
    this.mediaPicker,
    this.openComposer = false,
    this.initialPinId,
    this.initialPinName,
    this.onGoPairing,
  });

  @override
  State<MomentLoopScreen> createState() => _MomentLoopScreenState();
}

class _MomentLoopScreenState extends State<MomentLoopScreen> {
  final _auth = AuthService();
  late final ApiClient _apiClient;
  late final MomentLoopController _controller;
  late final bool _ownsController;
  late final UploadOutbox _outbox;
  TodayApi? _todayApi;

  /// 모아보기(달력) instead of the one-day-per-page feed.
  bool _calendar = false;

  /// Day the feed should scroll to next (calendar pick, after posting).
  DateTime? _jumpTo;
  bool _openedInitialTarget = false;
  late DateTime _weekStart;
  TodayState? _today;
  String? _partner;
  String? _storageError;
  int _lastDraftCount = 0;
  bool _hadFailure = false;

  String get _baseUrl => widget.baseUrl ?? _auth.baseUrl;
  String get _myName => CoupleNames.myNickname(_auth);

  int? get _userId {
    if (widget.userId != null) return widget.userId;
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  String get _partnerName {
    if (_partner != null) return _partner!;
    final me = _userId;
    for (final m in _controller.state.moments) {
      if (m.userId != me && (m.userName ?? '').trim().isNotEmpty) {
        return m.userName!.trim();
      }
    }
    return CoupleNames.cachedPartner ?? '상대';
  }

  String? get _errorCode {
    final error = _controller.state.error;
    if (error == null) return null;
    return error is MomentLoopException ? error.code : '$error';
  }

  bool get _unpaired => _errorCode == 'active_couple_required';

  @override
  void initState() {
    super.initState();
    _weekStart = mondayOf(DateTime.now());
    _apiClient = ApiClient(
      baseUrl: _baseUrl,
      tokenProvider: () => _auth.token,
      client: widget.client,
    );
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = MomentLoopController(
        repository: HttpMomentLoopRepository(apiClient: _apiClient),
        currentUserId: () => _userId,
      );
      _ownsController = true;
    }
    _controller.addListener(_onChanged);
    _outbox = widget.outbox ?? UploadOutbox.instance;
    _outbox.addListener(_onOutboxChanged);
    _outbox.feedRevision.addListener(_onFeedChanged);
    _lastDraftCount = _outbox.drafts.length;
    unawaited(_initializeOutbox());
    unawaited(_loadPartner());
    unawaited(_loadToday());
    unawaited(_loadPosts());
    if (widget.openComposer && widget.initialDraftId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openComposer());
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _outbox.removeListener(_onOutboxChanged);
    _outbox.feedRevision.removeListener(_onFeedChanged);
    if (_ownsController) _controller.dispose();
    _todayApi?.close();
    _apiClient.close();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onOutboxChanged() {
    if (!mounted) return;
    final drafts = _outbox.drafts;
    final failed = drafts.any((d) => d.status == UploadDraftStatus.failed);
    if (drafts.length < _lastDraftCount && !failed && !_hadFailure) {
      showV2Snack(context, '기록을 올렸어요');
    }
    _hadFailure = failed;
    _lastDraftCount = drafts.length;
    setState(() {});
  }

  void _onFeedChanged() {
    if (!mounted) return;
    unawaited(_loadPosts());
    unawaited(_loadToday());
  }

  Future<void> _initializeOutbox() async {
    try {
      await _outbox.initialize();
      if (mounted && widget.initialDraftId != null && !_openedInitialTarget) {
        _openedInitialTarget = true;
        await _openDraft(widget.initialDraftId!);
      }
    } catch (_) {
      if (mounted) setState(() => _storageError = '기기의 임시저장 공간을 열지 못했어요');
    }
  }

  void _resumeUploads() {
    unawaited(
      _outbox.resume().catchError((Object _) {
        if (mounted) {
          setState(() => _storageError = '임시저장을 읽지 못했어요. 저장 공간을 확인해 주세요.');
        }
      }),
    );
  }

  Future<void> _loadPartner() async {
    final name = await CoupleNames.loadPartner(
      _apiClient,
      userKey: '${_userId ?? ''}',
    );
    if (mounted && name != null) setState(() => _partner = name);
  }

  Future<void> _loadToday() async {
    _todayApi ??= TodayApi(
      baseUrl: _baseUrl,
      token: _auth.token ?? '',
      client: widget.client,
    );
    try {
      final state = await _todayApi!.fetchState();
      if (!mounted) return;
      setState(() => _today = state);
    } catch (_) {
      // The feed works without it; the CTA just falls back to my own posts.
    }
  }

  Future<void> _loadPosts() async {
    await _controller.loadWeek(_weekStart);
    if (!mounted ||
        _openedInitialTarget ||
        widget.initialPostId == null ||
        widget.initialDraftId != null) {
      return;
    }
    if (_controller.state.status != MomentLoopStatus.ready) return;
    _openedInitialTarget = true;
    final groups = groupMoments(
      _controller.state.moments,
    ).where((g) => g.any((p) => p.id == widget.initialPostId)).toList();
    if (groups.isEmpty) {
      showV2Snack(context, '이 순간을 찾을 수 없어요', tone: V2Tone.warn);
    } else {
      _openDetail(groups.first, initialPostId: widget.initialPostId);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadPosts(), _loadToday()]);
  }

  // ── Composer / drafts ──────────────────────────────────────────────────────

  Future<void> _openComposer({
    bool todayMoment = true,
    MomentStartSource source = MomentStartSource.none,
  }) async {
    final created = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MomentComposerPage(
          controller: _controller,
          outbox: _outbox,
          mediaPicker: widget.mediaPicker,
          startWithTodayMoment: todayMoment,
          startSource: source,
          initialPinId: widget.initialPinId,
          initialPinName: widget.initialPinName,
        ),
      ),
    );
    if (!mounted || created is! DateTime) return;
    _showDate(created);
    _resumeUploads();
    await _loadPosts();
  }

  void _showDate(DateTime date) {
    setState(() {
      _calendar = false;
      _jumpTo = dateOnly(date);
    });
  }

  Future<void> _editMoment(Moment post) async {
    final matches = _controller.state.moments.where((p) => p.id == post.id);
    if (matches.isEmpty) {
      if (mounted) showV2Snack(context, '이 순간을 찾을 수 없어요', tone: V2Tone.warn);
      return;
    }
    final selected = matches.first;
    final original =
        _controller.state.moments
            .where((p) => p.sessionKey == selected.sessionKey)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final first = original.first;
    final fields = MomentDraft(
      caption: first.caption ?? '',
      takenAt: DateTime.tryParse(first.takenAt ?? '') ?? DateTime.now(),
      capturedAt: DateTime.tryParse(first.capturedAt ?? '') ?? DateTime.now(),
      sessionId: first.sessionId ?? '',
      mapPinId: first.mapPinId,
      tags: _tagsOf(first.extra['tags']),
    );
    final result = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MomentComposerPage(
          controller: _controller,
          outbox: _outbox,
          mediaPicker: widget.mediaPicker,
          edit: MomentEdit(
            original: original,
            fields: fields,
            items: original.map(MomentEditItem.existing).toList(),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(); // the stale detail
      _resumeUploads();
    }
  }

  List<String> _tagsOf(Object? value) {
    if (value is List) return value.map((t) => '$t').toList(growable: false);
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return const ['#momentloop'];
  }

  Future<void> _openDraft(String id) async {
    final draft = await _outbox.readDraft(id);
    final edit = await _outbox.readEdit(id);
    if (!mounted) return;
    if (draft == null) {
      showV2Snack(context, '이 임시저장을 찾을 수 없어요', tone: V2Tone.warn);
      return;
    }
    if (_outbox.drafts.any(
      (d) => d.id == id && d.status == UploadDraftStatus.uploading,
    )) {
      showV2Snack(context, '지금 올리는 중이에요');
      return;
    }
    final saved = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MomentComposerPage(
          controller: _controller,
          outbox: _outbox,
          draftId: id,
          initialDraft: draft,
          edit: edit,
          mediaPicker: widget.mediaPicker,
        ),
      ),
    );
    if (saved != null && mounted) _resumeUploads();
  }

  void _showDrafts() {
    showV2Sheet<void>(
      context,
      title: '올리는 중인 기록',
      subtitle: '올리지 못한 기록은 이유와 함께 보여 드려요',
      builder: (sheetContext) => MomentDraftsSheet(
        outbox: _outbox,
        onRetry: _resumeUploads,
        onOpenDraft: (id) {
          Navigator.pop(sheetContext);
          unawaited(_openDraft(id));
        },
      ),
    );
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  void _openDetail(List<Moment> group, {int? initialPostId}) {
    final locked = group.first.todayLocked && group.first.userId != _userId;
    if (locked) {
      showV2Snack(context, '내 순간을 남기면 $_partnerName의 순간이 열려요');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentDetailPage(
          group: group,
          myUserId: _userId,
          myName: _myName,
          partnerName: _partnerName,
          initialPostId: initialPostId,
          onEdit: _editMoment,
          onDelete: _deleteMoment,
          onReaction: (sessionId, emoji) =>
              _controller.toggleReaction(sessionId: sessionId, emoji: emoji),
          onDesignateToday: (id) async {
            await _controller.designateToday(id);
            unawaited(_loadToday());
          },
          onRemoveTodayDesignation: () async {
            await _controller.removeTodayDesignation();
            unawaited(_loadToday());
          },
        ),
      ),
    );
  }

  Future<bool> _deleteMoment(Moment post) async {
    try {
      await _controller.deleteMoment(post.id);
      unawaited(_loadToday());
      if (mounted) showV2Snack(context, '순간을 지웠어요');
      return true;
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '지우지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
      return false;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  Future<void> _heart(Moment post) async {
    try {
      await _controller.toggleReaction(sessionId: post.sessionKey, emoji: '❤️');
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '하트를 보내지 못했어요', tone: V2Tone.err);
      }
    }
  }

  void _openComments(Moment post) {
    if (post.todayLocked && post.userId != _userId) {
      showV2Snack(context, '내 순간을 남기면 $_partnerName의 순간이 열려요');
      return;
    }
    showV2Sheet<void>(
      context,
      title: '댓글',
      builder: (_) => MomentCommentSheet(
        postId: post.id,
        myUserId: _userId,
        auth: _auth,
        onCount: (_) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final state = _controller.state;
    final failed = state.status == MomentLoopStatus.failure;
    final loading =
        state.status != MomentLoopStatus.ready &&
        state.moments.isEmpty &&
        !failed;
    final offline = _errorCode == 'network_error';

    Widget? plain;
    if (_unpaired) {
      plain = V2EmptyState.unpaired(
        onAction:
            widget.onGoPairing ??
            () => Navigator.of(context).popUntil((r) => r.isFirst),
      );
    } else if (failed && state.moments.isEmpty) {
      plain = offline
          ? V2ErrorState.offline(onRetry: _refresh)
          : V2ErrorState(
              title: '기록을 불러오지 못했어요',
              body: '잠시 후 다시 시도해 주세요.',
              onRetry: _refresh,
            );
    } else if (loading) {
      plain = const SingleChildScrollView(
        padding: EdgeInsets.all(V2Space.page),
        physics: NeverScrollableScrollPhysics(),
        child: MomentFeedSkeleton(),
      );
    }
    if (plain != null) {
      return V2Theme(
        child: Scaffold(
          backgroundColor: p.bg,
          appBar: const V2Header(title: '기록'),
          body: SafeArea(top: false, child: plain),
        ),
      );
    }

    final me = _userId;
    final pages = buildMomentDayPages(state.moments, me);
    final todayKey = dayKey(dateOnly(DateTime.now()));
    final todayPage = pages.where((pg) => dayKey(pg.day) == todayKey);
    final postedToday = todayPage.isNotEmpty && todayPage.first.hasMine;
    final partnerToday = todayPage.isNotEmpty && todayPage.first.hasTheirs
        ? todayPage.first.theirs.first
        : null;
    // When I have not posted, today's page is the "내 순간 올리기" page.
    final feedPages = postedToday
        ? pages
        : pages.where((pg) => dayKey(pg.day) != todayKey).toList();

    final drafts = _outbox.drafts;
    Widget? banner;
    if (_storageError != null) {
      banner = V2Banner(tone: V2BannerTone.err, message: _storageError!);
    } else if (drafts.isNotEmpty) {
      banner = MomentUploadBanner(
        key: const Key('moment_drafts_entry'),
        drafts: drafts,
        onRetry: _resumeUploads,
        onOpen: _showDrafts,
      );
    } else if (failed) {
      banner = offline
          ? V2Banner.offline()
          : V2Banner(
              tone: V2BannerTone.warn,
              message: '최신 기록을 불러오지 못했어요',
              actionLabel: '다시 시도',
              onAction: _refresh,
            );
    }

    final body = _calendar
        ? MomentMonthGrid(
            pages: pages,
            baseUrl: _baseUrl,
            myUserId: me,
            todayOpen: postedToday,
            onShowFeed: () => setState(() => _calendar = false),
            onPickDay: _showDate,
          )
        : MomentStoryFeed(
            pages: feedPages,
            showTodayCta: !postedToday,
            partnerPostedToday:
                partnerToday != null || (_today?.hasPartnerMoment ?? false),
            partnerTodayMoment: partnerToday,
            baseUrl: _baseUrl,
            myUserId: me,
            myName: _myName,
            partnerName: _partnerName,
            onCompose: (source) => _openComposer(source: source),
            onOpenGroup: (group) => _openDetail(group),
            onHeart: _heart,
            onComments: _openComments,
            onShowCalendar: () => setState(() => _calendar = true),
            banner: banner == null ? null : V2Theme(child: banner),
            jumpTo: _jumpTo,
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}
