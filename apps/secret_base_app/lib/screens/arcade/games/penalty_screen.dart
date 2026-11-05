import 'package:flutter/material.dart';

import 'penalty/penalty_game_screen.dart';

/// 패널티킥 진입점(이름 유지). 화면 본체는 `penalty/` 폴더의 게임 2.0 화면.
class PenaltyScreen extends StatelessWidget {
  const PenaltyScreen({super.key});

  @override
  Widget build(BuildContext context) => const PenaltyGameScreen();
}
