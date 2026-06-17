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

  void _rebuild() {
    if (mounted) setState(() {});
  }

  static const _games = [
    _GameInfo('🎲', '주사위', '1~6 랜덤', [Color(0xFF7C5CFC), Color(0xFF5B3FD4)]),
    _GameInfo('🎡', '룰렛', '운명의 선택', [Color(0xFFFF6B9D), Color(0xFFD94F7E)]),
    _GameInfo('✊', '가위바위보', '동시 선택', [Color(0xFF06D6A0), Color(0xFF049E77)]),
    _GameInfo('🧠', '텔레파시', '마음이 통할까', [Color(0xFFFFD166), Color(0xFFE0A800)]),
    _GameInfo('🏴‍☠️', '해적 룰렛', '폭탄을 피해라', [Color(0xFFFF6348), Color(0xFFCC4F3A)]),
    _GameInfo('🀄', '윷놀이', '턴제 보드게임', [Color(0xFF5DADE2), Color(0xFF2E86C1)]),
    _GameInfo('🃏', 'UNO', '108장 카드 대결', [Color(0xFFA29BFE), Color(0xFF6C5CE7)]),
    _GameInfo('💣', '폭탄 돌리기', '퀴즈 + 타이머', [Color(0xFFFF9F43), Color(0xFFE17B2F)]),
  ];

  Widget _buildScreen(int i) {
    switch (i) {
      case 0: return const DiceScreen();
      case 1: return const RouletteScreen();
      case 2: return const RpsScreen();
      case 3: return const TelepathyScreen();
      case 4: return const PirateScreen();
      case 5: return const YutScreen();
      case 6: return const UnoScreen();
      case 7: return const BombScreen();
      default: return const SizedBox();
    }
  }

  void _openGame(int i) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _buildScreen(i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns(context),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: _games.length,
                itemBuilder: (ctx, i) => _GameCard(
                  info: _games[i],
                  onTap: () => _openGame(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _gridColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  Widget _buildHeader() {
    final users = _socket.presenceUsers;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🕹️ 아케이드',
                style: GoogleFonts.notoSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kText,
                ),
              ),
              _PresenceChip(users: users),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 어떤 게임 할까요?',
            style: GoogleFonts.notoSans(fontSize: 14, color: kTextMuted),
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
  final List<Color> gradient;
  const _GameInfo(this.emoji, this.name, this.desc, this.gradient);
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: info.gradient.map((c) => c.withOpacity(0.25)).toList(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(info.emoji, style: const TextStyle(fontSize: 36)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info.desc,
                          style: GoogleFonts.notoSans(fontSize: 11, color: kTextMuted),
                        ),
                      ],
                    ),
                  ],
                ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: kTextMuted),
            ),
            const SizedBox(width: 6),
            Text('혼자', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kSuccess.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSuccess.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kSuccess),
          ),
          const SizedBox(width: 6),
          Text(
            users.join(' · '),
            style: GoogleFonts.notoSans(color: kSuccess, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
