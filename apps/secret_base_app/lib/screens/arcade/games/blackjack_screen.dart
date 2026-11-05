import 'package:flutter/material.dart';

import 'blackjack/blackjack_game_screen.dart';

/// 블랙잭 진입점(아케이드·푸시 경로가 쓰는 이름 유지). 실제 화면은 `blackjack/` 폴더.
class BlackjackScreen extends StatelessWidget {
  const BlackjackScreen({super.key});

  @override
  Widget build(BuildContext context) => const BlackjackGameScreen();
}
