import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/main_design.dart';

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
        http.get(
          Uri.parse('${_auth.baseUrl}/api/map'),
          headers: _authHeaders,
        ),
      ]);
      if (!mounted) return;
      final couple = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final moments = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final mapData = jsonDecode(responses[2].body) as Map<String, dynamic>;
      final now = DateTime.now();
      final nowStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      setState(() {
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
      });
    } catch (_) {
      // Home remains resilient
    } finally {
      if (mounted) setState(() => _loading = false);
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
            _coupleCard(),
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
          title: Text('아직 오늘 남긴 기록이 없어요', style: mainBody(weight: FontWeight.w700)),
          subtitle: Text('오늘의 추억이나 장소를 기록해보세요!', style: mainBody(size: 12, color: kMainSub)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: kMainMuted),
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
                    Text('오늘 추가한 비밀지도 장소', style: mainBody(weight: FontWeight.w800, size: 13)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kMainSageSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '📍 ${pin['place_name']} ($cat)',
                          style: mainBody(size: 12, color: kMainInk, weight: FontWeight.w700),
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
                    const Icon(Icons.photo_library_rounded, color: kMainRose, size: 18),
                    const SizedBox(width: 6),
                    Text('오늘 업로드한 이미지/순간', style: mainBody(weight: FontWeight.w800, size: 13)),
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
                      final fullUrl = mediaUrl.isEmpty ? '' : (mediaUrl.startsWith('http') ? mediaUrl : '${_auth.baseUrl}$mediaUrl');
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
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_outlined, color: kMainMuted),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.note_alt_outlined, color: kMainRose, size: 28),
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
