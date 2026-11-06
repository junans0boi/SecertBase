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
import '../secret_base/base_rewards_tab.dart';
import '../secret_base/secret_base_screen.dart';
import '../settings/notification_settings_screen.dart';
import 'anniversaries_screen.dart';
import 'home_format.dart';
import 'start_date_sheet.dart';
import 'today_card.dart';
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
  int _claimable = 0;
  bool _savingStart = false;

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
    final claimable = await (widget.claimableRewards ?? _defaultClaimable)();
    if (!mounted) return;
    setState(() {
      _notificationsBlocked = blocked;
      _claimable = claimable;
    });
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

  Future<int> _defaultClaimable() async {
    if (_auth.token == null) return 0;
    final api = BaseApi(baseUrl: _auth.baseUrl, headers: _authHeaders);
    try {
      final body = await api.get('/retention/secret-base/milestones');
      final raw = body['milestones'];
      if (raw is! List) return 0;
      return raw
          .whereType<Map>()
          .map((m) => Milestone.fromJson(Map<String, dynamic>.from(m)))
          .where((m) => m.claimable)
          .length;
    } catch (_) {
      return 0;
    } finally {
      api.close();
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

  void _openFortune() => _push(
    RelationshipFortuneScreen(
      api: FortuneApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
      onEditProfile: () => _push(
        const RelationshipUnderstandingScreen(editBirthProfileOnly: true),
      ),
      onOpenPartner: () => _push(const PartnerScreen()),
    ),
  );

  void _openUnderstanding() => _push(
    RelationshipUnderstandingScreen(
      assessmentStatus: widget.relationshipStatus ?? _defaultRelationshipStatus,
      hasActiveCouple: _couple != null,
    ),
  );

  RelationshipAssessmentStatus get _defaultRelationshipStatus {
    final birthDate = _auth.user?['BirthDate'] ?? _auth.user?['birthDate'];
    if (birthDate == null || '$birthDate'.trim().isEmpty) {
      return RelationshipAssessmentStatus.profileIncomplete;
    }
    return switch (_overview?.assessmentStatus) {
      HomeAssessmentStatus.inProgress =>
        RelationshipAssessmentStatus.inProgress,
      HomeAssessmentStatus.resultReady =>
        RelationshipAssessmentStatus.resultReady,
      _ => RelationshipAssessmentStatus.notStarted,
    };
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
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _hero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Space.page,
              V2Space.x4,
              V2Space.page,
              V2Space.x10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_controller.state.status == HomeStatus.failure) ...[
                  V2Banner(
                    tone: V2BannerTone.err,
                    message: '새 소식을 불러오지 못했어요. 마지막으로 받은 내용을 보여 줘요.',
                    actionLabel: '다시 불러오기',
                    onAction: _refresh,
                  ),
                  const SizedBox(height: V2Space.x3),
                ],
                if (_notificationsBlocked && !_notificationBannerDismissed) ...[
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
                  const SizedBox(height: V2Space.x3),
                ],
                _todayEntry(),
                ..._partnerLine(),
                if (_showChecklist) ...[
                  const SizedBox(height: V2Space.x4),
                  _checklist(),
                ],
                const SizedBox(height: V2Space.x5),
                _shortcuts(),
                const SizedBox(height: V2Space.x5),
                _memory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // hero

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

  Widget _hero() {
    final top = MediaQuery.paddingOf(context).top;
    final start = _startDay;
    final dDay = start != null ? dPlus(start) : _couple?.dDay;
    final next = _nextEvent;
    final pill = next == null
        ? null
        : next.days == 0
        ? '오늘은 ${next.label}이에요'
        : '${next.label}까지 ${next.days}일';
    return Container(
      padding: EdgeInsets.fromLTRB(
        V2Space.page,
        top + V2Space.x3,
        V2Space.page,
        V2Space.x6,
      ),
      decoration: const BoxDecoration(
        gradient: V2Gradients.hero,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(V2Radius.sheet),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: V2AvatarPair(me: _myName, partner: _partnerName),
              ),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Text(
                  '$_myName · $_partnerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Text.bodyStrong.copyWith(color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: '알림 설정',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Badge(
                  isLabelVisible: _notificationsBlocked,
                  smallSize: 8,
                  child: const Icon(V2Icons.bell, color: Colors.white),
                ),
                onPressed: _openNotifications,
              ),
            ],
          ),
          const SizedBox(height: V2Space.x4),
          if (dDay == null)
            _startPrompt()
          else ...[
            Semantics(
              label: '함께한 지 $dDay일째',
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'D+',
                      style: V2Text.serif(size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: V2Space.x1),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$dDay',
                          style: V2Text.serif(size: 64, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pill != null) ...[
              const SizedBox(height: V2Space.x2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Space.x3,
                  vertical: V2Space.x1 + 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .24),
                  borderRadius: V2Radius.pillAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(V2Icons.event, size: 16, color: Colors.white),
                    const SizedBox(width: V2Space.x1),
                    Flexible(
                      child: Text(
                        pill,
                        style: V2Text.label.copyWith(
                          color: Colors.white,
                          fontSize: 13,
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
    );
  }

  Widget _startPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '우리의 첫날을\n알려 주세요',
          style: V2Text.serif(size: 30, color: Colors.white),
        ),
        const SizedBox(height: V2Space.x1),
        Text(
          _coupleFailed
              ? '정보를 불러오지 못했어요. 아래로 당겨 새로고침해 보세요.'
              : '연결한 날이 기본이에요. 바꿔도 돼요',
          style: V2Text.cap.copyWith(color: Colors.white),
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

  // today

  Widget _todayEntry() {
    final state = _todayState;
    final failed = _overview?.todayLoadFailed ?? true;
    if (state == null || failed) {
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
    return TodayCard(
      state: state,
      myName: _myName,
      partnerName: _partnerName,
      // TODO(moment-agent): open the composer with "오늘의 순간" ON once
      // MomentLoopScreen exposes the optional named parameter (see
      // openMomentComposer in secret_base/base_common.dart).
      onCreateMoment: _createMoment,
      onOpenLoop: _openLoop,
      onPoke: _sendPoke,
      pokedToday: _pokedToday,
      poking: _poking,
      offline: _offline,
      baseUrl: _auth.baseUrl,
    );
  }

  List<Widget> _partnerLine() {
    final state = _todayState;
    if (state == null || (_overview?.todayLoadFailed ?? true)) return const [];
    final name = _partnerName;
    final moment = state.partnerMoment;
    final clock = clockLabel(moment?.capturedAt ?? moment?.takenAt);
    final text = switch (state.status) {
      TodayStatus.empty => '${josa(name, '도', '도')} 아직이에요',
      TodayStatus.selfWaiting => '${josa(name, '은', '는')} 아직 남기지 않았어요',
      _ =>
        clock != null
            ? '${josa(name, '이', '가')} $clock에 남겼어요'
            : '${josa(name, '이', '가')} 오늘의 순간을 남겼어요',
    };
    return [
      const SizedBox(height: V2Space.x3),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: V2Space.x1),
        child: Row(
          children: [
            ExcludeSemantics(
              child: V2Avatar(
                name: name,
                color: V2Avatar.partnerColor,
                size: V2AvatarSize.sm,
              ),
            ),
            const SizedBox(width: V2Space.x2),
            Expanded(child: Text(text, style: V2Text.cap)),
          ],
        ),
      ),
    ];
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

  // shortcuts

  Widget _shortcuts() {
    final items = [
      (
        icon: V2Icons.sparkle,
        label: '오늘의 운세',
        tone: V2Tone.lilac,
        badge: 0,
        onTap: _openFortune,
      ),
      (
        icon: V2Icons.heart,
        label: '우리 이해',
        tone: V2Tone.rose,
        badge: 0,
        onTap: _openUnderstanding,
      ),
      (
        icon: V2Icons.event,
        label: '기념일',
        tone: V2Tone.honey,
        badge: 0,
        onTap: () => _push(const AnniversariesScreen()),
      ),
      (
        icon: V2Icons.base,
        label: '비밀기지',
        tone: V2Tone.sage,
        badge: _claimable,
        onTap: () => _openBase(),
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: V2Space.x2),
          Expanded(
            child: _Shortcut(
              icon: items[i].icon,
              label: items[i].label,
              tone: items[i].tone,
              badge: items[i].badge,
              onTap: items[i].onTap,
            ),
          ),
        ],
      ],
    );
  }

  // memory

  Widget _memory() {
    final card = _overview?.memoryCard;
    if (_overview?.failedSections.contains(HomeSection.memory) ?? false) {
      return const SizedBox.shrink();
    }
    if (card == null) {
      return V2Card(
        variant: V2CardVariant.soft,
        child: Row(
          children: [
            const V2Art(icon: V2Icons.calendar, tone: V2Tone.honey),
            const SizedBox(width: V2Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('n년 전 오늘', style: V2Text.bodyStrong),
                  Text('기록이 쌓이면 1년 뒤 오늘 여기서 만나요', style: V2Text.cap),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final total = _overview?.memoryCardTotal ?? 0;
    final title = card.caption?.trim().isNotEmpty == true
        ? card.caption!
        : (card.placeName ?? '그날의 기록');
    final media = card.mediaUrl;
    return V2Card(
      onTap: () => _openBase(3),
      semanticLabel: '${card.yearsAgo}년 전 오늘, $title. 추억 모아 보기',
      child: Row(
        children: [
          ClipRRect(
            borderRadius: V2Radius.ctlAll,
            child: SizedBox(
              width: 64,
              height: 64,
              child: media == null
                  ? const V2PhotoPlaceholder(seed: 'memory')
                  : Image.network(
                      media.startsWith('http')
                          ? media
                          : '${_auth.baseUrl}$media',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const V2PhotoPlaceholder(seed: 'memory'),
                    ),
            ),
          ),
          const SizedBox(width: V2Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${card.yearsAgo}년 전 오늘', style: V2Text.label),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: V2Text.bodyStrong,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (total > 1) Text('이 날의 기록 $total개', style: V2Text.cap),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: V2Colors.muted),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.tone,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final V2Tone tone;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = V2ToneColors.of(tone);
    return Semantics(
      container: true,
      button: true,
      label: badge > 0 ? '$label, 받을 보상 $badge개' : label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: V2Colors.surface,
          borderRadius: V2Radius.cardAll,
          child: InkWell(
            borderRadius: V2Radius.cardAll,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.symmetric(
                horizontal: V2Space.x1,
                vertical: V2Space.x3,
              ),
              decoration: BoxDecoration(
                borderRadius: V2Radius.cardAll,
                border: Border.all(color: V2Colors.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: badge > 0,
                    label: Text('$badge'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: V2Radius.ctlAll,
                      ),
                      child: Icon(icon, color: c.text),
                    ),
                  ),
                  const SizedBox(height: V2Space.x2),
                  Text(
                    V2Text.keepAll(label),
                    textAlign: TextAlign.center,
                    style: V2Text.label,
                  ),
                ],
              ),
            ),
          ),
        ),
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
            padding: EdgeInsets.fromLTRB(
              V2Space.page,
              top + V2Space.x4,
              V2Space.page,
              0,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                V2SkeletonBox(height: 190, radius: V2Radius.sheet),
                SizedBox(height: V2Space.x4),
                V2SkeletonBox(height: 240, radius: V2Radius.card),
                SizedBox(height: V2Space.x4),
                V2SkeletonBox(height: 92, radius: V2Radius.card),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
