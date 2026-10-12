import 'package:flutter/material.dart';
import '../main_design.dart';
import '../../screens/arcade/game_lobby_screen.dart';
import '../../screens/arcade/games/blackjack_screen.dart';
import '../../screens/arcade/games/oldmaid_screen.dart';
import '../../screens/arcade/games/yut_screen.dart';
import '../../screens/arcade/games/marble_screen.dart';
import '../../screens/arcade/games/bomb_screen.dart';
import '../../screens/arcade/games/uno_screen.dart';
import '../../screens/arcade/games/rps_screen.dart';
import '../../screens/arcade/games/dice_screen.dart';
import '../../screens/arcade/games/roulette_screen.dart';
import '../../screens/arcade/games/telepathy_screen.dart';
import '../../screens/arcade/games/pirate_screen.dart';
import '../../screens/arcade/games/penalty_screen.dart';
import '../../screens/arcade/games/bowling_screen.dart';
import '../../screens/arcade/games/catch_screen.dart';
import '../../screens/arcade/games/tank_screen.dart';
import '../../screens/arcade/games/gostop_screen.dart';
import '../../widgets/game_session_presence.dart';

/// Uses the same game context and presence contract as the Play entry point.
GameLobbyScreen? pushGameLobby(String? type) {
  final entry = switch (type) {
    'blackjack' => ('블랙잭', const BlackjackScreen()),
    'oldmaid' => ('도둑잡기', const OldMaidScreen()),
    'yut' => ('윷놀이', const YutScreen()),
    'marble' => ('마블 작전', const MarbleScreen()),
    'bomb' => ('폭탄 돌리기', const BombScreen()),
    'uno' => ('원카드', const UnoScreen()),
    'rps' => ('가위바위보', const RpsScreen()),
    'zero' => ('제로', const RpsScreen(fixedMode: 'hanabagi')),
    'dice' => ('주사위', const DiceScreen()),
    'roulette' => ('룰렛', const RouletteScreen()),
    'telepathy' => ('텔레파시', const TelepathyScreen()),
    'pirate' => ('해적 룰렛', const PirateScreen()),
    'penalty' => ('패널티킥', const PenaltyScreen()),
    'bowling' => ('볼링', const BowlingScreen()),
    'catch' => ('그림 맞히기', const CatchScreen()),
    'tank' => ('탱크 대작전', const TankScreen()),
    'gostop' => ('고스톱 (맞고)', const GostopScreen()),
    _ => null,
  };
  if (entry == null) return null;
  Widget screen = entry.$2;
  if (const ['yut', 'marble', 'uno', 'gostop'].contains(type)) {
    screen = GameSessionPresence(gameType: type!, child: screen);
  }
  return GameLobbyScreen(
    gameType: type!,
    title: entry.$1,
    description: '상대방이 초대한 게임에 함께 참여해요.',
    emoji: '',
    color: kMainRose,
    backgroundColor: kMainRoseSoft,
    gameScreen: screen,
  );
}
