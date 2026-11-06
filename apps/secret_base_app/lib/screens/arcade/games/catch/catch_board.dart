/// 아틀리에 스케치북: 파란 테두리 + 크림 종이 + 스프링 철. 종이는 항상 4:3.
library;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'catch_models.dart';
import 'catch_paint.dart';

/// 파란 테두리 바깥 여백(위는 스프링 자리).
const double kBoardSide = 8;
const double kBoardTop = 16;
const double kBoardBottom = 8;

/// 종이 너비 [paperWidth]에 맞는 스케치북 전체 크기.
Size sketchbookSizeFor(double paperWidth) => Size(
  paperWidth + kBoardSide * 2,
  paperWidth / kCatchBoardAspect + kBoardTop + kBoardBottom,
);

/// 한 화면에서 [maxWidth]×[maxHeight] 안에 들어가는 가장 큰 종이 너비.
/// 키보드 높이와 무관하게 부모가 주는 크기만 보고 정한다.
double paperWidthFor(double maxWidth, double maxHeight) {
  final byWidth = maxWidth - kBoardSide * 2;
  final byHeight = (maxHeight - kBoardTop - kBoardBottom) * kCatchBoardAspect;
  final w = byWidth < byHeight ? byWidth : byHeight;
  return w < 120 ? 120 : w;
}

class SketchbookBoard extends StatelessWidget {
  final GameTheme theme;
  final double paperWidth;
  final CatchCanvasModel model;

  /// 종이 위(획 위)에 올릴 것: 그리는 손, 말풍선, 정답 연출 등. 종이 크기로 꽉 채워진다.
  final List<Widget> overlays;

  const SketchbookBoard({
    super.key,
    required this.theme,
    required this.paperWidth,
    required this.model,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final size = sketchbookSizeFor(paperWidth);
    return SizedBox(
      key: const ValueKey('catch-sketchbook'),
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(t.accent, Colors.white, 0.22)!,
                    t.accent,
                    Color.lerp(t.accent, Colors.black, 0.18)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // 테두리 안쪽의 얇은 흰 선.
          Positioned(
            left: 3,
            top: 3,
            right: 3,
            bottom: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: kBoardSide,
            top: kBoardTop,
            width: paperWidth,
            height: paperWidth / kCatchBoardAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const RepaintBoundary(
                    child: CustomPaint(painter: SketchPaperPainter()),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey('catch-strokes'),
                      painter: CatchStrokesPainter(model),
                      isComplex: true,
                      willChange: true,
                    ),
                  ),
                  ...overlays,
                ],
              ),
            ),
          ),
          // 스프링 철: 윗변에 걸쳐 종이와 테두리를 묶는다.
          Positioned(
            left: kBoardSide + 6,
            top: 0,
            width: paperWidth - 12,
            height: 30,
            child: const IgnorePointer(
              child: CustomPaint(painter: SpiralBindingPainter()),
            ),
          ),
        ],
      ),
    );
  }
}
