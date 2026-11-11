import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth_service.dart';
import '../../core/fortune_api.dart';
import '../../core/push/push_platform.dart';
import '../../core/push/push_service.dart';
import '../../core/today_api.dart';
import '../../features/home/application/home_controller.dart';
import '../../features/home/data/home_overview_repository.dart';
import '../../features/home/domain/home_overview.dart';
import '../../v2/v2.dart';
import '../auth/partner_screen.dart';
import '../relationship/fortune_screen.dart';
import '../relationship/relationship_understanding_screen.dart';
import '../secret_base/base_api.dart';
import '../secret_base/base_common.dart';
import '../secret_base/secret_base_screen.dart';
import '../settings/notification_settings_screen.dart';
import 'home_focus.dart';
import 'home_format.dart';
import 'start_date_sheet.dart';
import 'today_loop_viewer.dart';
import 'today_poke.dart';

/// 홈: 오늘 우리 둘의 순간이 어떤 상태인지 한눈에 보여 주고, 눌러서 바로
/// 남기게 하는 화면.
class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final RelationshipAssessmentStatus? relationshipStatus;
  final Future<TodayState> Function()? todayStateLoader;
  final HomeController? controller;

  /// True while the shell knows the device is offline.
  final ValueListenable<bool>? offline;

  /// Whether the OS blocks notifications (drives the 알림 거부 banner).
  final Future<bool> Function()? notificationsBlocked;

  /// Number of rewards that can be claimed now (badge on the 비밀기지 shortcut).
  final Future<int> Function()? claimableRewards;

  /// Saves the first day (defaults to `PATCH /api/couple/info`).
  final Future<void> Function(DateTime day)? saveStartDate;

  final TodayPoke? poke;

  /// Whether today's fortune was opened (defaults to [HomeFortuneSeen]).
  final Future<bool> Function()? fortuneSeen;

  /// One-line title of today's fortune, or null (defaults to the API).
  final Future<String?> Function()? fortuneHeadline;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    this.relationshipStatus,
    this.todayStateLoader,
    this.controller,
    this.offline,
    this.notificationsBlocked,
    this.claimableRewards,
    this.saveStartDate,
    this.poke,
    this.fortuneSeen,
    this.fortuneHeadline,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  late HomeController _controller;
  var _ownsController = false;
  late final TodayPoke _poke = widget.poke ?? TodayPoke();
  bool _pokedToday = false;
  bool _poking = false;
  bool _notificationsBlocked = false;
  bool _notificationBannerDismissed = false;
  bool _savingStart = false;
  bool _fortuneSeen = false;
  String? _fortuneHeadline;

  /// "나중에" on the focus card, for this visit only.
  bool _momentLater = false;
  bool _fortuneLater = false;

  Map<String, String> get _authHeaders => {
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller ?? _createController());
    _controller.load();
    widget.offline?.addListener(_onOfflineChanged);
    _poke.sentToday().then((v) {
      if (mounted) setState(() => _pokedToday = v);
    });
    _loadSideInfo();
  }

  HomeController _createController() => HomeController(
    HomeOverviewRepository.forAuth(
      _auth,
      todayStateLoader: widget.todayStateLoader,
    ),
  );

  void _attachController(HomeController controller) {
    _controller = controller;
    _ownsController = widget.controller == null;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onOfflineChanged() {
    if (!mounted) return;
    final wasOffline = _offline;
    setState(() {});
    // Back online: refresh what we are showing.
    if (!_offline && wasOffline) _refresh();
  }

  bool get _offline => widget.offline?.value ?? false;

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _attachController(widget.controller ?? _createController());
    _controller.load();
  }

  @override
  void dispose() {
    widget.offline?.removeListener(_onOfflineChanged);
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSideInfo() async {
    final blocked = await (widget.notificationsBlocked ?? _defaultBlocked)();
    final seen = await (widget.fortuneSeen ?? HomeFortuneSeen.today)();
    if (!mounted) return;
    setState(() {
      _notificationsBlocked = blocked;
      _fortuneSeen = seen;
    });
    final headline = await (widget.fortuneHeadline ?? _defaultHeadline)();
    if (mounted) setState(() => _fortuneHeadline = headline);
  }

  Future<String?> _defaultHeadline() async {
    final token = _auth.token;
    if (token == null) return null;
    final api = FortuneApi(baseUrl: _auth.baseUrl, token: token);
    try {
      final today = await api.fetchToday();
      final c = today.personal ?? today.relationship ?? today.emotionalFlow;
      final title = c?.title.trim();
      return title == null || title.isEmpty ? null : title;
    } catch (_) {
      return null;
    } finally {
      api.close();
    }
  }

  static Future<bool> _defaultBlocked() async {
    try {
      if (!PushService.instance.enabled) return false;
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('push_permission_asked') ?? false)) return false;
      return !await FirebasePushPlatform().permissionGranted();
    } catch (_) {
      return false;
    }
  }

  HomeOverview? get _overview => _controller.state.data;
  HomeCoupleInfo? get _couple => _overview?.couple;
  TodayState? get _todayState => _overview?.todayState;
  bool get _initialLoading =>
      _controller.state.status == HomeStatus.loading && _overview == null;
  bool get _fatal =>
      _overview == null && _controller.state.status == HomeStatus.failure;
  bool get _coupleFailed =>
      _overview?.failedSections.contains(HomeSection.couple) ?? false;
  bool get _unpaired => _overview != null && _couple == null && !_coupleFailed;

  Future<void> _refresh() async {
    await _controller.refresh();
    _loadSideInfo();
  }

  String get _myName {
    final user = _auth.user;
    final name = '${user?['Nickname'] ?? user?['UserName'] ?? ''}'.trim();
    return name.isEmpty ? '나' : name;
  }

  String get _partnerName => _couple?.partnerName ?? '짝꿍';

  DateTime? get _startDay => parseDay(_couple?.startDate);

  // ---- actions ----------------------------------------------------------

  Future<void> _createMoment() async {
    await openMomentComposer(context);
    if (mounted) _refresh();
  }

  Future<void> _openLoop() async {
    final state = _todayState;
    if (state == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TodayLoopViewer(
          state: state,
          baseUrl: _auth.baseUrl,
          myName: _myName,
          partnerName: _partnerName,
          reveal: true,
          onPoke: _pokedToday ? null : _sendPoke,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _sendPoke() async {
    if (_poking) return;
    setState(() => _poking = true);
    final outcome = await _poke.send();
    if (!mounted) return;
    setState(() {
      _poking = false;
      if (outcome != PokeOutcome.unavailable) _pokedToday = true;
    });
    switch (outcome) {
      case PokeOutcome.sent:
        showV2Snack(context, '${josa(_partnerName, '을', '를')} 콕 찔렀어요');
      case PokeOutcome.alreadyToday:
        showV2Snack(context, '콕 찌르기는 하루에 한 번만 할 수 있어요');
      case PokeOutcome.unavailable:
        showV2Snack(
          context,
          '지금은 콕 찌를 수 없어요. 잠시 후 다시 해 주세요.',
          tone: V2Tone.err,
        );
    }
  }

  Future<void> _pickStartDate() async {
    if (_savingStart) return;
    final picked = await showStartDateSheet(
      context,
      initial: _startDay,
      subtitle: '연결한 날이 기본이에요. 실제 첫날로 바꿔도 돼요',
    );
    if (picked == null || !mounted) return;
    setState(() => _savingStart = true);
    try {
      final saver = widget.saveStartDate;
      if (saver != null) {
        await saver(picked);
      } else {
        final api = BaseApi(baseUrl: _auth.baseUrl, headers: _authHeaders);
        try {
          await api.patch('/couple/info', {'start_date': isoDay(picked)});
        } finally {
          api.close();
        }
      }
      if (!mounted) return;
      showV2Snack(context, '우리의 첫날을 저장했어요');
      _refresh();
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '저장하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } finally {
      if (mounted) setState(() => _savingStart = false);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  void _openFortune() {
    HomeFortuneSeen.mark();
    setState(() => _fortuneSeen = true);
    _push(
      RelationshipFortuneScreen(
        api: FortuneApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
        onEditProfile: () => _push(
          const RelationshipUnderstandingScreen(editBirthProfileOnly: true),
        ),
        onOpenPartner: () => _push(const PartnerScreen()),
      ),
    );
  }

  void _openBase([int tab = 0]) => _push(
    SecretBaseScreen(
      baseUrl: _auth.baseUrl,
      authHeaders: _authHeaders,
      initialTab: tab,
    ),
  );

  void _openNotifications() => _push(const NotificationSettingsScreen());

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(backgroundColor: V2Colors.bg, body: _body()),
    );
  }

  Widget _body() {
    if (_initialLoading) return const _HomeSkeleton();
    if (_fatal) {
      return SafeArea(
        child: _offline
            ? V2ErrorState.offline(onRetry: _refresh)
            : V2ErrorState(
                title: '홈을 불러오지 못했어요',
                body: '잠시 후 다시 시도해 주세요.',
                retryLabel: '다시 불러오기',
                onRetry: _refresh,
              ),
      );
    }
    if (_unpaired) {
      return SafeArea(
        child: V2EmptyState.unpaired(
          onAction: () => openPartnerScreen(context),
        ),
      );
    }
    final top = MediaQuery.paddingOf(context).top;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(22, top + 14, 22, V2Space.x10),
        children: [
          _header(),
          if (_controller.state.status == HomeStatus.failure) ...[
            const SizedBox(height: V2Space.x4),
            V2Banner(
              tone: V2BannerTone.err,
              message: '새 소식을 불러오지 못했어요. 마지막으로 받은 내용을 보여 줘요.',
              actionLabel: '다시 불러오기',
              onAction: _refresh,
            ),
          ],
          if (_notificationsBlocked && !_notificationBannerDismissed) ...[
            const SizedBox(height: V2Space.x4),
            V2Banner(
              tone: V2BannerTone.warn,
              icon: V2Icons.bellOff,
              title: '알림이 꺼져 있어요',
              message: '새 순간과 콕을 놓칠 수 있어요',
              actionLabel: '설정 열기',
              onAction: _openNotifications,
              onDismiss: () =>
                  setState(() => _notificationBannerDismissed = true),
            ),
          ],
          const SizedBox(height: 22),
          _focus(),
          const SizedBox(height: V2Space.x2),
          ..._rows(),
          if (_showChecklist) ...[
            const SizedBox(height: V2Space.x4),
            _checklist(),
          ],
        ],
      ),
    );
  }

  // header: 날짜 · 함께한 날 · 다음 기념일 · 두 사람

  ({String label, int days})? get _nextEvent {
    final candidates = <({String label, int days})>[];
    final server = _couple?.nextAnniversary;
    if (server != null && server.daysUntil >= 0) {
      candidates.add((label: server.label, days: server.daysUntil));
    }
    final start = _startDay;
    if (start != null) {
      final m = nextAutoMilestone(start);
      if (m != null) candidates.add((label: m.label, days: m.daysUntil));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.days.compareTo(b.days));
    return candidates.first;
  }

  Widget _header() {
    final p = V2Palette.of(context);
    final start = _startDay;
    final dDay = start != null ? dPlus(start) : _couple?.dDay;
    final next = _nextEvent;
    final pill = next == null
        ? null
        : next.days == 0
        ? '오늘은 ${next.label}이에요'
        : '${next.label}까지 ${next.days}일';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthDayWeekday(DateTime.now()),
                style: V2Text.body.copyWith(color: p.muted),
              ),
              const SizedBox(height: 2),
              if (dDay == null)
                _startPrompt()
              else ...[
                Semantics(
                  label: '함께한 지 $dDay일',
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '함께한 지 '),
                          TextSpan(
                            text: '$dDay',
                            style: TextStyle(
                              color: p.point,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const TextSpan(text: '일'),
                        ],
                      ),
                      style: V2Text.display.copyWith(color: p.ink),
                    ),
                  ),
                ),
                if (pill != null) ...[
                  const SizedBox(height: V2Space.x3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: p.soft,
                      borderRadius: V2Radius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.point,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            pill,
                            style: V2Text.cap.copyWith(
                              color: p.sub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(width: V2Space.x3),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(
            child: V2AvatarPair(
              me: _myName,
              partner: _partnerName,
              size: V2AvatarSize.md,
            ),
          ),
        ),
      ],
    );
  }

  Widget _startPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '우리의 첫날을\n알려 주세요',
          style: V2Text.display.copyWith(color: V2Colors.ink),
        ),
        const SizedBox(height: V2Space.x1),
        Text(
          _coupleFailed
              ? '정보를 불러오지 못했어요. 아래로 당겨 새로고침해 보세요.'
              : '연결한 날이 기본이에요. 바꿔도 돼요',
          style: V2Text.cap,
        ),
        if (!_coupleFailed) ...[
          const SizedBox(height: V2Space.x3),
          V2Button(
            label: '첫날 정하기',
            icon: V2Icons.calendar,
            variant: V2ButtonVariant.soft,
            size: V2ButtonSize.sm,
            fullWidth: false,
            loading: _savingStart,
            onPressed: _pickStartDate,
          ),
        ],
      ],
    );
  }

  // 지금 할 일: one card, the most important thing not done yet.

  bool get _todayFailed =>
      _todayState == null || (_overview?.todayLoadFailed ?? true);
  bool get _iPosted {
    final s = _todayState;
    if (s == null) return false;
    return s.myMoment != null ||
        s.status == TodayStatus.selfWaiting ||
        s.status == TodayStatus.complete ||
        s.status == TodayStatus.viewed;
  }

  bool get _partnerPosted {
    final s = _todayState;
    if (s == null) return false;
    return s.hasPartnerMoment ||
        s.partnerMoment != null ||
        s.status == TodayStatus.partnerWaiting ||
        s.status == TodayStatus.complete ||
        s.status == TodayStatus.viewed;
  }

  bool get _momentPending => !_todayFailed && !_iPosted && !_momentLater;
  bool get _fortunePending => !_fortuneSeen && !_fortuneLater;

  Widget _focus() {
    if (_todayFailed) return _todayError();
    final state = _todayState!;
    final steps = (_iPosted ? 0 : 1) + (_fortuneSeen ? 0 : 1);
    if (_momentPending) {
      final partnerFirst = _partnerPosted;
      return HomeFocusCard(
        background: homeMomentFill(
          state.partnerMoment,
          baseUrl: _auth.baseUrl,
          seed: 'today-${state.date}',
          blur: true,
          cacheWidth: 400,
        ),
        kicker: '지금 할 일',
        step: 1,
        steps: steps,
        title: partnerFirst
            ? '${josa(_partnerName, '이', '가')} 오늘의 순간을\n남기고 기다려요'
            : '오늘의 순간을\n남겨 볼까요?',
        sub: partnerFirst
            ? '나도 한 장 남기면 둘의 사진이 열려요'
            : '${josa(_partnerName, '와', '과')} 서로의 오늘을 바꿔 봐요',
        action: partnerFirst ? '나도 남기기' : '오늘의 순간 남기기',
        actionIcon: V2Icons.camera,
        onAction: _offline ? null : _createMoment,
        laterLabel: '나중에',
        onLater: () => setState(() => _momentLater = true),
      );
    }
    if (_fortunePending) {
      return HomeFocusCard(
        background: const HomeFortuneBackground(),
        kicker: '지금 할 일',
        step: steps,
        steps: steps,
        title: '오늘의 운세가\n도착했어요',
        sub: '열어 보면 오늘 하루 힌트가 나와요',
        action: '열어 보기',
        onAction: _openFortune,
        laterLabel: '나중에',
        onLater: () => setState(() => _fortuneLater = true),
      );
    }
    if (_iPosted && !_partnerPosted) {
      return HomeFocusCard(
        background: homeMomentFill(
          state.myMoment,
          baseUrl: _auth.baseUrl,
          seed: 'mine-${state.date}',
          cacheWidth: 800,
        ),
        kicker: '오늘의 순간',
        title: '${josa(_partnerName, '을', '를')} 기다리는 중이에요',
        sub: '${josa(_partnerName, '이', '가')} 남기면 둘의 사진이 함께 열려요',
        action: _pokedToday
            ? '오늘은 콕 찔렀어요'
            : '${josa(_partnerName, '에게', '에게')} 콕 찌르기',
        actionIcon: V2Icons.heart,
        busy: _poking,
        onAction: _pokedToday || _offline ? null : _sendPoke,
      );
    }
    if (_iPosted) {
      final mine = clockLabel(
        state.myMoment?.capturedAt ?? state.myMoment?.takenAt,
      );
      final theirs = clockLabel(
        state.partnerMoment?.capturedAt ?? state.partnerMoment?.takenAt,
      );
      return HomeFocusCard(
        background: Row(
          children: [
            Expanded(
              child: homeMomentFill(
                state.myMoment,
                baseUrl: _auth.baseUrl,
                seed: 'mine-${state.date}',
                cacheWidth: 500,
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: homeMomentFill(
                state.partnerMoment,
                baseUrl: _auth.baseUrl,
                seed: 'partner-${state.date}',
                cacheWidth: 500,
              ),
            ),
          ],
        ),
        kicker: '✓ 오늘 할 일 끝',
        title: '오늘의 순간',
        sub: [
          if (mine != null) '$_myName $mine',
          if (theirs != null) '$_partnerName $theirs',
        ].join(' · '),
        onTap: _openLoop,
        semanticLabel: '오늘의 순간, 둘 다 남겼어요. 크게 보기',
      );
    }
    // Moment postponed with "나중에" and fortune already handled.
    return HomeFocusCard(
      background: homeMomentFill(
        null,
        baseUrl: _auth.baseUrl,
        seed: 'later-${state.date}',
      ),
      kicker: '오늘의 순간',
      title: '오늘의 순간은\n아직 비어 있어요',
      sub: '생각날 때 한 장 남겨 주세요',
      action: '남기기',
      actionIcon: V2Icons.camera,
      onAction: _offline ? null : _createMoment,
    );
  }

  Widget _todayError() {
    return V2Card(
      child: Column(
        children: [
          const V2Art(icon: V2Icons.error, tone: V2Tone.err),
          const SizedBox(height: V2Space.x3),
          Text(
            '오늘의 순간을 불러오지 못했어요',
            style: V2Text.head,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: V2Space.x1),
          Text(
            V2Text.keepAll('잠시 후 다시 해 보세요. 아래 다른 기능은 그대로 쓸 수 있어요.'),
            style: V2Text.cap,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: V2Space.x4),
          V2Button(
            label: '다시 불러오기',
            icon: V2Icons.refresh,
            variant: V2ButtonVariant.soft,
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  // quiet rows

  List<Widget> _rows() {
    final rows = <Widget>[];
    final state = _todayState;
    final fortuneIsFocus = !_momentPending && _fortunePending;
    if (!fortuneIsFocus) {
      rows.add(
        HomeRow(
          icon: V2Icons.sparkle,
          title: '오늘의 운세',
          sub: _fortuneSeen
              ? (_fortuneHeadline ?? '오늘 운세를 봤어요')
              : '아직 안 봤어요 · 한 줄 열어 보기',
          hot: !_fortuneSeen,
          dot: !_fortuneSeen,
          onTap: _openFortune,
        ),
      );
    }
    if (fortuneIsFocus && state != null && !_todayFailed) {
      final both = _iPosted && _partnerPosted;
      rows.add(
        HomeRow(
          icon: V2Icons.camera,
          title: '오늘의 순간',
          sub: both
              ? '둘 다 남겼어요 · 크게 보기'
              : _iPosted
              ? '${josa(_partnerName, '을', '를')} 기다리는 중'
              : '아직 안 남겼어요',
          trailing: both
              ? _thumbs([state.myMoment, state.partnerMoment])
              : null,
          onTap: both
              ? _openLoop
              : _iPosted
              ? null
              : _createMoment,
        ),
      );
    }
    final memory = _overview?.memoryCard;
    if (memory != null &&
        !(_overview?.failedSections.contains(HomeSection.memory) ?? false)) {
      final title = memory.caption?.trim().isNotEmpty == true
          ? memory.caption!
          : (memory.placeName ?? '그날의 기록');
      rows.add(
        HomeRow(
          icon: V2Icons.calendar,
          title: '${memory.yearsAgo}년 전 오늘',
          sub: title,
          secondaryIcon: true,
          onTap: () => _openBase(3),
        ),
      );
    }
    rows.add(
      HomeRow(
        icon: V2Icons.record,
        title: '지난 순간',
        sub: '기록에서 우리의 하루들을 넘겨 봐요',
        secondaryIcon: true,
        onTap: () => widget.onNavigate(1),
      ),
    );
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Divider(height: 1, color: V2Colors.line),
        rows[i],
      ],
    ];
  }

  Widget _thumbs(List<TodayMoment?> moments) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, m) in moments.indexed)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 36,
                height: 36,
                child: homeMomentFill(
                  m,
                  baseUrl: _auth.baseUrl,
                  seed: 'thumb-$i',
                  cacheWidth: 120,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // first-use checklist

  bool get _showChecklist {
    final state = _todayState;
    if (_overview == null || _unpaired) return false;
    final start = _startDay;
    final young = start == null || dPlus(start) <= 7;
    if (!young) return false;
    return !(start != null &&
        state?.myMoment != null &&
        !_notificationsBlocked);
  }

  Widget _checklist() {
    final startDone = _startDay != null;
    final momentDone = _todayState?.myMoment != null;
    final notifDone = !_notificationsBlocked;
    final done =
        1 + (startDone ? 1 : 0) + (momentDone ? 1 : 0) + (notifDone ? 1 : 0);
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('시작해 볼까요?', style: V2Text.head)),
              V2Chip(label: '$done/4', tone: V2Tone.rose),
            ],
          ),
          const SizedBox(height: V2Space.x2),
          _CheckRow(done: true, title: '${josa(_partnerName, '와', '과')} 연결했어요'),
          _CheckRow(
            done: startDone,
            title: '우리의 첫날 정하기',
            sub: '100일·1주년을 자동으로 세어 줘요',
            action: '정하기',
            onTap: _pickStartDate,
          ),
          _CheckRow(
            done: momentDone,
            title: '오늘의 첫 순간 남기기',
            sub: '${josa(_partnerName, '와', '과')} 같이 열어 봐요',
            action: '남기기',
            onTap: _createMoment,
          ),
          _CheckRow(
            done: notifDone,
            title: '알림 켜기',
            sub: '${josa(_partnerName, '의', '의')} 순간과 콕을 놓치지 않아요',
            action: '켜기',
            onTap: _openNotifications,
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.done,
    required this.title,
    this.sub,
    this.action,
    this.onTap,
  });

  final bool done;
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: V2Space.tap),
      child: Row(
        children: [
          Icon(
            done ? V2Icons.ok : Icons.radio_button_unchecked_rounded,
            color: done ? V2Colors.okText : V2Colors.control,
          ),
          const SizedBox(width: V2Space.x3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: V2Space.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: V2Text.bodyStrong.copyWith(
                      color: done ? V2Colors.muted : null,
                    ),
                  ),
                  if (sub != null && !done) Text(sub!, style: V2Text.cap),
                ],
              ),
            ),
          ),
          if (!done && action != null)
            V2Button(
              label: action!,
              size: V2ButtonSize.sm,
              fullWidth: false,
              variant: V2ButtonVariant.soft,
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Semantics(
      label: '홈을 불러오는 중이에요',
      child: V2Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, top + 18, 22, 0),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V2SkeletonBox(height: 18, width: 120, radius: 6),
                SizedBox(height: V2Space.x2),
                V2SkeletonBox(height: 34, width: 220, radius: 8),
                SizedBox(height: V2Space.x3),
                V2SkeletonBox(height: 30, width: 160, radius: 15),
                SizedBox(height: 22),
                V2SkeletonBox(height: HomeFocusCard.height, radius: 28),
                SizedBox(height: V2Space.x4),
                V2SkeletonBox(height: 56, radius: V2Radius.ctl),
                SizedBox(height: V2Space.x2),
                V2SkeletonBox(height: 56, radius: V2Radius.ctl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
