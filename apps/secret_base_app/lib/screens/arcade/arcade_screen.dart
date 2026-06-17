import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
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

  void _rebuild() { if (mounted) setState(() {}); }

  static const _games = [
    _GameInfo('🎲', '주사위', '1~6 랜덤', Color(0xFF7C5CFC), Color(0xFFEDE7FF)),
    _GameInfo('🎡', '룰렛', '운명의 선택', Color(0xFFD63384), Color(0xFFFFE4F0)),
    _GameInfo('✊', '가위바위보', '동시 선택', Color(0xFF00897B), Color(0xFFE0F2F1)),
    _GameInfo('🧠', '텔레파시', '마음이 통할까', Color(0xFFFF8F00), Color(0xFFFFF8E1)),
    _GameInfo('🏴‍☠️', '해적 룰렛', '폭탄을 피해라', Color(0xFFE53935), Color(0xFFFFEBEE)),
    _GameInfo('🀄', '윷놀이', '턴제 보드게임', Color(0xFF1976D2), Color(0xFFE3F2FD)),
    _GameInfo('🃏', 'UNO', '카드 대결', Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
    _GameInfo('💣', '폭탄 돌리기', '퀴즈 + 타이머', Color(0xFFEF6C00), Color(0xFFFFF3E0)),
  ];

  Widget _screen(int i) {
    switch (i) {
      case 0: return const DiceScreen();
      case 1: return const RouletteScreen();
      case 2: return const RpsScreen();
      case 3: return const TelepathyScreen();
      case 4: return const PirateScreen();
      case 5: return const YutScreen();
      case 6: return const UnoScreen();
      default: return const BombScreen();
    }
  }

  void _open(int i) => Navigator.push(context, MaterialPageRoute(builder: (_) => _screen(i)));

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
    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(users),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _games.length,
              itemBuilder: (_, i) => _GameCard(info: _games[i], onTap: () => _open(i)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<String> users) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE4F0), Color(0xFFFFF5F8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🕹️ 같이 놀자!',
                      style: GoogleFonts.notoSans(
                        fontSize: 22, fontWeight: FontWeight.w800, color: kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '오늘 어떤 게임 할까요?',
                      style: GoogleFonts.notoSans(fontSize: 13, color: kTextSub),
                    ),
                  ],
                ),
              ),
              _PresenceChip(users: users),
            ],
          ),
        ],
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
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: info.color.withAlpha(30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: info.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(info.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const Spacer(),
              Text(
                info.name,
                style: GoogleFonts.notoSans(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info.desc,
                style: GoogleFonts.notoSans(fontSize: 11, color: kTextMuted),
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
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Text('혼자', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kSuccess.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSuccess.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kSuccess),
          ),
          const SizedBox(width: 6),
          Text(
            users.join(' 💕 '),
            style: GoogleFonts.notoSans(color: kSuccess, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
