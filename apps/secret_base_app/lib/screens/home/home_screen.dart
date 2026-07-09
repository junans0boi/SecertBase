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
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: _dDayCard(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
              sliver: SliverList.list(
                children: [
                  _heartSection(),
                  const SizedBox(height: 12),
                  _todayHubCard(),
                  const SizedBox(height: 12),
                  _quickRow(),
                  const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      gradient: kRoseGrad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$myName & $partnerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mainBody(
                    size: 13,
                    color: Colors.white.withAlpha(225),
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (dDay != null) ...[
                  Text(
                    'D+$dDay',
                    style: _dDayNumberStyle(
                      size: 50,
                      color: Colors.white,
                      weight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    startDate != null ? '$startDate 부터 함께' : '함께한 날들',
                    style: mainBody(
                      size: 13,
                      color: Colors.white.withAlpha(210),
                    ),
                  ),
                ] else ...[
                  Text(
                    '우리의 첫날을\n등록해보세요',
                    style: mainTitle(size: 34, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'D-day가 홈에 바로 보여요',
                    style: mainBody(
                      size: 13,
                      color: Colors.white.withAlpha(210),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(235),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(child: CozyMascot(size: 66)),
          ),
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
      builder: (context, child) {
        return GestureDetector(
          onTap: _sendHeart,
          child: Transform.scale(
            scale: _heartCooldown ? 1.0 : pressAnim.value,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: _heartCooldown ? null : kRoseGrad,
                color: _heartCooldown ? kMainPaperSoft : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _heartCooldown ? kMainLine : kMainRose.withAlpha(70),
                ),
                boxShadow: _heartCooldown
                    ? []
                    : [
                        BoxShadow(
                          color: kMainRose.withAlpha(42),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(_heartCooldown ? 0 : 235),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _heartCooldown ? Icons.favorite_border : Icons.favorite,
                      color: _heartCooldown ? kMainMuted : kMainRose,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _socket.isConnected
                          ? (_heartCooldown ? '마음이 도착했어요' : '하트 보내기')
                          : '연결되면 하트를 보낼 수 있어요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mainBody(
                        size: 16,
                        color: _heartCooldown ? kMainInk : Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _heartCooldown ? kMainMuted : Colors.white,
                    size: 20,
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
          const SizedBox(height: 8),
          Text(primaryText, style: mainTitle(size: 27, color: kMainInk)),
          const SizedBox(height: 6),
          Text(
            question?['text'] ?? '오늘의 질문을 불러오는 중...',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mainBody(size: 15, color: kMainInk, height: 1.5),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _statusPill(
                  myAnswered ? '나는 완료' : '내 답변 대기',
                  myAnswered,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusPill(
                  partnerAnswered ? '상대 완료' : '상대 대기',
                  partnerAnswered,
                ),
              ),
            ],
          ),
          if (mission != null) ...[
            const SizedBox(height: 10),
            _missionLine(
              '${mission['title'] ?? '오늘의 미션'}',
              myMissionCompleted,
              partnerMissionCompleted,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QaScreen()),
            ).then((_) => _loadToday()),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(myAnswered ? '답변 보기' : '바로 답하기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: kMainInk,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (mission != null && !myMissionCompleted) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _completeMission,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('미션 완료 표시'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: kMainInk,
                backgroundColor: kMainPaper.withAlpha(180),
                side: const BorderSide(color: kMainLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool done) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? kMainSageSoft : kMainPaper.withAlpha(180),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: done ? kMainSage.withAlpha(120) : kMainLine),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mainBody(
          size: 12,
          color: done ? kMainSage : kMainMuted,
          weight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  Widget _missionLine(String title, bool mineDone, bool partnerDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kMainPaper.withAlpha(175),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMainLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 18, color: kMainPeach),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mainBody(
                size: 13,
                color: kMainInk,
                weight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            mineDone && partnerDone ? '둘 다 완료' : '진행 중',
            style: mainBody(
              size: 12,
              color: kMainMuted,
              weight: FontWeight.w800,
            ),
          ),
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
