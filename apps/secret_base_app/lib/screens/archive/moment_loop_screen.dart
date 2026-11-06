import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

enum _FeedTab { today, week, past }

/// 기록 (구 MomentLoop): 오늘 카드, 오늘/이번 주/지난 기록, 작성기.
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

  _FeedTab _tab = _FeedTab.today;
  bool _gridView = true;
  bool _openedInitialTarget = false;
  late DateTime _weekStart;
  TodayState? _today;
  bool _todayLoading = true;
  bool _todayFailed = false;
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
    unawaited(_loadViewMode());
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

  Future<void> _loadViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final grid = prefs.getBool('moment_loop_grid_view') ?? true;
      if (mounted && grid != _gridView) setState(() => _gridView = grid);
    } catch (_) {}
  }

  Future<void> _toggleViewMode() async {
    final next = !_gridView;
    setState(() => _gridView = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('moment_loop_grid_view', next);
    } catch (_) {}
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
      setState(() {
        _today = state;
        _todayLoading = false;
        _todayFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _todayLoading = false;
          _todayFailed = true;
        });
      }
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

  Future<void> _openComposer({bool todayMoment = true}) async {
    final created = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MomentComposerPage(
          controller: _controller,
          outbox: _outbox,
          mediaPicker: widget.mediaPicker,
          startWithTodayMoment: todayMoment,
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
    final day = dateOnly(date);
    final thisWeek = mondayOf(DateTime.now());
    setState(() {
      if (day == dateOnly(DateTime.now())) {
        _tab = _FeedTab.today;
      } else if (mondayOf(day) == thisWeek) {
        _tab = _FeedTab.week;
        _weekStart = thisWeek;
      } else {
        _tab = _FeedTab.past;
      }
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

  void _showCalendar() {
    final days = <String>{};
    for (final m in _controller.state.moments) {
      final d = momentDay(m);
      if (d != null) days.add(dayKey(d));
    }
    showV2Sheet<void>(
      context,
      title: '날짜로 찾기',
      builder: (sheetContext) => MomentCalendarSheet(
        month: _weekStart,
        daysWithMoments: days,
        onDay: (day) {
          Navigator.pop(sheetContext);
          setState(() {
            _weekStart = mondayOf(day);
            _tab = _FeedTab.week;
          });
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  bool get _isCurrentWeek => _weekStart == mondayOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final drafts = _outbox.drafts;
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: V2Header(
          title: '기록',
          actions: [
            if (drafts.isNotEmpty)
              V2IconButton(
                key: const Key('moment_drafts_entry'),
                icon: V2Icons.refresh,
                tooltip: '올리는 중인 기록 ${drafts.length}개',
                dot: drafts.any((d) => d.status == UploadDraftStatus.failed),
                onPressed: _showDrafts,
              ),
            if (!_unpaired)
              V2IconButton(
                key: const Key('moment_add'),
                icon: V2Icons.add,
                tooltip: '순간 남기기',
                onPressed: () => _openComposer(),
              ),
          ],
        ),
        body: SafeArea(top: false, child: _body(p)),
      ),
    );
  }

  Widget _body(V2Palette p) {
    final state = _controller.state;
    if (_unpaired) {
      return V2EmptyState.unpaired(
        onAction:
            widget.onGoPairing ??
            () => Navigator.of(context).popUntil((r) => r.isFirst),
      );
    }
    final failed = state.status == MomentLoopStatus.failure;
    final loading =
        state.status != MomentLoopStatus.ready &&
        state.moments.isEmpty &&
        !failed;
    final me = _userId;
    final partner = _partnerName;
    final drafts = _outbox.drafts;
    final offline = _errorCode == 'network_error';

    final groups = groupMoments(state.moments);
    final today = dateOnly(DateTime.now());
    final thisWeek = mondayOf(today);

    final Widget feed;
    if (failed && state.moments.isEmpty) {
      feed = offline
          ? V2ErrorState.offline(onRetry: _refresh)
          : V2ErrorState(
              title: '기록을 불러오지 못했어요',
              body: '잠시 후 다시 시도해 주세요.',
              onRetry: _refresh,
            );
    } else if (loading) {
      feed = const SingleChildScrollView(
        padding: EdgeInsets.all(V2Space.page),
        physics: NeverScrollableScrollPhysics(),
        child: MomentFeedSkeleton(),
      );
    } else {
      feed = switch (_tab) {
        _FeedTab.today => _todayFeed(groups, today, me, partner),
        _FeedTab.week => _weekFeed(groups, me, partner),
        _FeedTab.past => _pastFeed(groups, thisWeek, me, partner),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.page,
            V2Space.x2,
            V2Space.page,
            V2Space.x3,
          ),
          child: MomentTodayCard(
            state: _today,
            loading: _todayLoading,
            failed: _todayFailed,
            myName: _myName,
            partnerName: partner,
            onCompose: () => _openComposer(),
            onOpenLoop: () => setState(() => _tab = _FeedTab.today),
          ),
        ),
        if (drafts.isNotEmpty || _storageError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Space.page,
              0,
              V2Space.page,
              V2Space.x3,
            ),
            child: _storageError != null
                ? V2Banner(tone: V2BannerTone.err, message: _storageError!)
                : MomentUploadBanner(
                    drafts: drafts,
                    onRetry: _resumeUploads,
                    onOpen: _showDrafts,
                  ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V2Space.page),
          child: V2Segmented<_FeedTab>(
            segments: const [
              V2Segment(value: _FeedTab.today, label: '오늘'),
              V2Segment(value: _FeedTab.week, label: '이번 주'),
              V2Segment(value: _FeedTab.past, label: '지난 기록'),
            ],
            selected: _tab,
            onChanged: (t) => setState(() {
              _tab = t;
              if (t == _FeedTab.week) _weekStart = mondayOf(DateTime.now());
            }),
          ),
        ),
        if (failed && state.moments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Space.page,
              V2Space.x3,
              V2Space.page,
              0,
            ),
            child: offline
                ? V2Banner.offline()
                : V2Banner(
                    tone: V2BannerTone.warn,
                    message: '최신 기록을 불러오지 못했어요',
                    actionLabel: '다시 시도',
                    onAction: _refresh,
                  ),
          ),
        Expanded(child: feed),
      ],
    );
  }

  Widget _scroll(List<Widget> children) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        V2Space.page,
        V2Space.x2,
        V2Space.page,
        V2Space.x12,
      ),
      children: children,
    ),
  );

  Widget _toolbar({required bool weekNav, String? label}) => MomentWeekToolbar(
    weekStart: _weekStart,
    isCurrentWeek: _isCurrentWeek,
    showWeekNav: weekNav,
    label: label,
    onPrev: () => setState(
      () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
    ),
    onNext: _isCurrentWeek
        ? null
        : () => setState(
            () => _weekStart = _weekStart.add(const Duration(days: 7)),
          ),
    onCalendar: _showCalendar,
    gridView: _gridView,
    onToggleView: _toggleViewMode,
  );

  Widget _emptyFor({required String title, String? body, bool cta = true}) {
    return V2EmptyState(
      key: const Key('moment_empty'),
      illustration: const V2SceneIllustration(V2Scene.photo),
      title: title,
      body: body,
      actionLabel: cta ? '순간 남기기' : null,
      onAction: cta ? () => _openComposer() : null,
    );
  }

  Widget _todayFeed(
    List<List<Moment>> groups,
    DateTime today,
    int? me,
    String partner,
  ) {
    final todays = groups.where((g) => momentDay(g.first) == today).toList();
    return _scroll([
      _toolbar(weekNav: false, label: '오늘의 기록'),
      if (todays.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: V2Space.x4),
          child: _emptyFor(
            title: '오늘은 아직 기록이 없어요',
            body: '사진 한 장, 한 줄이면 충분해요.',
          ),
        )
      else
        MomentDaySection(
          day: today,
          groups: todays,
          gridView: _gridView,
          baseUrl: _baseUrl,
          myUserId: me,
          myName: _myName,
          partnerName: partner,
          onTap: _openDetail,
        ),
    ]);
  }

  Widget _weekFeed(List<List<Moment>> groups, int? me, String partner) {
    final end = _weekStart.add(const Duration(days: 7));
    final inWeek = groups.where((g) {
      final d = momentDay(g.first);
      return d != null && !d.isBefore(_weekStart) && d.isBefore(end);
    }).toList();
    final days = <DateTime, List<List<Moment>>>{};
    for (final g in inWeek) {
      days.putIfAbsent(momentDay(g.first)!, () => []).add(g);
    }
    final ordered = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return _scroll([
      _toolbar(weekNav: true),
      if (ordered.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: V2Space.x4),
          child: _isCurrentWeek
              ? _emptyFor(
                  title: '이번 주 첫 순간을 남겨 보세요',
                  body: '사진·짧은 영상·한 줄 중 하나면 충분해요.',
                )
              : _emptyFor(title: '이 주에는 기록이 없어요', cta: false),
        )
      else
        for (final d in ordered)
          MomentDaySection(
            day: d,
            groups: days[d]!,
            gridView: _gridView,
            baseUrl: _baseUrl,
            myUserId: me,
            myName: _myName,
            partnerName: partner,
            onTap: _openDetail,
          ),
    ]);
  }

  Widget _pastFeed(
    List<List<Moment>> groups,
    DateTime thisWeek,
    int? me,
    String partner,
  ) {
    final past = groups.where((g) {
      final d = momentDay(g.first);
      return d != null && d.isBefore(thisWeek);
    }).toList();
    final months = <DateTime, List<List<Moment>>>{};
    for (final g in past) {
      final d = momentDay(g.first)!;
      months.putIfAbsent(DateTime(d.year, d.month), () => []).add(g);
    }
    final ordered = months.keys.toList()..sort((a, b) => b.compareTo(a));
    return _scroll([
      _toolbar(weekNav: false, label: '달별로 모아 봤어요'),
      if (ordered.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: V2Space.x4),
          child: _emptyFor(
            title: '지난 기록이 아직 없어요',
            body: '지난주까지 남긴 기록이 여기에 쌓여요.',
            cta: false,
          ),
        )
      else
        for (final m in ordered)
          MomentMonthSection(
            month: m,
            groups: months[m]!,
            bothDays: _bothDays(months[m]!, me),
            gridView: _gridView,
            baseUrl: _baseUrl,
            myUserId: me,
            myName: _myName,
            partnerName: partner,
            onTap: _openDetail,
          ),
    ]);
  }

  /// Days of the month where both of us left a moment.
  int _bothDays(List<List<Moment>> groups, int? me) {
    final mine = <String>{};
    final theirs = <String>{};
    for (final g in groups) {
      final d = momentDay(g.first);
      if (d == null) continue;
      (g.first.userId == me ? mine : theirs).add(dayKey(d));
    }
    return mine.intersection(theirs).length;
  }
}
