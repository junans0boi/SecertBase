import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/today_api.dart';
import '../../features/home/application/home_controller.dart';
import '../../features/home/data/home_overview_repository.dart';
import '../../features/home/domain/home_overview.dart';
import 'today_card.dart';
import 'today_loop_viewer.dart';
import 'memory_list_screen.dart';
import '../secret_base/secret_base_screen.dart';
import '../relationship/relationship_understanding_screen.dart';
import '../../core/fortune_api.dart';
import '../relationship/fortune_screen.dart';
import '../relationship/saju_screen.dart';
import '../relationship/tarot_screen.dart';
import '../auth/partner_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final RelationshipAssessmentStatus? relationshipStatus;
  final Future<TodayState> Function()? todayStateLoader;
  final HomeController? controller;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    this.relationshipStatus,
    this.todayStateLoader,
    this.controller,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  late HomeController _controller;
  var _ownsController = false;

  Map<String, String> get _authHeaders => {
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller ?? _createController());
    _controller.load();
  }

  HomeController _createController() {
    return HomeController(
      HomeOverviewRepository.forAuth(
        _auth,
        todayStateLoader: widget.todayStateLoader,
      ),
    );
  }

  void _attachController(HomeController controller) {
    _controller = controller;
    _ownsController = widget.controller == null;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

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
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  HomeOverview? get _overview => _controller.state.data;

  Future<void> _refresh() => _controller.refresh();

  RelationshipAssessmentStatus? get _loadedRelationshipStatus {
    return switch (_overview?.assessmentStatus) {
      HomeAssessmentStatus.inProgress =>
        RelationshipAssessmentStatus.inProgress,
      HomeAssessmentStatus.resultReady =>
        RelationshipAssessmentStatus.resultReady,
      HomeAssessmentStatus.notStarted =>
        RelationshipAssessmentStatus.notStarted,
      null => null,
    };
  }

  HomeCoupleInfo? get _couple => _overview?.couple;

  bool get _homeLoading =>
      _controller.state.status == HomeStatus.loading && _overview == null;

  bool get _homeFailed => _controller.state.status == HomeStatus.failure;

  bool get _todayLoadFailed =>
      _homeFailed || _overview == null || _overview!.todayLoadFailed;

  TodayState? get _todayState => _overview?.todayState;

  bool get _todayLoading => _homeLoading;

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: kMainRose,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            _homeHeader(),
            const SizedBox(height: 16),
            _coupleCard(),
            const SizedBox(height: 14),
            _todayEntry(),
            const SizedBox(height: 22),
            _quickActions(),
            const SizedBox(height: 18),
            _relationshipCard(),
            if (_overview?.memoryCard != null) ...[
              const SizedBox(height: 18),
              _MemoryCardWidget(
                card: _overview!.memoryCard!,
                totalCount: _overview!.memoryCardTotal,
                baseUrl: _auth.baseUrl,
                authHeaders: _authHeaders,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _homeHeader() {
    final name = _auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? '우리';
    return Row(
      children: [
        const BrandLogo(size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('우리의 하루', style: mainTitle(size: 25)),
              Text('$name님, 오늘도 함께 기록해요', style: mainBody(size: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '함께 해볼까요?',
                style: mainBody(size: 15, weight: FontWeight.w900),
              ),
            ),
            Text('좌우로 밀어 더 보기', style: mainBody(size: 11, color: kMainMuted)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _QuickAction(
                icon: Icons.map_outlined,
                title: '비밀 지도',
                subtitle: '장소 남기기',
                color: kMainSage,
                background: kMainSageSoft,
                onTap: () => widget.onNavigate(2),
              ),
              _QuickAction(
                icon: Icons.cottage_outlined,
                title: '비밀기지',
                subtitle: '우리의 기록',
                color: kMainLilac,
                background: kMainLilacSoft,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SecretBaseScreen(
                      baseUrl: _auth.baseUrl,
                      authHeaders: _authHeaders,
                    ),
                  ),
                ),
              ),
              _QuickAction(
                icon: Icons.auto_awesome_outlined,
                title: '운세',
                subtitle: '오늘의 흐름',
                color: kMainRose,
                background: kMainRoseSoft,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => RelationshipFortuneScreen(
                      api: FortuneApi(
                        baseUrl: _auth.baseUrl,
                        token: _auth.token ?? '',
                      ),
                      onEditProfile: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const RelationshipUnderstandingScreen(
                            editBirthProfileOnly: true,
                          ),
                        ),
                      ),
                      onOpenPartner: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const PartnerScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _QuickAction(
                icon: Icons.style_outlined,
                title: '타로',
                subtitle: '오늘의 카드',
                color: kMainLilac,
                background: kMainLilacSoft,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const TarotScreen()),
                ),
              ),
              _QuickAction(
                icon: Icons.auto_graph_rounded,
                title: '사주',
                subtitle: '나의 흐름',
                color: kMainSage,
                background: kMainSageSoft,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SajuScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _todayEntry() {
    if (_todayLoading) return const _TodayLoadingCard();
    final state = _todayState;
    if (_todayLoadFailed || state == null) {
      return _TodayFailureCard(onRetry: _refresh);
    }
    return TodayCard(
      state: state,
      onCreateMoment: () => widget.onNavigate(1),
      onOpenLoop: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TodayLoopViewer(state: state, baseUrl: _auth.baseUrl),
        ),
      ),
    );
  }

  Widget _coupleCard() {
    final myName = _auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? '나';
    final partnerName = _couple?.partnerName ?? '상대방';
    final dDay = _couple?.dDay;
    final startDate = _couple?.startDate;
    return MainCard(
      gradient: kRoseGrad,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '우리의 오늘',
            style: mainBody(
              size: 12,
              color: Colors.white.withAlpha(220),
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$myName & $partnerName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mainBody(
              size: 14,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dDay == null ? '우리의 첫날을 등록해보세요' : 'D+$dDay',
            style: mainTitle(size: dDay == null ? 28 : 48, color: Colors.white),
          ),
          if (startDate != null)
            Text(
              '$startDate 부터 함께',
              style: mainBody(size: 13, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _relationshipCard() {
    final status = widget.relationshipStatus ?? _defaultRelationshipStatus;
    return _RelationshipHomeEntry(
      status: status,
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RelationshipUnderstandingScreen(
            assessmentStatus: status,
            hasActiveCouple: _couple != null,
          ),
        ),
      ),
    );
  }

  RelationshipAssessmentStatus get _defaultRelationshipStatus {
    final birthDate = _auth.user?['BirthDate'] ?? _auth.user?['birthDate'];
    if (birthDate == null || '$birthDate'.trim().isEmpty) {
      return RelationshipAssessmentStatus.profileIncomplete;
    }
    return _loadedRelationshipStatus ?? RelationshipAssessmentStatus.notStarted;
  }
}

class _MemoryCardWidget extends StatelessWidget {
  final HomeMemoryCard card;
  final int totalCount;
  final String baseUrl;
  final Map<String, String> authHeaders;

  const _MemoryCardWidget({
    required this.card,
    required this.totalCount,
    required this.baseUrl,
    required this.authHeaders,
  });

  @override
  Widget build(BuildContext context) {
    final yearsAgo = card.yearsAgo;
    final placeName = card.placeName;
    final caption = card.caption;
    final mediaUrl = card.mediaUrl;
    final fullMediaUrl = mediaUrl != null ? '$baseUrl$mediaUrl' : null;

    return MainCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추억 되짚기',
            style: mainBody(size: 14, color: kMainInk, weight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 14, color: kMainMuted),
              const SizedBox(width: 4),
              Text(
                '$yearsAgo년 전 오늘',
                style: mainBody(size: 12, color: kMainMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fullMediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    fullMediaUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, a, b) => Container(
                      width: 72,
                      height: 72,
                      color: kMainPaperSoft,
                      child: const Icon(
                        Icons.image_outlined,
                        color: kMainMuted,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kMainPaperSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_album_outlined,
                    color: kMainMuted,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (placeName != null)
                      Text(
                        placeName,
                        style: mainBody(
                          size: 13,
                          weight: FontWeight.w700,
                          color: kMainInk,
                        ),
                      ),
                    if (caption != null)
                      Text(
                        caption,
                        style: mainBody(size: 13, color: kMainSub),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (totalCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalCount > 1 ? '이 날 $totalCount개의 기억이 있어요' : '이 날의 기억',
                  style: mainBody(size: 12, color: kMainMuted),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemoryListScreen(
                        baseUrl: baseUrl,
                        authHeaders: authHeaders,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    '모든 기억 보기',
                    style: mainBody(
                      size: 12,
                      color: kMainRose,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $subtitle',
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(
            width: 124,
            child: Material(
              color: kMainPaper,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: mainBody(size: 13, weight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: mainBody(size: 11, color: kMainMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayLoadingCard extends StatelessWidget {
  const _TodayLoadingCard();

  @override
  Widget build(BuildContext context) {
    return MainCard(
      color: kMainSkySoft,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const IconBadge(
            color: kMainSky,
            backgroundColor: Colors.white,
            size: 44,
            child: Icon(Icons.auto_stories_outlined, color: kMainSky),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 루프를 준비하고 있어요',
                  style: mainBody(
                    size: 14,
                    color: kMainInk,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '오늘의 순간을 함께 열어볼게요',
                  style: mainBody(size: 12, color: kMainSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayFailureCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _TodayFailureCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MainCard(
      color: kMainPaperSoft,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const IconBadge(
            color: kMainRose,
            backgroundColor: Colors.white,
            size: 44,
            child: Icon(Icons.refresh_rounded, color: kMainRose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 루프를 불러오지 못했어요',
                  style: mainBody(
                    size: 14,
                    color: kMainInk,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '잠시 후 다시 시도해주세요',
                  style: mainBody(size: 12, color: kMainSub),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _RelationshipHomeEntry extends StatelessWidget {
  final RelationshipAssessmentStatus status;
  final VoidCallback onTap;

  const _RelationshipHomeEntry({required this.status, required this.onTap});

  ({String title, String subtitle, String action, IconData icon, bool primary})
  get _copy => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete => (
      title: '관계 이해 준비하기',
      subtitle: '출생 프로필을 먼저 완성해주세요',
      action: '준비 상태 확인하기',
      icon: Icons.edit_note_outlined,
      primary: false,
    ),
    RelationshipAssessmentStatus.notStarted => (
      title: '관계 이해 알아보기',
      subtitle: '우리의 대화와 관계를 천천히 살펴봐요',
      action: '관계 이해 살펴보기',
      icon: Icons.psychology_outlined,
      primary: false,
    ),
    RelationshipAssessmentStatus.inProgress => (
      title: '관계 이해 이어보기',
      subtitle: '진행 중인 검사를 이어가세요',
      action: '검사 이어가기',
      icon: Icons.play_circle_outline,
      primary: true,
    ),
    RelationshipAssessmentStatus.resultReady => (
      title: '관계 이해 결과가 있어요',
      subtitle: '최근 결과와 다음 질문을 확인해보세요',
      action: '결과 살펴보기',
      icon: Icons.insights_outlined,
      primary: false,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final action = copy.primary
        ? FilledButton(onPressed: onTap, child: Text(copy.action))
        : OutlinedButton(onPressed: onTap, child: Text(copy.action));
    return MainCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                color: kMainLilac,
                backgroundColor: kMainLilacSoft,
                size: 44,
                child: Icon(copy.icon, color: kMainLilac, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: mainBody(size: 15, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      copy.subtitle,
                      style: mainBody(size: 12, color: kMainSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    );
  }
}
