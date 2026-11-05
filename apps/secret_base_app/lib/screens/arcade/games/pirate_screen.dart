import 'package:flutter/material.dart';

import 'pirate/pirate_game_screen.dart';

/// 해적 룰렛 진입점(아케이드·푸시 경로가 이 이름을 쓴다). 화면은 `pirate/` 폴더에 있다.
class PirateScreen extends StatelessWidget {
  const PirateScreen({super.key});

  @override
  Widget build(BuildContext context) => const PirateGameScreen();
}
