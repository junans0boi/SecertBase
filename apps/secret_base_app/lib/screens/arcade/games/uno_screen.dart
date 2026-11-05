import 'package:flutter/material.dart';

import 'onecard/onecard_screen.dart';

/// 원카드 진입점(내부 식별자 uno). 화면은 `onecard/`의 2.0 화면을 그대로 쓴다.
class UnoScreen extends StatelessWidget {
  const UnoScreen({super.key});

  @override
  Widget build(BuildContext context) => const OneCardScreen();
}
