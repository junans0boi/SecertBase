import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/today_api.dart';
import 'memory_list_screen.dart';
import 'today_card.dart';
import 'today_loop_viewer.dart';
import '../secret_base/secret_base_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  Map<String, dynamic>? _coupleInfo;
  List<Map<String, dynamic>> _recentMoments = [];
  List<Map<String, dynamic>> _todayPins = [];
  List<Map<String, dynamic>> _todayMoments = [];
  TodayState? _todayState;
  Map<String, dynamic>? _memoryCard;
  int _memoryCardTotal = 0;
  bool _loading = true;

  Map<String, String> get _authHeaders => {
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final todayFuture = _loadTodayState();
    try {
      final userId = _auth.user?['UserId'] ?? _auth.user?['id'];
      final responses = await Future.wait([
        http.get(
          Uri.parse('${_auth.baseUrl}/api/couple/info'),
          headers: _authHeaders,
        ),
        http.get(
          Uri.parse('${_auth.baseUrl}/api/setlog').replace(
            queryParameters: {if (userId != null) 'user_id': '$userId'},
          ),
          headers: _authHeaders,
        ),
        http.get(Uri.parse('${_auth.baseUrl}/api/map'), headers: _authHeaders),
        http.get(
          Uri.parse('${_auth.baseUrl}/api/retention/memory-card'),
          headers: _authHeaders,
        ),
      ]);
      if (!mounted) return;
      final couple = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final moments = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final mapData = jsonDecode(responses[2].body) as Map<String, dynamic>;
      final todayState = await todayFuture;
      final now = DateTime.now();
      final nowStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      setState(() {
        _todayState = todayState;
        if (responses[0].statusCode == 200 && couple['ok'] == true) {
          _coupleInfo = couple;
        }
        if (responses[1].statusCode == 200 && moments['ok'] == true) {
          final allPosts = (moments['posts'] as List? ?? const [])
              .map((post) => Map<String, dynamic>.from(post as Map))
              .toList();
          _recentMoments = allPosts.take(3).toList();
          _todayMoments = allPosts.where((post) {
            final dateStr = '${post['taken_at'] ?? post['captured_at'] ?? ''}';
            return dateStr.startsWith(nowStr) || dateStr.contains(nowStr);
          }).toList();
        }
        if (responses[2].statusCode == 200 && mapData['ok'] == true) {
          final allPins = (mapData['pins'] as List? ?? const [])
              .map((pin) => Map<String, dynamic>.from(pin as Map))
              .toList();
          _todayPins = allPins.where((pin) {
            final dateStr = '${pin['visit_date'] ?? pin['created_at'] ?? ''}';
            return dateStr.startsWith(nowStr) || dateStr.contains(nowStr);
          }).toList();
        }
        if (responses[3].statusCode == 200) {
          final mc = jsonDecode(responses[3].body) as Map<String, dynamic>;
          if (mc['ok'] == true && mc['card'] != null) {
            _memoryCard = mc['card'] as Map<String, dynamic>;
            _memoryCardTotal = mc['total_count'] as int? ?? 0;
          } else {
            _memoryCard = null;
            _memoryCardTotal = 0;
          }
        }
      });
    } catch (_) {
      // Home remains resilient
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<TodayState?> _loadTodayState() async {
    final token = _auth.token;
    if (token == null) return null;
    final api = TodayApi(baseUrl: _auth.baseUrl, token: token);
    try {
      return await api.fetchState();
    } catch (_) {
      return null;
    } finally {
      api.close();
    }
  }

  void _openTodayLoop() {
    final state = _todayState;
    if (state == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TodayLoopViewer(state: state, baseUrl: _auth.baseUrl),
      ),
    );
    _markTodayLoopViewed();
  }

  Future<void> _markTodayLoopViewed() async {
    final token = _auth.token;
    final state = _todayState;
    if (token == null || state == null || !state.canOpenLoop) return;
    final api = TodayApi(baseUrl: _auth.baseUrl, token: token);
    try {
      final viewedAt = await api.markViewed();
      if (!mounted) return;
      setState(() {
        _todayState = TodayState(
          date: state.date,
          status: TodayStatus.viewed,
          hasPartnerMoment: state.hasPartnerMoment,
          revealedAt: state.revealedAt,
          viewedAt: viewedAt,
          myMoment: state.myMoment,
          partnerMoment: state.partnerMoment,
        );
      });
    } catch (_) {
      // Viewing remains available even if the analytics acknowledgement fails.
    } finally {
      api.close();
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
            if (_loading && _todayState == null)
              const MainCard(
                child: SizedBox(
                  height: 96,
                  child: Center(
                    child: CircularProgressIndicator(color: kMainRose),
                  ),
                ),
              )
            else if (_todayState != null)
              TodayCard(
                state: _todayState!,
                onCreateMoment: () => widget.onNavigate(1),
                onOpenLoop: _openTodayLoop,
              ),
            if (_loading || _todayState != null) const SizedBox(height: 18),
            _coupleCard(),
            if (_memoryCard != null) ...[
              const SizedBox(height: 18),
              _MemoryCardWidget(
                card: _memoryCard!,
                totalCount: _memoryCardTotal,
                baseUrl: _auth.baseUrl,
                authHeaders: _authHeaders,
              ),
            ],
            const SizedBox(height: 18),
            _sectionTitle('오늘의 소식 & MomentLoop', () => widget.onNavigate(1)),
            const SizedBox(height: 8),
            _momentPreview(),
            const SizedBox(height: 18),
            _sectionTitle('함께하기', null),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Shortcut(
                    icon: Icons.map_outlined,
                    title: '비밀 지도',
                    subtitle: '우리 장소 보기',
                    color: kMainSage,
                    onTap: () => widget.onNavigate(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Shortcut(
                    icon: Icons.sports_esports_outlined,
                    title: '함께 놀기',
                    subtitle: '세 가지 게임',
                    color: kMainRose,
                    onTap: () => widget.onNavigate(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Shortcut(
              icon: Icons.cottage_outlined,
              title: '우리의 비밀기지',
              subtitle: '마일스톤과 월별 엽서',
              color: kMainLilac,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SecretBaseScreen(
                    baseUrl: _auth.baseUrl,
                    authHeaders: _authHeaders,
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _sectionTitle(String title, VoidCallback? onTap) {
    return Row(
      children: [
        Expanded(child: Text(title, style: mainTitle(size: 20))),
        if (onTap != null)
          IconButton(
            tooltip: '전체 보기',
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
      ],
    );
  }

  Widget _momentPreview() {
    if (_loading) {
      return const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator(color: kMainRose)),
      );
    }

    final hasTodayPins = _todayPins.isNotEmpty;
    final hasTodayMoments = _todayMoments.isNotEmpty;

    if (!hasTodayPins && !hasTodayMoments) {
      return MainCard(
        child: ListTile(
          leading: const Icon(Icons.auto_stories_outlined, color: kMainRose),
          title: Text(
            '아직 오늘 남긴 기록이 없어요',
            style: mainBody(weight: FontWeight.w700),
          ),
          subtitle: Text(
            '오늘의 추억이나 장소를 기록해보세요!',
            style: mainBody(size: 12, color: kMainSub),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: kMainMuted,
          ),
          onTap: () => widget.onNavigate(1),
        ),
      );
    }

    return Column(
      children: [
        if (hasTodayPins) ...[
          MainCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place_rounded, color: kMainSage, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '오늘 추가한 비밀지도 장소',
                      style: mainBody(weight: FontWeight.w800, size: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _todayPins.map((pin) {
                    final cat = pin['category'] ?? '기타';
                    return InkWell(
                      onTap: () => widget.onNavigate(1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kMainSageSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '📍 ${pin['place_name']} ($cat)',
                          style: mainBody(
                            size: 12,
                            color: kMainInk,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (hasTodayMoments) ...[
          MainCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_rounded,
                      color: kMainRose,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '오늘 업로드한 이미지/순간',
                      style: mainBody(weight: FontWeight.w800, size: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _todayMoments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) {
                      final m = _todayMoments[i];
                      final mediaUrl = '${m['media_url'] ?? ''}'.trim();
                      final fullUrl = mediaUrl.isEmpty
                          ? ''
                          : (mediaUrl.startsWith('http')
                                ? mediaUrl
                                : '${_auth.baseUrl}$mediaUrl');
                      return GestureDetector(
                        onTap: () => widget.onNavigate(1),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: kMainRoseSoft,
                              child: fullUrl.isNotEmpty
                                  ? Image.network(
                                      fullUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: kMainMuted,
                                            ),
                                          ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.note_alt_outlined,
                                        color: kMainRose,
                                        size: 28,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
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
                    errorBuilder: (_, __, ___) => Container(
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

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 16),
              Text(title, style: mainBody(weight: FontWeight.w800)),
              Text(subtitle, style: mainBody(size: 12, color: kMainSub)),
            ],
          ),
        ),
      ),
    );
  }
}
