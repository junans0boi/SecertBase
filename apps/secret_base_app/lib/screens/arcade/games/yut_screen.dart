import 'package:flutter/material.dart';

import 'yut/yut_game_screen.dart';

/// 윷놀이 진입점. 화면은 `yut/`의 2.0 화면(한지 마당)을 그대로 쓴다.
class YutScreen extends StatelessWidget {
  const YutScreen({super.key});

  @override
  Widget build(BuildContext context) => const YutGameScreen();
}
