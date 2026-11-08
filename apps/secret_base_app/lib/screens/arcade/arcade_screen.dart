import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/main_hero.dart';
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

const _kUnrankedGames = {'telepathy', 'dice'};

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  int? _selectedIdx;

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

  Widget _buildWalletBar() {
    final balance = _balance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kMainHoneySoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kMainHoney.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  balance != null ? '${_formatCoins(balance)}코인' : '...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kMainHoney,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!_bonusClaimed)
            GestureDetector(
              onTap: _bonusLoading ? null : _claimBonus,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: kRoseGrad,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_bonusLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 4),
                    const Text(
                      '출석 +500',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text('오늘 보너스 수령 완료', style: mainBody(size: 12, color: kMainMuted)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kMainLilacSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kMainLilac.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 14, color: kMainLilac),
                  const SizedBox(width: 4),
                  Text(
                    '상점',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kMainLilac,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildRecordCard(String gameType) {
    final r = _records[gameType];
    final wins = r?['wins'] ?? 0;
    final losses = r?['losses'] ?? 0;
    final draws = r?['draws'] ?? 0;
    final total = r?['total'] ?? 0;
    return MainCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: kMainSub),
              const SizedBox(width: 6),
              Text('기록', style: mainTitle(size: 14)),
            ],
          ),
          const SizedBox(height: 14),
          if (total == 0)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 32,
                    color: kMainMuted.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '아직 플레이 기록이 없어요',
                    style: mainBody(size: 11, color: kMainMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RecordStat('승', '$wins', kMainSky),
                    _RecordStat('패', '$losses', kMainRose),
                    if (draws > 0) _RecordStat('무', '$draws', kMainMuted),
                    _RecordStat(
                      '승률',
                      total > 0 ? '${(wins * 100 ~/ total)}%' : '-',
                      kMainSage,
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
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
      color: kMainRose,
      background: kMainRoseSoft,
    ),
    _GameInfo(
      type: 'oldmaid',
      icon: Icons.elderly_rounded,
      title: '도둑잡기',
      description: '상대 카드를 뽑아 짝을 맞추고 조커를 피하는 동화 속 심리전',
      color: kMainHoney,
      background: kMainHoneySoft,
    ),
    _GameInfo(
      type: 'yut',
      icon: Icons.grid_view_rounded,
      title: '윷놀이',
      description: '윷을 던져 말을 업고 잡으며 먼저 골인해요 · 말 2~4개, 30초 턴',
      color: kMainSky,
      background: kMainSkySoft,
    ),
    _GameInfo(
      type: 'marble',
      icon: Icons.castle_rounded,
      title: '마블 작전',
      description: '주사위를 굴려 도시를 사고 상대를 파산시키는 2인 전략 보드게임',
      color: kMainLilac,
      background: kMainLilacSoft,
    ),
    _GameInfo(
      type: 'rps',
      icon: Icons.back_hand_outlined,
      title: '가위바위보',
      description: '단판, 3판, 묵찌빠 세 가지 모드',
      color: kMainSage,
      background: kMainSageSoft,
    ),
    _GameInfo(
      type: 'zero',
      icon: Icons.exposure_zero_rounded,
      title: '제로',
      description: '손가락을 숨기고 합계를 맞혀요 · 5라운드 승부',
      color: kMainHoney,
      background: kMainHoneySoft,
    ),
    _GameInfo(
      type: 'uno',
      icon: Icons.style_rounded,
      title: '원카드',
      description: '색과 숫자를 맞춰 먼저 손패를 비워요 · 마지막 한 장엔 원카드!',
      color: kMainRose,
      background: kMainRoseSoft,
    ),
    _GameInfo(
      type: 'dice',
      icon: Icons.casino_outlined,
      title: '주사위',
      description: '1부터 6까지 동시에 굴리는 초간단 내기',
      color: kMainSky,
      background: kMainSkySoft,
    ),
    _GameInfo(
      type: 'telepathy',
      icon: Icons.psychology_outlined,
      title: '텔레파시',
      description: '둘 중 하나를 몰래 골라 같은 쪽이면 통했어요! · 밸런스 게임 5·10·15문제',
      color: kMainLilac,
      background: kMainLilacSoft,
    ),
    _GameInfo(
      type: 'pirate',
      icon: Icons.sailing_outlined,
      title: '해적 룰렛',
      description: '번갈아 칼을 꽂다 폭탄 구멍을 찌르면 져요',
      color: kMainRose,
      background: kMainRoseSoft,
    ),
    _GameInfo(
      type: 'penalty',
      icon: Icons.sports_soccer_rounded,
      title: '패널티킥',
      description: '골대 칸을 골라 넣고 막아요 · 3칸·6칸 중 방장이 골라요',
      color: kMainSky,
      background: kMainSkySoft,
    ),
    _GameInfo(
      type: 'bowling',
      icon: Icons.sports_baseball_rounded,
      title: '볼링',
      description: '타이밍 조준으로 10프레임 투구하여 점수 대결',
      color: kMainLilac,
      background: kMainLilacSoft,
    ),
    _GameInfo(
      type: 'catch',
      icon: Icons.brush_outlined,
      title: '그림 맞히기',
      description: '한 사람이 그리면 상대가 힌트를 보며 정답을 맞혀요 · 번갈아 라운드',
      color: kMainSage,
      background: kMainSageSoft,
    ),
    _GameInfo(
      type: 'tank',
      icon: Icons.military_tech_rounded,
      title: '탱크 대작전',
      description: '각도와 파워를 조절해 상대 탱크를 포격하는 전략 게임',
      color: kMainHoney,
      background: kMainHoneySoft,
    ),
    _GameInfo(
      type: 'gostop',
      icon: Icons.style_outlined,
      title: '고스톱 (맞고)',
      description: '정통 규칙으로 즐기는 2인 맞고 · 25초 턴, 점수와 배수가 한눈에',
      color: kMainSage,
      background: kMainSageSoft,
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

  Widget _buildStoryIcon(int idx) {
    final game = _games[idx];
    final isSelected = _selectedIdx == idx;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${game.title}${isSelected ? ' 선택됨' : ''}',
      child: GestureDetector(
        key: ValueKey('arcade_game_${game.type}'),
        onTap: () => setState(() => _selectedIdx = isSelected ? null : idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? kMainRoseSoft : kMainPaper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? kMainRose : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: kMainRose.withAlpha(isSelected ? 50 : 22),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: game.background,
                ),
                child: Icon(game.icon, color: game.color, size: 24),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  game.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mainBody(
                    size: 12,
                    color: isSelected ? kMainRose : kMainInk,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_esports_rounded, size: 60, color: kMainMuted),
          const SizedBox(height: 14),
          Text('위에서 게임을 골라보세요', style: mainBody(size: 15, color: kMainSub)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    _GameInfo game,
    bool connected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Game info + start button
        MainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: game.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(game.icon, color: game.color, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.title, style: mainTitle(size: 22)),
                        const SizedBox(height: 4),
                        Text(
                          game.description,
                          style: mainBody(size: 13, color: kMainSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: connected ? () => _open(context, game) : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    '시작하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: connected ? game.color : kMainMuted,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!connected) ...[
                const SizedBox(height: 8),
                Text(
                  '상대방 연결을 확인하고 있어요',
                  textAlign: TextAlign.center,
                  style: mainBody(size: 12, color: kMainMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 승패가 없는 협동·도구성 게임(텔레파시·주사위)에는 기록 카드를 두지 않는다.
        Row(
          children: [
            if (!_kUnrankedGames.contains(game.type)) ...[
              Expanded(child: _buildRecordCard(game.type)),
              const SizedBox(width: 10),
            ],
            Expanded(child: _buildWalletCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletCard() {
    final balance = _balance;
    return MainCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond_rounded, size: 16, color: kMainHoney),
              const SizedBox(width: 6),
              Text('내 코인', style: mainTitle(size: 14)),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  balance != null ? '${_formatCoins(balance)}코인' : '...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kMainHoney,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = SocketService().isConnected;
    final selected = _selectedIdx != null ? _games[_selectedIdx!] : null;

    return ColoredBox(
      color: kMainCream,
      child: Column(
        children: [
          MainTabHeader(
            safeTop: true,
            title: '둘이서 놀기',
            subtitle: connected ? '오늘은 어떤 게임으로 놀아볼까요?' : '상대방 연결을 확인하고 있어요',
            trailing: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kMainRoseSoft,
                shape: BoxShape.circle,
                border: Border.all(color: kMainLine),
              ),
              child: const Icon(Icons.sports_esports_rounded, color: kMainRose),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                _buildWalletBar(),
                Row(
                  children: [
                    Expanded(child: Text('게임 고르기', style: mainTitle(size: 24))),
                    Text(
                      '${_games.length}가지',
                      style: mainBody(size: 12, color: kMainMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (var i = 0; i < _games.length; i++) _buildStoryIcon(i),
                  ],
                ),
                const SizedBox(height: 20),
                if (selected == null)
                  MainCard(
                    radius: 26,
                    padding: const EdgeInsets.symmetric(vertical: 38),
                    child: _buildEmptyState(),
                  )
                else
                  _buildDetailCard(context, selected, connected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameInfo {
  final String type;
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color background;

  const _GameInfo({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.background,
  });
}

class _RecordStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RecordStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: mainBody(size: 11, color: kMainSub)),
      ],
    );
  }
}
