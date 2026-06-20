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
  Map<String, dynamic>? _todayQA;

  bool _heartCooldown = false;
  late final AnimationController _pulseCtrl;
  late final AnimationController _heartPressCtrl;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _load();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _heartPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    _pulseCtrl.dispose();
    _heartPressCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Future.wait([_loadCoupleInfo(), _loadQA()]);
  }

  Future<void> _loadCoupleInfo() async {
    final uid = _auth.user?['UserId'];
    if (uid == null) return;
    try {
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/couple/info?user_id=$uid'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && mounted) setState(() => _coupleInfo = data);
      }
    } catch (_) {}
  }

  Future<void> _loadQA() async {
    try {
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/qa/today'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && mounted) setState(() => _todayQA = data);
      }
    } catch (_) {}
  }

  Future<void> _setStartDate(DateTime picked) async {
    final uid = _auth.user?['UserId'];
    if (uid == null) return;
    final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      final res = await http.patch(
        Uri.parse('${_auth.baseUrl}/api/couple/info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': uid, 'start_date': formatted}),
      );
      if (res.statusCode == 200) await _loadCoupleInfo();
    } catch (_) {}
  }

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kMainRose,
            onPrimary: Colors.white,
            surface: kMainPaper,
            onSurface: kMainInk,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) await _setStartDate(picked);
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
                  _heartSection(),
                  const SizedBox(height: 18),
                  _quickRow(),
                  const SizedBox(height: 18),
                  _qaCard(),
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
    final myName = _auth.user?['UserName'] ?? '나';

    return MainCard(
      padding: const EdgeInsets.all(22),
      gradient: kRoseGrad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$myName & $partnerName',
                style: mainBody(size: 14, color: Colors.white.withAlpha(220), weight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: _showDatePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_calendar_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('날짜', style: mainBody(size: 11, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (dDay != null) ...[
            Text(
              '❤️ ${dDay}일째',
              style: GoogleFontsGaegu(size: 44, color: Colors.white, weight: FontWeight.w700),
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
            Text('✨ 기념일을 설정해보세요', style: mainBody(size: 16, color: Colors.white, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('사귄 날을 등록하면 D-Day를 알려드려요', style: mainBody(size: 13, color: Colors.white.withAlpha(200))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('기념일 설정하기', style: mainBody(size: 13, color: kMainRose, weight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heartSection() {
    final pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    final pressAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _heartPressCtrl, curve: Curves.easeOut),
    );

    return Column(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_pulseCtrl, _heartPressCtrl]),
          builder: (_, __) {
            final scale = _heartCooldown ? 0.95 : pulseAnim.value * pressAnim.value;
            return Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: _sendHeart,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _heartCooldown
                        ? const LinearGradient(colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)])
                        : kRoseGrad,
                    boxShadow: _heartCooldown
                        ? []
                        : [
                            BoxShadow(
                              color: kMainRose.withAlpha(80),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 60),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          _heartCooldown ? '상대방에게 전달됐어요 💕' : '지금 이 순간을 전해요',
          style: mainBody(size: 13, color: _heartCooldown ? kMainSage : kMainSub, weight: FontWeight.w600),
        ),
        if (!_socket.isConnected)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('소켓 연결 필요', style: mainBody(size: 11, color: kMainMuted)),
          ),
      ],
    );
  }

  Widget _quickRow() {
    return Row(
      children: [
        Expanded(
          child: _QuickCard(
            emoji: '🎲',
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
            emoji: '🕯️',
            label: '타임캡슐',
            color: kMainHoney,
            bgColor: kMainHoneySoft,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CapsuleScreen())),
          ),
        ),
      ],
    );
  }

  Widget _qaCard() {
    final question = _todayQA?['question'] as Map<String, dynamic>?;
    final answers = (_todayQA?['answers'] as List?) ?? [];
    final myId = _auth.user?['UserId']?.toString();
    final myAnswered = answers.any((a) => a['user_id']?.toString() == myId);
    final partnerAnswered = answers.any((a) => a['user_id']?.toString() != myId);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QaScreen()),
      ).then((_) => _loadQA()),
      child: MainCard(
        padding: const EdgeInsets.all(18),
        color: kMainHoneySoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('❓ 오늘의 질문', style: mainBody(size: 13, color: kMainHoney, weight: FontWeight.w700)),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kMainMuted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              question?['question'] ?? '오늘의 질문을 불러오는 중...',
              style: mainBody(size: 15, color: kMainInk, height: 1.5),
            ),
            if (question != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _chip(myAnswered ? '내 답변 ✓' : '내 답변 대기', myAnswered),
                  const SizedBox(width: 8),
                  _chip(partnerAnswered ? '상대 답변 ✓' : '상대 답변 대기', partnerAnswered),
                ],
              ),
            ],
          ],
        ),
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
      child: Text(label, style: mainBody(size: 11, color: done ? kMainSage : kMainMuted)),
    );
  }

  Widget _partnerCard() {
    final partnerName = _coupleInfo?['partnerName'] ?? '상대방';
    final partnerCode = _coupleInfo?['partnerCode'] as String?;
    final isOnline = _socket.presenceUsers.length >= 2;
    final partnerEmoji = (partnerCode != null ? _socket.profileEmojis[partnerCode] : null) ?? '🙂';

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
                Text(partnerName, style: mainBody(size: 16, color: kMainInk, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  isOnline ? '지금 비밀기지에 있어요 🌿' : '자리를 비웠어요',
                  style: mainBody(size: 12, color: isOnline ? kMainSage : kMainMuted),
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
  final String emoji;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.emoji,
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
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: mainBody(size: 14, color: kMainInk, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper so home_screen doesn't need a separate import
TextStyle GoogleFontsGaegu({double size = 28, Color color = kMainInk, FontWeight weight = FontWeight.w700}) {
  return mainTitle(size: size, color: color, weight: weight);
}
