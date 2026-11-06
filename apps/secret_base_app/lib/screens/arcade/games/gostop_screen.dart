import 'package:flutter/material.dart';

import 'gostop/gostop_game_screen.dart';

/// 고스톱 진입점. 화면은 `gostop/`의 2.0 화면(초록 펠트 판)을 그대로 쓴다.
/// 아케이드는 이 위젯을 GameSessionPresence로 감싼다.
class GostopScreen extends StatelessWidget {
  const GostopScreen({super.key});

  @override
  Widget build(BuildContext context) => const GostopGameScreen();
}
