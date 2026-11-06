import 'package:flutter/material.dart';

import 'telepathy/telepathy_game_screen.dart';

/// 텔레파시 진입점(아케이드·푸시 경로가 이 이름을 쓴다). 화면은 `telepathy/` 폴더에 있다.
class TelepathyScreen extends StatelessWidget {
  const TelepathyScreen({super.key});

  @override
  Widget build(BuildContext context) => const TelepathyGameScreen();
}
