import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/socket_service.dart';
import 'game_lobby_screen.dart';
import 'games/blackjack_screen.dart';
import 'games/bomb_screen.dart';
import 'games/bowling_screen.dart';
import 'games/catch_screen.dart';
import 'games/dice_screen.dart';
import 'games/oldmaid_screen.dart';
import 'games/penalty_screen.dart';
import 'games/pirate_screen.dart';
import 'games/roulette_screen.dart';
import 'games/rps_screen.dart';
import 'games/telepathy_screen.dart';
import 'games/uno_screen.dart';
import 'games/tank_screen.dart';
import 'games/gostop_screen.dart';
import 'games/yut_screen.dart';
import 'games/marble_screen.dart';
import '../shop/shop_screen.dart';
import '../../widgets/game_session_presence.dart';
import '../../v2/v2.dart';

const _kUnrankedGames = {'telepathy', 'dice'};

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  final _auth = AuthService();
  int? _balance;
  bool _bonusClaimed = false;
  bool _bonusLoading = false;

  // gameType → {wins, losses, total}
  Map<String, Map<String, int>> _records = {};

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchRecords();
    SocketService().addListener(_onSocketUpdate);
  }

  @override
  void dispose() {
    SocketService().removeListener(_onSocketUpdate);
    super.dispose();
  }

  void _onSocketUpdate() {
    final newBalance = SocketService().walletBalance;
    if (newBalance != null && newBalance != _balance) {
      setState(() => _balance = newBalance);
    }
  }

  Future<void> _fetchBalance() async {
    final token = _auth.token;
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/wallet/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final lastBonus = data['last_bonus_date'] as String?;
        setState(() {
          _balance = data['balance'] as int;
          _bonusClaimed =
              lastBonus != null && lastBonus.substring(0, 10) == today;
        });
      }
    } catch (_) {}
  }

  Future<void> _claimBonus() async {
    if (_bonusClaimed || _bonusLoading) return;
    final token = _auth.token;
    if (token == null) return;
    setState(() => _bonusLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${_auth.baseUrl}/api/wallet/daily-bonus'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _balance = data['balance'] as int;
          _bonusClaimed = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _bonusLoading = false);
    }
  }

  Future<void> _fetchRecords() async {
    final token = _auth.token;
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/arcade/records'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted || res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final raw = data['records'] as Map<String, dynamic>? ?? {};
      final parsed = <String, Map<String, int>>{};
      for (final e in raw.entries) {
        final v = e.value as Map<String, dynamic>;
        parsed[e.key] = {
          'wins': (v['wins'] as num?)?.toInt() ?? 0,
          'losses': (v['losses'] as num?)?.toInt() ?? 0,
          'draws': (v['draws'] as num?)?.toInt() ?? 0,
          'total': (v['total'] as num?)?.toInt() ?? 0,
        };
      }
      setState(() => _records = parsed);
    } catch (_) {}
  }

  String _formatCoins(int v) {
    if (v >= 10000) {
      final man = v ~/ 10000;
      final rem = v % 10000;
      return rem == 0 ? '$man만' : '$man만$rem';
    }
    return v.toString();
  }

  static const _games = [
    _GameInfo(
      type: 'blackjack',
      icon: Icons.style,
      title: '블랙잭',
      description: '숨은 카드 한 장으로 겨루는 21점 대결 · 먼저 2승',
      tone: V2Tone.rose,
      kind: _Kind.card,
    ),
    _GameInfo(
      type: 'oldmaid',
      icon: Icons.elderly_rounded,
      title: '도둑잡기',
      description: '상대 카드를 뽑아 짝을 맞추고 조커를 피하는 동화 속 심리전',
      tone: V2Tone.honey,
      kind: _Kind.card,
    ),
    _GameInfo(
      type: 'yut',
      icon: Icons.grid_view_rounded,
      title: '윷놀이',
      description: '윷을 던져 말을 업고 잡으며 먼저 골인해요 · 말 2~4개, 30초 턴',
      tone: V2Tone.sky,
      kind: _Kind.board,
    ),
    _GameInfo(
      type: 'marble',
      icon: Icons.castle_rounded,
      title: '마블 작전',
      description: '주사위를 굴려 도시를 사고 상대를 파산시키는 2인 전략 보드게임',
      tone: V2Tone.lilac,
      kind: _Kind.board,
    ),
    _GameInfo(
      type: 'rps',
      icon: Icons.back_hand_outlined,
      title: '가위바위보',
      description: '단판, 3판, 묵찌빠 세 가지 모드',
      tone: V2Tone.sage,
      kind: _Kind.quick,
    ),
    _GameInfo(
      type: 'zero',
      icon: Icons.exposure_zero_rounded,
      title: '제로',
      description: '손가락을 숨기고 합계를 맞혀요 · 5라운드 승부',
      tone: V2Tone.honey,
      kind: _Kind.card,
    ),
    _GameInfo(
      type: 'uno',
      icon: Icons.style_rounded,
      title: '원카드',
      description: '색과 숫자를 맞춰 먼저 손패를 비워요 · 마지막 한 장엔 원카드!',
      tone: V2Tone.rose,
      kind: _Kind.card,
    ),
    _GameInfo(
      type: 'dice',
      icon: Icons.casino_outlined,
      title: '주사위',
      description: '1부터 6까지 동시에 굴리는 초간단 내기',
      tone: V2Tone.sky,
      kind: _Kind.quick,
    ),
    _GameInfo(
      type: 'telepathy',
      icon: Icons.psychology_outlined,
      title: '텔레파시',
      description: '둘 중 하나를 몰래 골라 같은 쪽이면 통했어요! · 밸런스 게임 5·10·15문제',
      tone: V2Tone.lilac,
      kind: _Kind.talk,
    ),
    _GameInfo(
      type: 'pirate',
      icon: Icons.sailing_outlined,
      title: '해적 룰렛',
      description: '번갈아 칼을 꽂다 폭탄 구멍을 찌르면 져요',
      tone: V2Tone.rose,
      kind: _Kind.quick,
    ),
    _GameInfo(
      type: 'penalty',
      icon: Icons.sports_soccer_rounded,
      title: '패널티킥',
      description: '골대 칸을 골라 넣고 막아요 · 3칸·6칸 중 방장이 골라요',
      tone: V2Tone.sky,
      kind: _Kind.quick,
    ),
    _GameInfo(
      type: 'bowling',
      icon: Icons.sports_baseball_rounded,
      title: '볼링',
      description: '타이밍 조준으로 10프레임 투구하여 점수 대결',
      tone: V2Tone.lilac,
      kind: _Kind.quick,
    ),
    _GameInfo(
      type: 'catch',
      icon: Icons.brush_outlined,
      title: '그림 맞히기',
      description: '한 사람이 그리면 상대가 힌트를 보며 정답을 맞혀요 · 번갈아 라운드',
      tone: V2Tone.sage,
      kind: _Kind.talk,
    ),
    _GameInfo(
      type: 'tank',
      icon: Icons.military_tech_rounded,
      title: '탱크 대작전',
      description: '각도와 파워를 조절해 상대 탱크를 포격하는 전략 게임',
      tone: V2Tone.honey,
      kind: _Kind.quick,
    ),
    _GameInfo(
      type: 'gostop',
      icon: Icons.style_outlined,
      title: '고스톱 (맞고)',
      description: '정통 규칙으로 즐기는 2인 맞고 · 25초 턴, 점수와 배수가 한눈에',
      tone: V2Tone.sage,
      kind: _Kind.card,
    ),
  ];

  Widget _screen(String type) {
    Widget screen = switch (type) {
      'blackjack' => const BlackjackScreen(),
      'oldmaid' => const OldMaidScreen(),
      'penalty' => const PenaltyScreen(),
      'bowling' => const BowlingScreen(),
      'yut' => const YutScreen(),
      'marble' => const MarbleScreen(),
      'bomb' => const BombScreen(),
      'uno' => const UnoScreen(),
      'zero' => const RpsScreen(fixedMode: 'hanabagi'),
      'dice' => const DiceScreen(),
      'roulette' => const RouletteScreen(),
      'telepathy' => const TelepathyScreen(),
      'pirate' => const PirateScreen(),
      'catch' => const CatchScreen(),
      'tank' => const TankScreen(),
      'gostop' => const GostopScreen(),
      _ => const RpsScreen(),
    };
    // Wrap resumable game types so the server tracks which socket is viewing them.
    if (type == 'yut' ||
        type == 'marble' ||
        type == 'uno' ||
        type == 'gostop') {
      screen = GameSessionPresence(gameType: type, child: screen);
    }
    return screen;
  }

  void _open(BuildContext context, _GameInfo game) {
    final socket = SocketService();
    final isActive = switch (game.type) {
      'yut' => socket.yutActive,
      'marble' => socket.marbleActive,
      'bomb' => socket.bombActive,
      'uno' => socket.unoActive,
      'gostop' => socket.gostopActive,
      _ => false,
    };

    // 게임에서 돌아오면 기록과 잔액을 다시 불러온다.
    void refresh(_) {
      if (!mounted) return;
      _fetchRecords();
      _fetchBalance();
    }

    if (isActive) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _screen(game.type)),
      ).then(refresh);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameLobbyScreen(
          gameType: game.type,
          title: game.title,
          description: game.description,
          emoji: '',
          color: game.color,
          backgroundColor: game.background,
          gameScreen: _screen(game.type),
        ),
      ),
    ).then(refresh);
  }

  // ── 2.1 UI: 출석 → 오늘의 추천 → 최근에 한 게임 → 종류 칩 + 게임 타일 ──

  _Kind? _kind;

  int get _dayOfYear {
    final now = DateTime.now();
    return now.difference(DateTime(now.year)).inDays;
  }

  /// One game a day: something neither of us has played yet, else any.
  _GameInfo get _recommended {
    final fresh = _games
        .where(
          (g) =>
              !_kUnrankedGames.contains(g.type) &&
              (_records[g.type]?['total'] ?? 0) == 0,
        )
        .toList();
    final pool = fresh.isNotEmpty ? fresh : _games;
    return pool[_dayOfYear % pool.length];
  }

  List<_GameInfo> get _recent {
    final played =
        _games.where((g) => (_records[g.type]?['total'] ?? 0) > 0).toList()
          ..sort(
            (a, b) => (_records[b.type]!['total']!).compareTo(
              _records[a.type]!['total']!,
            ),
          );
    return played.take(8).toList();
  }

  String _recordText(_GameInfo g) {
    if (_kUnrankedGames.contains(g.type)) return '함께 하는 게임';
    final r = _records[g.type];
    final total = r?['total'] ?? 0;
    if (total == 0) return '처음';
    final draws = r?['draws'] ?? 0;
    return '${r?['wins'] ?? 0}승 ${r?['losses'] ?? 0}패${draws > 0 ? ' $draws무' : ''}';
  }

  void _openShop() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));

  void _showGame(_GameInfo game) {
    final connected = SocketService().isConnected;
    final r = _records[game.type];
    final ranked = !_kUnrankedGames.contains(game.type);
    final wins = r?['wins'] ?? 0;
    final losses = r?['losses'] ?? 0;
    final total = r?['total'] ?? 0;
    showV2Sheet<void>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _GameArt(game: game, size: 72, radius: 22, iconSize: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: V2Text.title.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(game.description, style: V2Text.cap),
                  ],
                ),
              ),
            ],
          ),
          if (ranked) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(value: '$wins', label: '이김'),
                const SizedBox(width: 8),
                _Stat(value: '$losses', label: '짐'),
                const SizedBox(width: 8),
                _Stat(
                  value: total > 0 ? '${wins * 100 ~/ total}%' : '-',
                  label: '승률',
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          V2Button(
            label: '시작하기',
            icon: Icons.play_arrow_rounded,
            onPressed: connected
                ? () {
                    Navigator.pop(sheetContext);
                    _open(context, game);
                  }
                : null,
          ),
          if (!connected) ...[
            const SizedBox(height: 8),
            Text(
              '상대방 연결을 확인하고 있어요',
              textAlign: TextAlign.center,
              style: V2Text.cap,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final connected = SocketService().isConnected;
    final hero = _recommended;
    final recent = _recent;
    final visible = _kind == null
        ? _games
        : _games.where((g) => g.kind == _kind).toList();
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: V2Header(
          title: '놀이',
          subtitle: connected ? null : '상대방 연결을 확인하고 있어요',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _CoinPill(
                text: _balance == null ? '...' : _formatCoins(_balance!),
                onTap: _openShop,
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_fetchBalance(), _fetchRecords()]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _Attendance(
                claimed: _bonusClaimed,
                loading: _bonusLoading,
                onClaim: _claimBonus,
              ),
              const SizedBox(height: 12),
              _HeroGame(
                game: hero,
                fresh: (_records[hero.type]?['total'] ?? 0) == 0,
                onTap: () => _showGame(hero),
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('최근에 한 게임', style: V2Text.head),
                const SizedBox(height: 10),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final g = recent[i];
                      return Semantics(
                        button: true,
                        label: '${g.title}, ${_recordText(g)}',
                        child: GestureDetector(
                          onTap: () => _showGame(g),
                          child: SizedBox(
                            width: 88,
                            child: Column(
                              children: [
                                _GameArt(game: g, size: 88, radius: 22),
                                const SizedBox(height: 6),
                                Text(
                                  g.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V2Text.cap.copyWith(
                                    color: p.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text('전체 게임', style: V2Text.head)),
                  Text('${_games.length}개', style: V2Text.cap),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final k in <_Kind?>[null, ..._Kind.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: V2Chip(
                          label: k?.label ?? '전체',
                          selected: _kind == k,
                          onTap: () => setState(() => _kind = k),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                key: const Key('arcade_game_tiles'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: .86,
                ),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final g = visible[i];
                  return Semantics(
                    button: true,
                    label: '${g.title}, ${_recordText(g)}',
                    child: GestureDetector(
                      key: ValueKey('arcade_game_${g.type}'),
                      onTap: () => _showGame(g),
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _GameArt(
                                game: g,
                                radius: 22,
                                iconSize: 46,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(g.title, style: V2Text.bodyStrong),
                            Text(_recordText(g), style: V2Text.cap),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameInfo {
  final String type;
  final IconData icon;
  final String title;
  final String description;
  final V2Tone tone;

  /// 칩 분류: 보드 · 카드 · 순발력 · 마음.
  final _Kind kind;

  const _GameInfo({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
    required this.kind,
  });

  /// Icon color in the active theme (AA on [background]).
  Color get color => V2ToneColors.of(tone).text;
  Color get background => V2ToneColors.of(tone).soft;
}

enum _Kind {
  board('보드'),
  card('카드'),
  quick('순발력'),
  talk('마음');

  const _Kind(this.label);
  final String label;
}

/// Tone-gradient tile with the game icon (no illustrations).
class _GameArt extends StatelessWidget {
  const _GameArt({
    required this.game,
    this.size,
    this.radius = 20,
    this.iconSize = 34,
  });

  final _GameInfo game;
  final double? size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = V2Palette.of(context).tone(game.tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.soft, Color.lerp(t.soft, t.base, .55)!],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(game.icon, color: t.text, size: iconSize),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      label: '코인 $text, 상점 열기',
      child: ExcludeSemantics(
        child: Material(
          color: p.soft,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(text, style: V2Text.buttonSm.copyWith(color: p.ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Attendance extends StatelessWidget {
  const _Attendance({
    required this.claimed,
    required this.loading,
    required this.onClaim,
  });

  final bool claimed;
  final bool loading;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: claimed ? p.soft : p.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claimed ? '오늘 출석 완료' : '오늘 출석하고 500코인 받기',
                  style: V2Text.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(claimed ? '내일 또 받을 수 있어요' : '매일 한 번', style: V2Text.cap),
              ],
            ),
          ),
          if (!claimed)
            V2Button(
              label: '출석 +500',
              size: V2ButtonSize.sm,
              fullWidth: false,
              loading: loading,
              onPressed: onClaim,
            ),
        ],
      ),
    );
  }
}

class _HeroGame extends StatelessWidget {
  const _HeroGame({
    required this.game,
    required this.fresh,
    required this.onTap,
  });

  final _GameInfo game;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = V2Palette.of(context).tone(game.tone);
    return Semantics(
      button: true,
      label: '오늘의 추천 ${game.title}',
      child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            height: 196,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(t.text, Colors.black, .35)!,
                  Color.lerp(t.base, t.text, .35)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -10,
                  child: Icon(
                    game.icon,
                    size: 170,
                    color: Colors.white.withValues(alpha: .14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fresh ? '오늘의 추천 · 둘 다 아직 안 해 봤어요' : '오늘의 추천',
                        style: V2Text.label.copyWith(
                          color: Colors.white.withValues(alpha: .9),
                          letterSpacing: 0,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        game.title,
                        style: V2Text.title.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        game.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.cap.copyWith(
                          color: Colors.white.withValues(alpha: .88),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const ShapeDecoration(
                          color: Colors.white,
                          shape: StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF191F28),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '시작하기',
                              style: V2Text.buttonSm.copyWith(
                                color: const Color(0xFF191F28),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: p.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value, style: V2Text.sans(size: 20, weight: FontWeight.w800)),
            Text(label, style: V2Text.cap),
          ],
        ),
      ),
    );
  }
}
