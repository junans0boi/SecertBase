import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import '../archive/qa_screen.dart';
import '../archive/capsule_screen.dart';
import '../date_roulette_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _auth = AuthService();
  final _socket = SocketService();

  Map<String, dynamic>? _coupleInfo;
  Map<String, dynamic>? _today;

  bool _heartCooldown = false;
  late final AnimationController _heartPressCtrl;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _load();

    _heartPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    _heartPressCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Future.wait([_loadCoupleInfo(), _loadToday()]);
  }

  Future<void> _loadCoupleInfo() async {
    final uid = _auth.user?['UserId'];
    if (uid == null) return;
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/couple/info?user_id=$uid'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && mounted) setState(() => _coupleInfo = data);
      }
    } catch (_) {}
  }

  Future<void> _loadToday() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/today?user_id=$uid'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && mounted) setState(() => _today = data);
      }
    } catch (_) {}
  }

  void _sendHeart() {
    if (_heartCooldown || !_socket.isConnected) return;
    _socket.sendHeart();
    _heartPressCtrl.forward().then((_) => _heartPressCtrl.reverse());
    setState(() => _heartCooldown = true);
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) setState(() => _heartCooldown = false);
    });
  }

  Future<void> _completeMission() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    final mission = _today?['mission'] as Map<String, dynamic>?;
    final instanceId = mission?['instanceId'];
    if (uid == null || instanceId == null) return;

    try {
      final res = await http.post(
        Uri.parse('${_auth.baseUrl}/api/missions/$instanceId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': uid}),
      );
      if (res.statusCode == 200) await _loadToday();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      child: RefreshIndicator(
        onRefresh: _load,
        color: kMainRose,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _dDayCard(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              sliver: SliverList.list(
                children: [
                  _todayHubCard(),
                  const SizedBox(height: 18),
                  _heartSection(),
                  const SizedBox(height: 18),
                  _quickRow(),
                  const SizedBox(height: 18),
                  _partnerCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dDayCard() {
    final dDay = _coupleInfo?['dDay'];
    final partnerName = _coupleInfo?['partnerName'] ?? '상대방';
    final startDate = _coupleInfo?['startDate'];
    final myName =
        _auth.user?['Nickname'] ??
        _auth.user?['nickname'] ??
        _auth.user?['UserName'] ??
        '나';

    return MainCard(
      padding: const EdgeInsets.all(22),
      gradient: kRoseGrad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$myName & $partnerName',
            style: mainBody(
              size: 14,
              color: Colors.white.withAlpha(220),
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (dDay != null) ...[
            Text(
              '${dDay}일째',
              style: _dDayNumberStyle(
                size: 44,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '함께한 날들',
              style: mainBody(size: 14, color: Colors.white.withAlpha(200)),
            ),
            if (startDate != null) ...[
              const SizedBox(height: 2),
              Text(
                '$startDate 부터',
                style: mainBody(size: 12, color: Colors.white.withAlpha(160)),
              ),
            ],
          ] else ...[
            Text(
              '기념일을 설정해보세요',
              style: mainBody(
                size: 16,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '사귄 날을 등록하면 D-Day를 알려드려요',
              style: mainBody(size: 13, color: Colors.white.withAlpha(200)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heartSection() {
    final pressAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _heartPressCtrl, curve: Curves.easeOut));

    return AnimatedBuilder(
      animation: _heartPressCtrl,
      builder: (_, __) {
        return Transform.scale(
          scale: _heartCooldown ? 1.0 : pressAnim.value,
          child: GestureDetector(
            onTap: _sendHeart,
            child: MainCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              color: _heartCooldown ? kMainPaperSoft : kMainRoseSoft,
              borderColor: _heartCooldown ? kMainLine : kMainRose.withAlpha(70),
              child: Row(
                children: [
                  Icon(
                    _heartCooldown ? Icons.favorite_border : Icons.favorite,
                    color: _heartCooldown ? kMainMuted : kMainRose,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _heartCooldown ? '상대방에게 전달됐어요' : '지금 이 순간을 전해요',
                      style: mainBody(
                        size: 14,
                        color: kMainInk,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_socket.isConnected)
                    Text(
                      '연결 필요',
                      style: mainBody(size: 11, color: kMainMuted),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _quickRow() {
    return Row(
      children: [
        Expanded(
          child: _QuickCard(
            icon: Icons.casino_outlined,
            label: '데이트 룰렛',
            color: kMainSky,
            bgColor: kMainSkySoft,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DateRouletteScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickCard(
            icon: Icons.inventory_2_outlined,
            label: '타임캡슐',
            color: kMainHoney,
            bgColor: kMainHoneySoft,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CapsuleScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _todayHubCard() {
    final question = _today?['question'] as Map<String, dynamic>?;
    final streak = _today?['streak'] as Map<String, dynamic>?;
    final mission = _today?['mission'] as Map<String, dynamic>?;
    final myAnswered = question?['myAnswered'] == true;
    final partnerAnswered = question?['partnerAnswered'] == true;
    final completedToday = streak?['completedToday'] == true;
    final streakCount = streak?['current'] ?? 0;
    final myMissionCompleted = mission?['myCompleted'] == true;
    final partnerMissionCompleted = mission?['partnerCompleted'] == true;
    final primaryText = myAnswered
        ? (partnerAnswered ? '답변 보러가기' : '상대 답변 기다리는 중')
        : '오늘 질문 답하기';

    return MainCard(
      padding: const EdgeInsets.all(20),
      color: completedToday ? kMainSageSoft : kMainHoneySoft,
      borderColor: (completedToday ? kMainSage : kMainHoney).withAlpha(110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '오늘 할 일',
                style: mainBody(
                  size: 13,
                  color: completedToday ? kMainSage : kMainHoney,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _miniBadge(completedToday ? '오늘 완료' : '$streakCount일 스트릭'),
            ],
          ),
          const SizedBox(height: 10),
          Text(primaryText, style: mainTitle(size: 24, color: kMainInk)),
          const SizedBox(height: 8),
          Text(
            question?['text'] ?? '오늘의 질문을 불러오는 중...',
            style: mainBody(size: 15, color: kMainInk, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(myAnswered ? '내 답변 완료' : '내 답변 대기', myAnswered),
              _chip(partnerAnswered ? '상대 답변 완료' : '상대 답변 대기', partnerAnswered),
              _chip(completedToday ? '오늘 루프 완료' : '스트릭 대기', completedToday),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QaScreen()),
              ).then((_) => _loadToday()),
              icon: const Icon(Icons.question_answer_outlined, size: 18),
              label: Text(myAnswered ? '답변 확인' : '질문 답하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kMainInk,
                backgroundColor: kMainPaper.withAlpha(180),
                side: const BorderSide(color: kMainLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (mission != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kMainPaper.withAlpha(170),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kMainLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 미션',
                    style: mainBody(
                      size: 12,
                      color: kMainSub,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${mission['title'] ?? ''}',
                    style: mainBody(
                      size: 16,
                      color: kMainInk,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mission['description'] ?? ''}',
                    style: mainBody(size: 13, color: kMainSub, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        myMissionCompleted ? '내 미션 완료' : '내 미션 대기',
                        myMissionCompleted,
                      ),
                      _chip(
                        partnerMissionCompleted ? '상대 미션 완료' : '상대 미션 대기',
                        partnerMissionCompleted,
                      ),
                    ],
                  ),
                  if (!myMissionCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _completeMission,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('내 미션 완료'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kMainInk,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: kMainPaper.withAlpha(200),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kMainLine),
      ),
      child: Text(
        label,
        style: mainBody(size: 11, color: kMainInk, weight: FontWeight.w800),
      ),
    );
  }

  Widget _chip(String label, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? kMainSageSoft : kMainPaperSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? kMainSage : kMainLine),
      ),
      child: Text(
        label,
        style: mainBody(size: 11, color: done ? kMainSage : kMainMuted),
      ),
    );
  }

  Widget _partnerCard() {
    final partnerName = _coupleInfo?['partnerName'] ?? '상대방';
    final partnerCode = _coupleInfo?['partnerCode'] as String?;
    final isOnline = _socket.presenceUsers.length >= 2;
    final partnerEmoji =
        (partnerCode != null ? _socket.profileEmojis[partnerCode] : null) ??
        '🙂';

    return MainCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isOnline ? kMainSageSoft : kMainPaperSoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(partnerEmoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerName,
                  style: mainBody(
                    size: 16,
                    color: kMainInk,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? '지금 비밀기지에 있어요' : '자리를 비웠어요',
                  style: mainBody(
                    size: 12,
                    color: isOnline ? kMainSage : kMainMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? kMainSage : kMainLine,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MainCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        color: bgColor,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: mainBody(
                  size: 14,
                  color: kMainInk,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _dDayNumberStyle({
  double size = 28,
  Color color = kMainInk,
  FontWeight weight = FontWeight.w700,
}) {
  return mainTitle(size: size, color: color, weight: weight);
}
