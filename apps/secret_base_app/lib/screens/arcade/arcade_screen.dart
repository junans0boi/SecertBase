import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import 'game_lobby_screen.dart';
import 'games/dice_screen.dart';
import 'games/roulette_screen.dart';
import 'games/catch_screen.dart';
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
  int _selectedGame = 0;

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
    _GameInfo(
      'dice',
      '🎲',
      '주사위',
      '가볍게 운을 맡기고 싶을 때',
      '1부터 6까지 동시에 굴려요. 데이트 메뉴, 설거지 내기, 오늘의 작은 선택에 딱 좋아요.',
      '빠른 시작 · 10초 컷',
      kMainSky,
      kMainSkySoft,
    ),
    _GameInfo(
      'roulette',
      '🎡',
      '룰렛',
      '둘 중 아무도 못 고를 때',
      '선택지를 적고 돌리면 끝. 오늘 뭐 먹지, 어디 갈지 같은 애매한 순간을 귀엽게 정리해줘요.',
      '선택지 추가 후 시작',
      kMainRose,
      kMainRoseSoft,
    ),
    _GameInfo(
      'rps',
      '✊',
      '가위바위보',
      '가장 빠른 승부가 필요할 때',
      '3판선승, 묵찌빠, 제로까지 같이 즐길 수 있는 기본기 탄탄한 커플 승부예요.',
      '동시 선택 · 모드 지원',
      kMainSage,
      kMainSageSoft,
    ),
    _GameInfo(
      'telepathy',
      '🧠',
      '텔레파시',
      '우리 취향이 통하는지 확인',
      '같은 답을 고르면 성공. 가볍게 웃으면서 서로의 취향을 맞춰보는 미니 게임이에요.',
      '동시 입력 · 취향 매칭',
      kMainHoney,
      kMainHoneySoft,
    ),
    _GameInfo(
      'pirate',
      '🏴‍☠️',
      '해적 룰렛',
      '두근두근 벌칙 타이밍',
      '칼을 하나씩 꽂다가 터지면 당첨. 간단하지만 리액션이 좋아서 통화 중에도 잘 어울려요.',
      '랜덤 폭발 · 벌칙 추천',
      kMainPeach,
      kMainPeachSoft,
    ),
    _GameInfo(
      'yut',
      '🀄',
      '윷놀이',
      '느긋하게 한 판 하고 싶을 때',
      '말 업기, 잡기, 지름길까지 서버에서 동기화되는 2인 윷놀이예요. 캐릭터를 고르고 시작해요.',
      '턴제 보드게임 · 캐릭터 선택',
      kMainSky,
      kMainSkySoft,
    ),
    _GameInfo(
      'uno',
      '🃏',
      'UNO',
      '카드로 제대로 붙는 날',
      '클래식과 고와일드 모드를 지원해요. 스태킹, 챌린지, 모두내기로 오래 놀기 좋은 메인 게임이에요.',
      '모드 선택 · 추천 게임',
      kMainRose,
      kMainRoseSoft,
    ),
    _GameInfo(
      'bomb',
      '💣',
      '폭탄 돌리기',
      '퀴즈와 타이머로 긴장감 있게',
      '문제를 맞히면 폭탄을 넘겨요. 제한 시간이 끝나기 전까지 침착하게 답하는 순발력 게임이에요.',
      '퀴즈 + 타이머',
      kMainHoney,
      kMainHoneySoft,
    ),
    _GameInfo(
      'catch',
      '🎨',
      '캐치마인드',
      '그림으로 마음을 맞춰보기',
      '직접 그린 그림을 보고 상대가 맞히는 게임이에요. 못 그릴수록 더 재밌어지는 타입이에요.',
      '그림 퀴즈 · 창의력',
      kMainSage,
      kMainSageSoft,
    ),
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
      case 7:
        return const BombScreen();
      default:
        return const CatchScreen();
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

  @override
  Widget build(BuildContext context) {
    final users = _socket.presenceUsers;
    final selected = _games[_selectedGame];
    return CozyPage(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            sliver: SliverToBoxAdapter(child: _buildHeader(users)),
          ),
          SliverToBoxAdapter(child: _storySelector()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
            sliver: SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _GameDetailCard(
                  key: ValueKey(selected.gameType),
                  info: selected,
                  onEnter: () => _open(_selectedGame),
                ),
              ),
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
                        '실시간 게임만 모았어요',
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

  Widget _storySelector() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: _games.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final info = _games[index];
          final selected = index == _selectedGame;
          return _GameStoryItem(
            info: info,
            selected: selected,
            onTap: () => setState(() => _selectedGame = index),
          );
        },
      ),
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
  final String detail;
  final String notice;
  final Color color;
  final Color bgColor;
  const _GameInfo(
    this.gameType,
    this.emoji,
    this.name,
    this.desc,
    this.detail,
    this.notice,
    this.color,
    this.bgColor,
  );
}

class _GameStoryItem extends StatelessWidget {
  final _GameInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _GameStoryItem({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 70 : 64,
              height: selected ? 70 : 64,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? kRoseGrad : null,
                color: selected ? null : kMainPaper,
                border: selected
                    ? null
                    : Border.all(color: info.color.withAlpha(80)),
                boxShadow: [
                  BoxShadow(
                    color: info.color.withAlpha(selected ? 45 : 14),
                    blurRadius: selected ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: info.bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(info.emoji, style: const TextStyle(fontSize: 27)),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              info.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mainBody(
                size: 12,
                color: selected ? kMainInk : kMainMuted,
                weight: selected ? FontWeight.w900 : FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameDetailCard extends StatelessWidget {
  final _GameInfo info;
  final VoidCallback onEnter;

  const _GameDetailCard({super.key, required this.info, required this.onEnter});

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: const EdgeInsets.all(0),
      borderColor: info.color.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [info.bgColor, kMainPaper],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                _GameLogo(info: info),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NoticePill(info: info),
                      const SizedBox(height: 10),
                      Text(
                        info.name,
                        style: mainTitle(
                          size: 40,
                          color: kMainInk,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        info.desc,
                        style: mainBody(
                          size: 14,
                          color: kMainSub,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '게임 안내',
                  style: mainBody(
                    size: 13,
                    color: info.color,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.detail,
                  style: mainBody(size: 15, color: kMainInk, height: 1.55),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TinyInfo(icon: Icons.favorite, label: '2인 전용'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TinyInfo(
                        icon: Icons.bolt_rounded,
                        label: info.gameType == 'yut' || info.gameType == 'uno'
                            ? '긴 호흡'
                            : '빠른 플레이',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onEnter,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text('${info.name} 접속'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: info.color,
                    foregroundColor: Colors.white,
                    textStyle: mainBody(size: 16, weight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameLogo extends StatelessWidget {
  final _GameInfo info;

  const _GameLogo({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 124,
      decoration: BoxDecoration(
        color: info.color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: info.color.withAlpha(55),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(info.emoji, style: const TextStyle(fontSize: 48)),
          Positioned(
            bottom: 14,
            child: Text(
              info.name,
              style: mainBody(
                size: 12,
                color: Colors.white,
                weight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticePill extends StatelessWidget {
  final _GameInfo info;

  const _NoticePill({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: info.color.withAlpha(80)),
      ),
      child: Text(
        info.notice,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mainBody(
          size: 11,
          color: info.color,
          weight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _TinyInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kMainLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: kMainRose),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mainBody(
                size: 12,
                color: kMainInk,
                weight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
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
