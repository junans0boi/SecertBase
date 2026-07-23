import 'package:flutter/material.dart';

import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import 'game_lobby_screen.dart';
import 'games/bomb_screen.dart';
import 'games/catch_screen.dart';
import 'games/dice_screen.dart';
import 'games/pirate_screen.dart';
import 'games/roulette_screen.dart';
import 'games/rps_screen.dart';
import 'games/telepathy_screen.dart';
import 'games/uno_screen.dart';
import 'games/yut_screen.dart';

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  int? _selectedIdx;

  static const _games = [
    _GameInfo(
      type: 'yut',
      icon: Icons.grid_view_rounded,
      title: '윷놀이',
      description: '말 업기와 잡기까지 함께 즐기는 2인 보드게임',
      color: kMainSky,
      background: kMainSkySoft,
    ),
    _GameInfo(
      type: 'bomb',
      icon: Icons.timer_outlined,
      title: '폭탄 돌리기',
      description: '문제를 맞히고 시간이 끝나기 전에 폭탄을 넘겨요',
      color: kMainHoney,
      background: kMainHoneySoft,
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
      description: '내 숫자와 합계 예측을 동시에 고르는 심리전',
      color: kMainHoney,
      background: kMainHoneySoft,
    ),
    _GameInfo(
      type: 'uno',
      icon: Icons.style_rounded,
      title: '원카드',
      description: '색과 숫자를 맞춰 손패를 먼저 비우는 카드 대결',
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
      type: 'roulette',
      icon: Icons.track_changes_rounded,
      title: '룰렛',
      description: '선택지를 적고 돌려서 정하는 결정 도우미',
      color: kMainPeach,
      background: kMainPeachSoft,
    ),
    _GameInfo(
      type: 'telepathy',
      icon: Icons.psychology_outlined,
      title: '텔레파시',
      description: '같은 답을 고르면 성공하는 취향 맞추기',
      color: kMainLilac,
      background: kMainLilacSoft,
    ),
    _GameInfo(
      type: 'pirate',
      icon: Icons.sailing_outlined,
      title: '해적 룰렛',
      description: '칼을 하나씩 꽂다가 터지면 당첨되는 벌칙 게임',
      color: kMainRose,
      background: kMainRoseSoft,
    ),
    _GameInfo(
      type: 'catch',
      icon: Icons.brush_outlined,
      title: '그림 맞히기',
      description: '직접 그린 그림을 보고 상대가 정답을 맞혀요',
      color: kMainSage,
      background: kMainSageSoft,
    ),
  ];

  Widget _screen(String type) => switch (type) {
    'yut' => const YutScreen(),
    'bomb' => const BombScreen(),
    'uno' => const UnoScreen(),
    'zero' => const RpsScreen(fixedMode: 'hanabagi'),
    'dice' => const DiceScreen(),
    'roulette' => const RouletteScreen(),
    'telepathy' => const TelepathyScreen(),
    'pirate' => const PirateScreen(),
    'catch' => const CatchScreen(),
    _ => const RpsScreen(),
  };

  void _open(BuildContext context, _GameInfo game) {
    final socket = SocketService();
    final isActive = switch (game.type) {
      'yut' => socket.yutActive,
      'bomb' => socket.bombActive,
      'uno' => socket.unoActive,
      _ => false,
    };

    if (isActive) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _screen(game.type)),
      );
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
    );
  }

  Widget _buildStoryIcon(int idx) {
    final game = _games[idx];
    final isSelected = _selectedIdx == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedIdx = isSelected ? null : idx),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: game.background,
                border: Border.all(
                  color: isSelected ? game.color : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: game.color.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)]
                    : null,
              ),
              child: Icon(game.icon, color: game.color, size: 26),
            ),
            const SizedBox(height: 5),
            Text(
              game.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? game.color : kMainSub,
              ),
            ),
          ],
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
          Text(
            '위에서 게임을 골라보세요',
            style: mainBody(size: 15, color: kMainSub),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, _GameInfo game, bool connected) {
    return SingleChildScrollView(
      child: Column(
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
          // Future: stats row
          Row(
            children: [
              Expanded(
                child: _buildComingSoonCard(
                  Icons.bar_chart_rounded,
                  '기록',
                  '전적과 통계가 표시될 예정이에요',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildComingSoonCard(
                  Icons.diamond_rounded,
                  '재화',
                  '게임 보상과 아이템이 올 예정이에요',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard(IconData icon, String label, String hint) {
    return MainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: kMainSub),
              const SizedBox(width: 6),
              Text(label, style: mainTitle(size: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kMainHoneySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kMainHoney.withValues(alpha: 0.45)),
                ),
                child: Text(
                  '준비 중',
                  style: TextStyle(
                    fontSize: 10,
                    color: kMainHoney,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Icon(icon, size: 32, color: kMainMuted.withValues(alpha: 0.35)),
                const SizedBox(height: 6),
                Text(hint, style: mainBody(size: 11, color: kMainMuted), textAlign: TextAlign.center),
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

    return CozyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('함께 놀기', style: mainTitle(size: 32)),
                const SizedBox(height: 4),
                Text(
                  connected ? '상대방과 실시간으로 시작할 수 있어요' : '상대방 연결을 확인하고 있어요',
                  style: mainBody(size: 13, color: kMainSub),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _games.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _buildStoryIcon(i),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: selected == null
                  ? _buildEmptyState()
                  : _buildDetailCard(context, selected, connected),
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
