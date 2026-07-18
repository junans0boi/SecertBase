import 'package:flutter/material.dart';

import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import 'game_lobby_screen.dart';
import 'games/bomb_screen.dart';
import 'games/dice_screen.dart';
import 'games/rps_screen.dart';
import 'games/uno_screen.dart';
import 'games/yut_screen.dart';

class ArcadeScreen extends StatelessWidget {
  const ArcadeScreen({super.key});

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
  ];

  Widget _screen(String type) => switch (type) {
    'yut' => const YutScreen(),
    'bomb' => const BombScreen(),
    'uno' => const UnoScreen(),
    'zero' => const RpsScreen(fixedMode: 'hanabagi'),
    'dice' => const DiceScreen(),
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

  @override
  Widget build(BuildContext context) {
    final connected = SocketService().isConnected;
    return CozyPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Text('함께 놀기', style: mainTitle(size: 32)),
          const SizedBox(height: 4),
          Text(
            connected ? '상대방과 실시간으로 시작할 수 있어요' : '상대방 연결을 확인하고 있어요',
            style: mainBody(size: 13, color: kMainSub),
          ),
          const SizedBox(height: 18),
          ..._games.map(
            (game) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MainCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: connected ? () => _open(context, game) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: game.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(game.icon, color: game.color),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(game.title, style: mainTitle(size: 20)),
                              const SizedBox(height: 3),
                              Text(
                                game.description,
                                style: mainBody(size: 12, color: kMainSub),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
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
