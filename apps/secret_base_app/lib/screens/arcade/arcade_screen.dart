import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import 'game_lobby_screen.dart';
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
    _GameInfo('dice', '🎲', '주사위', '1~6 랜덤', kMainSky, kMainSkySoft),
    _GameInfo('roulette', '🎡', '룰렛', '운명의 선택', kMainRose, kMainRoseSoft),
    _GameInfo('rps', '✊', '가위바위보', '동시 선택', kMainSage, kMainSageSoft),
    _GameInfo('telepathy', '🧠', '텔레파시', '마음이 통할까', kMainHoney, kMainHoneySoft),
    _GameInfo(
      'pirate',
      '🏴‍☠️',
      '해적 룰렛',
      '폭탄을 피해라',
      kMainPeach,
      kMainPeachSoft,
    ),
    _GameInfo('yut', '🀄', '윷놀이', '턴제 보드게임', kMainSky, kMainSkySoft),
    _GameInfo('uno', '🃏', 'UNO', '카드 대결', kMainRose, kMainRoseSoft),
    _GameInfo('bomb', '💣', '폭탄 돌리기', '퀴즈 + 타이머', kMainHoney, kMainHoneySoft),
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

  void _open(int i) {
    final info = _games[i];
    if (info.gameType == 'uno') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const _UnoModeSelectScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameLobbyScreen(
          gameType: info.gameType,
          title: info.name,
          description: info.desc,
          emoji: info.emoji,
          color: info.color,
          backgroundColor: info.bgColor,
          gameScreen: _screen(i),
        ),
      ),
    );
  }

  int _cols(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= 1100) return 4;
    if (w >= 720) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final users = _socket.presenceUsers;
    final cols = _cols(context);
    return CozyPage(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            sliver: SliverToBoxAdapter(child: _buildHeader(users)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text('게임 목록', style: mainBody(weight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Text('${_games.length}개', style: mainBody(size: 12)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: cols == 2 ? 2.15 : 2.55,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        return MainCard(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 14,
            compact ? 9 : 12,
            compact ? 10 : 12,
            compact ? 9 : 12,
          ),
          radius: 16,
          color: kMainPaper.withAlpha(240),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kMainSageSoft,
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                  border: Border.all(color: kMainSage.withAlpha(120)),
                ),
                child: Icon(
                  Icons.sports_esports,
                  color: kMainInk,
                  size: compact ? 19 : 22,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '함께 놀 시간',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mainTitle(size: compact ? 21 : 24),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 1),
                      Text(
                        '바로 고르고 같이 시작해요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mainBody(size: 12, height: 1.2),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 78 : 132),
                child: _PresenceChip(users: users, compact: compact),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnoModeSelectScreen extends StatelessWidget {
  const _UnoModeSelectScreen();

  void _openLobby(BuildContext context, _UnoModeInfo mode) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameLobbyScreen(
          gameType: mode.lobbyType,
          title: mode.title,
          description: mode.description,
          emoji: mode.emoji,
          color: mode.color,
          backgroundColor: mode.backgroundColor,
          gameScreen: const UnoScreen(),
          unoMode: mode.mode,
        ),
      ),
    );
  }

  static const _modes = [
    _UnoModeInfo(
      mode: 'classic',
      lobbyType: 'uno_classic',
      emoji: '🃏',
      title: '클래식',
      description: '기본 UNO 룰',
      badge: '기본',
      color: kMainRose,
      backgroundColor: kMainRoseSoft,
    ),
    _UnoModeInfo(
      mode: 'go_wild',
      lobbyType: 'uno_go_wild',
      emoji: '⚡',
      title: '고와일드',
      description: '스태킹 + 모두내기',
      badge: '추천',
      color: kMainHoney,
      backgroundColor: kMainHoneySoft,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      body: SafeArea(
        child: CozyPage(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                sliver: SliverToBoxAdapter(
                  child: _Header(onBack: () => Navigator.of(context).pop()),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.crossAxisExtent >= 720;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: wide ? 2 : 1,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: wide ? 0.82 : 1.75,
                      ),
                      itemCount: _modes.length,
                      itemBuilder: (_, i) => _UnoModeCard(
                        mode: _modes[i],
                        wide: wide,
                        onTap: () => _openLobby(context, _modes[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      radius: 16,
      color: kMainPaper.withAlpha(242),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('UNO 모드 선택', style: mainTitle(size: 24)),
                const SizedBox(height: 2),
                Text(
                  '플레이할 룰을 고르고 대기방에 들어가요',
                  style: mainBody(size: 12, color: kMainSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnoModeInfo {
  final String mode;
  final String lobbyType;
  final String emoji;
  final String title;
  final String description;
  final String badge;
  final Color color;
  final Color backgroundColor;

  const _UnoModeInfo({
    required this.mode,
    required this.lobbyType,
    required this.emoji,
    required this.title,
    required this.description,
    required this.badge,
    required this.color,
    required this.backgroundColor,
  });
}

class _UnoModeCard extends StatelessWidget {
  final _UnoModeInfo mode;
  final bool wide;
  final VoidCallback onTap;

  const _UnoModeCard({
    required this.mode,
    required this.wide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: mode.backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: mode.color.withAlpha(110), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: mode.color.withAlpha(26),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(wide ? 18 : 14),
            child: wide ? _wideContent() : _compactContent(),
          ),
        ),
      ),
    );
  }

  Widget _compactContent() {
    return Row(
      children: [
        _cardFace(92),
        const SizedBox(width: 16),
        Expanded(child: _textContent()),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward_ios, size: 18, color: mode.color),
      ],
    );
  }

  Widget _wideContent() {
    return Column(
      children: [
        Expanded(child: Center(child: _cardFace(150))),
        const SizedBox(height: 18),
        _textContent(center: true),
      ],
    );
  }

  Widget _textContent({bool center = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: mode.color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            mode.badge,
            style: mainBody(
              size: 11,
              color: Colors.white,
              weight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          mode.title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: mainTitle(size: wide ? 28 : 24, color: kMainInk),
        ),
        const SizedBox(height: 4),
        Text(
          mode.description,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _cardFace(double width) {
    return Transform.rotate(
      angle: mode.mode == 'classic' ? -0.08 : 0.08,
      child: Container(
        width: width,
        height: width * 1.42,
        decoration: BoxDecoration(
          color: mode.mode == 'classic'
              ? const Color(0xFF171717)
              : const Color(0xFF7B3FF2),
          borderRadius: BorderRadius.circular(width * 0.09),
          border: Border.all(color: Colors.white, width: width * 0.045),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.55,
              child: Container(
                width: width * 0.78,
                height: width * 0.5,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(235),
                  borderRadius: BorderRadius.circular(width * 0.35),
                ),
              ),
            ),
            Text(mode.emoji, style: TextStyle(fontSize: width * 0.34)),
            Positioned(
              bottom: width * 0.17,
              child: Text(
                mode.mode == 'classic' ? 'CLASSIC' : 'GO WILD',
                style: mainBody(
                  size: width * 0.12,
                  color: Colors.white,
                  weight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameInfo {
  final String gameType;
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final Color bgColor;
  const _GameInfo(
    this.gameType,
    this.emoji,
    this.name,
    this.desc,
    this.color,
    this.bgColor,
  );
}

class _GameCard extends StatelessWidget {
  final _GameInfo info;
  final VoidCallback onTap;
  const _GameCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 165;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: kMainPaper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: info.color.withAlpha(85)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A7F70).withAlpha(12),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 34 : 42,
                      height: compact ? 34 : 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: info.bgColor,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: info.color.withAlpha(120)),
                      ),
                      child: Text(
                        info.emoji,
                        style: TextStyle(
                          fontSize: compact ? 19 : 22,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 7 : 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mainBody(
                              size: compact ? 13 : 14,
                              color: kMainInk,
                              weight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            info.desc,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: mainBody(
                              size: compact ? 10 : 11,
                              color: kMainMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: info.color,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PresenceChip extends StatelessWidget {
  final List<String> users;
  final bool compact;
  const _PresenceChip({required this.users, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: kMainPaperSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kMainLine),
        ),
        child: Text(
          '혼자',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: mainBody(
            size: compact ? 11 : 12,
            color: kMainMuted,
            height: 1,
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: kMainSageSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMainSage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: kMainSage,
            ),
          ),
          SizedBox(width: compact ? 4 : 6),
          Flexible(
            child: Text(
              compact ? '${users.length}명' : users.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mainBody(
                size: compact ? 11 : 12,
                color: kMainInk,
                weight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
