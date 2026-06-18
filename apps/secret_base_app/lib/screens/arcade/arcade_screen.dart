import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import 'games/dice_screen.dart';
import 'games/roulette_screen.dart';
import 'games/rps_screen.dart';
import 'games/telepathy_screen.dart';
import 'games/pirate_screen.dart';
import 'games/yut_screen.dart';
import 'games/uno_screen.dart';
import 'games/bomb_screen.dart';

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  static const _games = [
    _GameInfo('🎲', '주사위', '1~6 랜덤', kMainSky, kMainSkySoft),
    _GameInfo('🎡', '룰렛', '운명의 선택', kMainRose, kMainRoseSoft),
    _GameInfo('✊', '가위바위보', '동시 선택', kMainSage, kMainSageSoft),
    _GameInfo('🧠', '텔레파시', '마음이 통할까', kMainHoney, kMainHoneySoft),
    _GameInfo('🏴‍☠️', '해적 룰렛', '폭탄을 피해라', kMainPeach, kMainPeachSoft),
    _GameInfo('🀄', '윷놀이', '턴제 보드게임', kMainSky, kMainSkySoft),
    _GameInfo('🃏', 'UNO', '카드 대결', kMainRose, kMainRoseSoft),
    _GameInfo('💣', '폭탄 돌리기', '퀴즈 + 타이머', kMainHoney, kMainHoneySoft),
  ];

  Widget _screen(int i) {
    switch (i) {
      case 0:
        return const DiceScreen();
      case 1:
        return const RouletteScreen();
      case 2:
        return const RpsScreen();
      case 3:
        return const TelepathyScreen();
      case 4:
        return const PirateScreen();
      case 5:
        return const YutScreen();
      case 6:
        return const UnoScreen();
      default:
        return const BombScreen();
    }
  }

  void _open(int i) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => _screen(i)));

  int _cols(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final users = _socket.presenceUsers;
    final cols = _cols(context);
    return CozyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(users),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 13,
                mainAxisSpacing: 13,
                childAspectRatio: 0.94,
              ),
              itemCount: _games.length,
              itemBuilder: (_, i) =>
                  _GameCard(info: _games[i], onTap: () => _open(i)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<String> users) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: MainCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
        color: kMainPaper.withAlpha(235),
        child: Row(
          children: [
            const CozyMascot(size: 70),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('함께 놀 시간', style: mainTitle(size: 28)),
                  const SizedBox(height: 2),
                  Text('오늘 어떤 게임 할까요?', style: mainBody(size: 13)),
                ],
              ),
            ),
            _PresenceChip(users: users),
          ],
        ),
      ),
    );
  }
}

class _GameInfo {
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final Color bgColor;
  const _GameInfo(this.emoji, this.name, this.desc, this.color, this.bgColor);
}

class _GameCard extends StatelessWidget {
  final _GameInfo info;
  final VoidCallback onTap;
  const _GameCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MainCard(
        padding: EdgeInsets.zero,
        radius: 20,
        borderColor: info.color.withAlpha(95),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoodleBadge(
                color: info.color,
                backgroundColor: info.bgColor,
                child: Text(info.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const Spacer(),
              Text(
                info.name,
                style: mainBody(
                  size: 15,
                  color: kMainInk,
                  weight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info.desc,
                style: mainBody(size: 11, color: kMainMuted, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresenceChip extends StatelessWidget {
  final List<String> users;
  const _PresenceChip({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kMainPaperSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kMainLine),
        ),
        child: Text(
          '혼자',
          style: mainBody(size: 12, color: kMainMuted, height: 1),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kMainSageSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMainSage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: kMainSage,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            users.join(' · '),
            style: mainBody(
              size: 12,
              color: kMainInk,
              weight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
