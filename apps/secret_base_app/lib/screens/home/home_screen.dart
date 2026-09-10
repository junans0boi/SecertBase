import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import 'memory_list_screen.dart';
import '../secret_base/secret_base_screen.dart';
import '../relationship/relationship_understanding_screen.dart';
import '../../core/fortune_api.dart';
import '../relationship/fortune_screen.dart';
import '../relationship/saju_screen.dart';
import '../relationship/tarot_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final RelationshipAssessmentStatus? relationshipStatus;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    this.relationshipStatus,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  Map<String, dynamic>? _coupleInfo;
  Map<String, dynamic>? _memoryCard;
  int _memoryCardTotal = 0;
  RelationshipAssessmentStatus? _loadedRelationshipStatus;

  Map<String, String> get _authHeaders => {
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('${_auth.baseUrl}/api/couple/info'),
          headers: _authHeaders,
        ),
        http.get(
          Uri.parse('${_auth.baseUrl}/api/retention/memory-card'),
          headers: _authHeaders,
        ),
        http.get(
          Uri.parse('${_auth.baseUrl}/api/relationship/assessments'),
          headers: _authHeaders,
        ),
      ]);
      if (!mounted) return;
      final couple = jsonDecode(responses[0].body) as Map<String, dynamic>;

      setState(() {
        if (responses[0].statusCode == 200 && couple['ok'] == true) {
          _coupleInfo = couple;
        }
        if (responses[1].statusCode == 200) {
          final mc = jsonDecode(responses[1].body) as Map<String, dynamic>;
          if (mc['ok'] == true && mc['card'] != null) {
            _memoryCard = mc['card'] as Map<String, dynamic>;
            _memoryCardTotal = mc['total_count'] as int? ?? 0;
          } else {
            _memoryCard = null;
            _memoryCardTotal = 0;
          }
        }
        if (responses[2].statusCode == 200) {
          final catalog = jsonDecode(responses[2].body) as Map<String, dynamic>;
          final assessments = catalog['assessments'];
          if (catalog['ok'] == true && assessments is List) {
            _loadedRelationshipStatus = _relationshipStatusFromCatalog(
              assessments,
            );
          }
        }
      });
    } catch (_) {
      // Home remains resilient
    }
  }

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      child: RefreshIndicator(
        onRefresh: _load,
        color: kMainRose,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            _homeHeader(),
            const SizedBox(height: 20),
            _coupleCard(),
            const SizedBox(height: 14),
            _quickActions(),
            const SizedBox(height: 18),
            _relationshipCard(),
            if (_memoryCard != null) ...[
              const SizedBox(height: 18),
              _MemoryCardWidget(
                card: _memoryCard!,
                totalCount: _memoryCardTotal,
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
    return SizedBox(
      height: 104,
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
            onTap: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => const SajuScreen())),
          ),
        ],
      ),
    );
  }

  Widget _coupleCard() {
    final myName = _auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? '나';
    final partnerName = _coupleInfo?['partnerName'] ?? '상대방';
    final dDay = _coupleInfo?['dDay'];
    final startDate = _coupleInfo?['startDate'];
    return MainCard(
      gradient: kRoseGrad,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    return RelationshipEntryCard(
      status: status,
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RelationshipUnderstandingScreen(
            assessmentStatus: status,
            hasActiveCouple: _coupleInfo != null,
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

  RelationshipAssessmentStatus _relationshipStatusFromCatalog(List raw) {
    final personalAssessments = raw.whereType<Map>().where(
      (assessment) => assessment['audience'] == 'individual',
    );
    if (personalAssessments.any(
      (assessment) => assessment['completionStatus'] == 'in_progress',
    )) {
      return RelationshipAssessmentStatus.inProgress;
    }
    if (personalAssessments.any(
      (assessment) => assessment['completionStatus'] == 'completed',
    )) {
      return RelationshipAssessmentStatus.resultReady;
    }
    return RelationshipAssessmentStatus.notStarted;
  }
}

class _MemoryCardWidget extends StatelessWidget {
  final Map<String, dynamic> card;
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
    final yearsAgo = card['years_ago'] as int? ?? 0;
    final placeName = card['place_name'] as String?;
    final caption = card['caption'] as String?;
    final mediaUrl = card['media_url'] as String?;
    final fullMediaUrl = mediaUrl != null ? '$baseUrl$mediaUrl' : null;

    return MainCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemoryListScreen(
                        baseUrl: baseUrl,
                        authHeaders: authHeaders,
                      ),
                    ),
                  ),
                  child: Text(
                    '보러가기 →',
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
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 118,
        child: Material(
          color: kMainPaper,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: mainBody(size: 13, weight: FontWeight.w800),
                  ),
                  Text(subtitle, style: mainBody(size: 11, color: kMainMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
