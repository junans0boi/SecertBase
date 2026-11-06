import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:secret_base_app/v2/v2.dart';

import '../../core/assessment_catalog_api.dart';
import '../../core/auth_service.dart';
import '../../core/birth_profile_api.dart';
import '../../core/compatibility_api.dart';
import '../../core/counseling_api.dart';
import '../../core/fortune_api.dart';
import '../../core/mindcare_api.dart';
import '../../core/saju_api.dart';
import '../../core/tarot_api.dart';
import 'assessment_catalog_screen.dart';
import 'birth_info_sheet.dart';
import 'care_safety.dart';
import 'compatibility_screen.dart';
import 'counseling_screen.dart';
import 'fortune_screen.dart';
import 'mindcare_screen.dart';
import 'relationship_common.dart';
import 'saju_screen.dart';
import 'tarot_screen.dart';
import 'widgets/tarot_card_art.dart';

enum RelationshipAssessmentStatus {
  profileIncomplete,
  notStarted,
  inProgress,
  resultReady,
}

/// A compact entry card (kept for callers that embed the hub entry).
class RelationshipEntryCard extends StatelessWidget {
  final RelationshipAssessmentStatus status;
  final VoidCallback onTap;

  const RelationshipEntryCard({
    super.key,
    required this.status,
    required this.onTap,
  });

  String get _title => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete => '우리 이해 준비하기',
    RelationshipAssessmentStatus.notStarted => '우리 이해 시작하기',
    RelationshipAssessmentStatus.inProgress => '우리 이해 이어하기',
    RelationshipAssessmentStatus.resultReady => '우리 이해 결과 보기',
  };

  String get _subtitle => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete =>
      '출생 정보를 알려 주면 운세와 사주를 볼 수 있어요',
    RelationshipAssessmentStatus.notStarted => '운세, 타로, 검사로 우리를 알아가요',
    RelationshipAssessmentStatus.inProgress => '진행 중인 검사를 이어가세요',
    RelationshipAssessmentStatus.resultReady => '새로운 관계 패턴을 확인해 보세요',
  };

  IconData get _icon => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete => V2Icons.edit,
    RelationshipAssessmentStatus.notStarted => V2Icons.sparkle,
    RelationshipAssessmentStatus.inProgress => V2Icons.chevron,
    RelationshipAssessmentStatus.resultReady => V2Icons.star,
  };

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: V2List(
        children: [
          V2ListTile(
            icon: _icon,
            tone: V2Tone.lilac,
            title: _title,
            subtitle: _subtitle,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

/// 우리 이해: 오늘 (운세·타로) / 알아가기 (사주·심리검사·궁합) / 돌봄.
class RelationshipUnderstandingScreen extends StatefulWidget {
  final BirthProfileApi? api;
  final AssessmentCatalogApi? assessmentCatalogApi;
  final RelationshipAssessmentStatus assessmentStatus;
  final bool? hasActiveCouple;
  final http.Client? coupleInfoClient;
  final bool editBirthProfileOnly;
  final FortuneApi? fortuneApi;
  final TarotApi? tarotApi;

  const RelationshipUnderstandingScreen({
    super.key,
    this.api,
    this.assessmentCatalogApi,
    this.assessmentStatus = RelationshipAssessmentStatus.notStarted,
    this.hasActiveCouple,
    this.coupleInfoClient,
    this.editBirthProfileOnly = false,
    this.fortuneApi,
    this.tarotApi,
  });

  @override
  State<RelationshipUnderstandingScreen> createState() =>
      _RelationshipUnderstandingScreenState();
}

class _RelationshipUnderstandingScreenState
    extends State<RelationshipUnderstandingScreen> {
  late final BirthProfileApi _api;
  late final bool _ownsApi;
  AssessmentCatalogApi? _catalogApi;
  late final bool _ownsCatalogApi;
  FortuneApi? _fortuneApi;
  late final bool _ownsFortuneApi;
  TarotApi? _tarotApi;
  late final bool _ownsTarotApi;

  BirthProfile? _profile;
  bool _profileKnown = false;
  RelationshipAssessmentStatus? _loadedAssessmentStatus;
  bool? _hasActiveCouple;
  FortuneToday? _fortune;
  TarotToday? _tarot;
  bool _todayLoading = true;
  bool _todayFailed = false;
  bool _we = false;

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _ownsApi = widget.api == null;
    _api =
        widget.api ??
        BirthProfileApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    final full = widget.api == null && !widget.editBirthProfileOnly;
    _ownsCatalogApi = widget.assessmentCatalogApi == null && full;
    _catalogApi =
        widget.assessmentCatalogApi ??
        (_ownsCatalogApi
            ? AssessmentCatalogApi(
                baseUrl: auth.baseUrl,
                token: auth.token ?? '',
              )
            : null);
    _ownsFortuneApi = widget.fortuneApi == null && full;
    _fortuneApi =
        widget.fortuneApi ??
        (_ownsFortuneApi
            ? FortuneApi(baseUrl: auth.baseUrl, token: auth.token ?? '')
            : null);
    _ownsTarotApi = widget.tarotApi == null && full;
    _tarotApi =
        widget.tarotApi ??
        (_ownsTarotApi
            ? TarotApi(baseUrl: auth.baseUrl, token: auth.token ?? '')
            : null);
    _hasActiveCouple =
        widget.hasActiveCouple ??
        (widget.api != null && widget.coupleInfoClient == null ? false : null);
    if (widget.editBirthProfileOnly) {
      _todayLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _editOnlyStart());
    } else {
      _loadAll();
    }
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    if (_ownsCatalogApi) _catalogApi?.close();
    if (_ownsFortuneApi) _fortuneApi?.close();
    if (_ownsTarotApi) _tarotApi?.close();
    super.dispose();
  }

  // ---- loading ---------------------------------------------------------

  Future<void> _loadAll() async {
    setState(() {
      _todayLoading = true;
      _todayFailed = false;
    });
    await Future.wait([
      if (widget.hasActiveCouple == null &&
          (widget.api == null || widget.coupleInfoClient != null))
        _loadActiveCouple(),
      _loadProfile(),
      _loadAssessments(),
      _loadToday(),
    ]);
  }

  Future<void> _loadActiveCouple() async {
    final auth = AuthService();
    final client = widget.coupleInfoClient ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${auth.baseUrl}/api/couple/info'),
            headers: {
              if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
            },
          )
          .timeout(const Duration(seconds: 20));
      final body = response.body.isEmpty ? null : jsonDecode(response.body);
      final active =
          response.statusCode == 200 &&
          body is Map<String, dynamic> &&
          body['ok'] == true;
      if (![200, 404, 409].contains(response.statusCode)) {
        throw const FormatException('couple_info_unavailable');
      }
      if (mounted) setState(() => _hasActiveCouple = active);
    } catch (_) {
      // Unknown: the hub treats it as not paired and stays usable.
    } finally {
      if (widget.coupleInfoClient == null) client.close();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileKnown = true;
      });
    } catch (_) {
      if (mounted) setState(() => _profileKnown = false);
    }
  }

  Future<void> _loadAssessments() async {
    final api = _catalogApi;
    if (api == null) return;
    try {
      final items = await api.fetch();
      if (!mounted) return;
      setState(() => _loadedAssessmentStatus = _statusFromAssessments(items));
    } catch (_) {
      // The hub stays usable when assessment status is unavailable.
    }
  }

  Future<void> _loadToday() async {
    final fortuneApi = _fortuneApi;
    final tarotApi = _tarotApi;
    if (fortuneApi == null && tarotApi == null) {
      if (mounted) setState(() => _todayLoading = false);
      return;
    }
    var failed = false;
    FortuneToday? fortune;
    TarotToday? tarot;
    await Future.wait([
      () async {
        if (fortuneApi == null) return;
        try {
          fortune = await fortuneApi.fetchToday();
        } catch (_) {
          failed = true;
        }
      }(),
      () async {
        if (tarotApi == null) return;
        try {
          tarot = await tarotApi.fetchToday();
        } catch (_) {
          failed = true;
        }
      }(),
    ]);
    if (!mounted) return;
    setState(() {
      _fortune = fortune;
      _tarot = tarot;
      _todayFailed = failed && fortune == null && tarot == null;
      _todayLoading = false;
    });
  }

  RelationshipAssessmentStatus _statusFromAssessments(
    List<AssessmentCatalogItem> items,
  ) {
    final personal = items.where(
      (a) => a.audience == AssessmentAudience.individual,
    );
    if (personal.any(
      (a) => a.completionStatus == AssessmentCompletionStatus.inProgress,
    )) {
      return RelationshipAssessmentStatus.inProgress;
    }
    if (personal.any(
      (a) => a.completionStatus == AssessmentCompletionStatus.completed,
    )) {
      return RelationshipAssessmentStatus.resultReady;
    }
    return RelationshipAssessmentStatus.notStarted;
  }

  // ---- birth info -------------------------------------------------------

  bool get _hasBirthProfile => _profile?.birthDate.trim().isNotEmpty == true;

  Future<bool> _openBirthSheet() async {
    final saved = await showBirthInfoSheet(
      context,
      api: _api,
      existing: _hasBirthProfile ? _profile : null,
    );
    if (saved == null || !mounted) return false;
    setState(() {
      _profile = saved;
      _profileKnown = true;
    });
    showV2Snack(context, '출생 정보를 저장했어요');
    return true;
  }

  Future<void> _editOnlyStart() async {
    await _loadProfile();
    if (!mounted) return;
    await _openBirthSheet();
  }

  // ---- navigation --------------------------------------------------------

  AuthService get _auth => AuthService();

  void _push(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  Future<void> _openFortune() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RelationshipFortuneScreen(
          api: FortuneApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
          scope: _we ? FortuneScope.couple : FortuneScope.personal,
        ),
      ),
    );
    if (mounted && _fortuneApi != null) _loadToday();
  }

  Future<void> _openTarot() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TarotScreen(
          api: TarotApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
          relationshipFirst: _we,
        ),
      ),
    );
    if (mounted && _tarotApi != null) _loadToday();
  }

  void _openSaju() => _push(
    SajuScreen(
      api: SajuApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
      relationshipFirst: _we,
    ),
  );

  void _openCatalog() => _push(
    AssessmentCatalogScreen(
      api: AssessmentCatalogApi(
        baseUrl: _auth.baseUrl,
        token: _auth.token ?? '',
      ),
      hasActiveCouple: _hasActiveCouple == true,
      audienceFilter: _we ? AssessmentAudience.couple : null,
    ),
  );

  void _openCompatibility() => _push(
    CompatibilityDashboardScreen(
      api: CompatibilityApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
    ),
  );

  void _openMindcare() => _push(
    MindcareScreen(
      api: MindcareApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
    ),
  );

  void _openCounseling({required bool shared}) => _push(
    RelationshipCounselingScreen(
      api: CounselingApi(baseUrl: _auth.baseUrl, token: _auth.token ?? ''),
      shared: shared,
      onOpenPartner: () => openPartnerConnection(context),
    ),
  );

  // ---- build -------------------------------------------------------------

  bool get _paired => _hasActiveCouple == true;

  @override
  Widget build(BuildContext context) {
    if (widget.editBirthProfileOnly) return _editOnlyPage();
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '우리 이해'),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(V2Space.page, 0, V2Space.page, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CareHelpChip(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAll,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    _todaySection(),
                    _knowSection(),
                    _careSection(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        V2Space.page,
                        20,
                        V2Space.page,
                        0,
                      ),
                      child: Text(
                        '재미와 자기 이해를 위한 안내예요. 예언이나 진단, 치료가 아니에요.',
                        style: V2Text.cap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editOnlyPage() {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '출생 정보'),
        body: ListView(
          padding: const EdgeInsets.all(V2Space.page),
          children: [
            if (_hasBirthProfile)
              V2Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('저장된 출생 정보', style: V2Text.cap),
                    const SizedBox(height: 4),
                    Text(
                      '${_profile!.calendarType == BirthCalendarType.lunar ? '음력' : '양력'} ${_profile!.birthDate}'
                      '${_profile!.lunarLeapMonth ? ' (윤달)' : ''}',
                      style: V2Text.head,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profile!.birthTime == null
                          ? '태어난 시각 모름'
                          : '태어난 시각 ${_profile!.birthTime}',
                      style: V2Text.cap,
                    ),
                  ],
                ),
              )
            else
              Text('아직 출생 정보가 없어요. 사주와 운세를 볼 때만 써요.', style: V2Text.body),
            const SizedBox(height: 16),
            V2Button(
              label: _hasBirthProfile ? '출생 정보 수정하기' : '출생 정보 입력하기',
              onPressed: _openBirthSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _todaySection() {
    return V2Section(
      title: '오늘',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_paired)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: V2Segmented<bool>(
                segments: const [
                  V2Segment(value: false, label: '나'),
                  V2Segment(value: true, label: '우리'),
                ],
                selected: _we,
                onChanged: (v) => setState(() => _we = v),
              ),
            )
          else if (_hasActiveCouple == false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: V2Banner(
                message: '파트너와 연결하면 우리 운세, 우리 타로, 궁합도 볼 수 있어요.',
                actionLabel: '연결하기',
                onAction: () => openPartnerConnection(context),
              ),
            ),
          if (_todayLoading)
            const V2SkeletonList(count: 2)
          else if (_todayFailed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: V2Banner(
                tone: V2BannerTone.err,
                message: '오늘의 운세와 타로를 불러오지 못했어요.',
                actionLabel: '다시 시도',
                onAction: _loadAll,
              ),
            )
          else ...[
            _fortuneCard(),
            const SizedBox(height: 10),
            _tarotCard(),
          ],
        ],
      ),
    );
  }

  Widget _fortuneCard() {
    final today = _fortune;
    final content = _we ? today?.relationship : today?.personal;
    final needsProfile = !_we && today != null && content == null;
    return V2Card(
      key: const Key('hub_today_fortune'),
      onTap: needsProfile ? _editThenReload : _openFortune,
      semanticLabel: '오늘의 운세 열기',
      child: Row(
        children: [
          const V2Art(icon: V2Icons.star, tone: V2Tone.honey, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_we ? '오늘 우리의 운세' : '오늘의 운세', style: V2Text.cap),
                const SizedBox(height: 2),
                Text(
                  content?.title.isNotEmpty == true
                      ? content!.title
                      : needsProfile
                      ? '출생 정보를 알려 주세요'
                      : '오늘의 흐름 보기',
                  style: V2Text.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  content?.summary.isNotEmpty == true
                      ? content!.summary
                      : needsProfile
                      ? '생년월일을 입력하면 한 줄 운세가 나와요.'
                      : '눌러서 오늘의 한 줄을 확인해요.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V2Text.cap,
                ),
              ],
            ),
          ),
          const Icon(V2Icons.chevron, size: 20),
        ],
      ),
    );
  }

  Future<void> _editThenReload() async {
    if (await _openBirthSheet() && mounted) {
      await _loadToday();
    }
  }

  Widget _tarotCard() {
    final today = _tarot;
    final reading = _we ? today?.relationship : today?.personal;
    final card = reading?.card;
    return V2Card(
      key: const Key('hub_today_tarot'),
      onTap: _openTarot,
      semanticLabel: '오늘의 타로 열기',
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: card != null
                ? TarotCardFace(cardKey: card.key, title: card.title, width: 52)
                : const TarotCardBack(width: 52),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_we ? '오늘 우리의 타로' : '오늘의 타로', style: V2Text.cap),
                const SizedBox(height: 2),
                Text(
                  card != null ? card.title : '오늘의 한 장을 뽑아 보세요',
                  style: V2Text.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  card != null ? card.plain : '하루에 한 장, 마음에 끌리는 카드를 골라요.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V2Text.cap,
                ),
              ],
            ),
          ),
          const Icon(V2Icons.chevron, size: 20),
        ],
      ),
    );
  }

  V2Chip _assessmentBadge() {
    final status = _loadedAssessmentStatus ?? widget.assessmentStatus;
    return switch (status) {
      RelationshipAssessmentStatus.inProgress => const V2Chip(
        label: '진행 중',
        tone: V2Tone.honey,
      ),
      RelationshipAssessmentStatus.resultReady => const V2Chip(
        label: '결과 있음',
        tone: V2Tone.ok,
      ),
      _ => const V2Chip(label: '시작 전'),
    };
  }

  Widget _knowSection() {
    final sajuBadge = !_profileKnown
        ? null
        : _hasBirthProfile
        ? const V2Chip(label: '준비됨', tone: V2Tone.ok)
        : const V2Chip(label: '출생 정보 필요', tone: V2Tone.warn);
    return V2Section(
      title: '알아가기',
      child: V2List(
        children: [
          V2ListTile(
            key: const Key('hub_saju'),
            icon: V2Icons.sparkle,
            tone: V2Tone.sage,
            title: _we ? '우리의 사주' : '사주',
            subtitle: '태어난 날로 보는 나의 기질',
            trailing: sajuBadge,
            onTap: _openSaju,
          ),
          V2ListTile(
            key: const Key('hub_assessments'),
            icon: V2Icons.help,
            tone: V2Tone.lilac,
            title: '심리검사',
            subtitle: '출생 정보 없이 바로 할 수 있어요',
            trailing: _assessmentBadge(),
            onTap: _openCatalog,
          ),
          V2ListTile(
            key: const Key('hub_compatibility'),
            icon: V2Icons.heart,
            tone: V2Tone.rose,
            title: '궁합',
            subtitle: _paired ? '두 사람의 검사 결과로 보는 관계 패턴' : '파트너와 연결하면 볼 수 있어요',
            trailing: _paired
                ? const V2Chip(label: '연결됨', tone: V2Tone.ok)
                : const V2Chip(label: '파트너 연결 후', icon: V2Icons.lock),
            onTap: _paired
                ? _openCompatibility
                : () => openPartnerConnection(context),
          ),
        ],
      ),
    );
  }

  Widget _careSection() {
    return V2Section(
      title: '돌봄',
      child: V2List(
        children: [
          V2ListTile(
            key: const Key('hub_mindcare'),
            icon: V2Icons.care,
            tone: V2Tone.lilac,
            title: '마음관리',
            subtitle: '질문에 눌러서 답하며 마음을 정리해요',
            onTap: _openMindcare,
          ),
          V2ListTile(
            key: const Key('hub_counseling'),
            icon: V2Icons.chat,
            tone: V2Tone.sky,
            title: 'AI 상담',
            subtitle: 'AI 가이드와 이야기해요. 전문 상담이 아니에요',
            onTap: () => _openCounseling(shared: false),
          ),
          if (_paired)
            V2ListTile(
              key: const Key('hub_shared_counseling'),
              icon: V2Icons.couple,
              tone: V2Tone.peach,
              title: '함께 하는 상담',
              subtitle: '두 사람이 함께 볼 수 있는 공간이에요',
              onTap: () => _openCounseling(shared: true),
            ),
        ],
      ),
    );
  }
}
