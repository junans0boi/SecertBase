import 'package:flutter/material.dart';

import '../tokens.dart';

/// 넓은 화면(웹 데스크톱·태블릿)에서 앱을 가운데 한 줄로 모아 준다.
///
/// 화면이 [maxWidth]보다 좁으면 아무것도 바꾸지 않는다. `MaterialApp.builder`
/// 에서 한 번만 감싸면 모든 화면·시트·스낵바가 같은 폭을 쓴다.
class V2AppFrame extends StatelessWidget {
  const V2AppFrame({super.key, required this.child, this.maxWidth = 560});

  final Widget? child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) return content;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF0E0B12) : const Color(0xFFF3E8EC),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(
                  color: V2Colors.ink.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: ClipRect(child: content),
          ),
        ),
      ),
    );
  }
}
