import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_models.dart';

/// 캐릭터 얼굴(원 안에 머리만 잘라 보여 준다).
class YutCharacterFace extends StatelessWidget {
  final String character;
  final double size;

  const YutCharacterFace({
    super.key,
    required this.character,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxWidth: size * 1.85,
          maxHeight: size * 2.4,
          child: Transform.translate(
            offset: Offset(size * 0.01, size * 0.03),
            child: Image.asset(
              yutCharacterAsset(character),
              width: size * 1.85,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Obangsaek.white,
                child: Center(
                  child: Text(
                    (yutCharacterNames[character] ?? '말').characters.first,
                    style: GoogleFonts.gowunBatang(
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.w800,
                      color: Obangsaek.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 윷말: 옻칠한 둥근 말판 + 플레이어 색 테두리 + (캐릭터 얼굴 | 상점 말 스킨).
/// [count]가 2 이상이면 업힌 말 수 배지를 단다.
class YutToken extends StatelessWidget {
  final double size;
  final Color color;
  final String character;
  final String? skinEmoji;
  final int count;
  final bool selected;
  final bool glow;
  final bool dimmed;

  const YutToken({
    super.key,
    required this.size,
    required this.color,
    required this.character,
    this.skinEmoji,
    this.count = 1,
    this.selected = false,
    this.glow = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final ring = size * 0.09;
    final face = size - ring * 2 - 2;
    final emoji = skinEmoji;
    final token = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.3)!, color],
        ),
        border: Border.all(
          color: selected ? Obangsaek.yellow : Obangsaek.black,
          width: selected ? 2.6 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 5,
            offset: const Offset(1.5, 3),
          ),
          if (glow || selected)
            BoxShadow(
              color: Obangsaek.yellow.withValues(alpha: 0.85),
              blurRadius: 14,
              spreadRadius: 1.5,
            ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Obangsaek.white,
        ),
        alignment: Alignment.center,
        child: emoji != null && emoji.isNotEmpty
            ? Text(emoji, style: TextStyle(fontSize: face * 0.62))
            : YutCharacterFace(character: character, size: face),
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            token,
            if (count > 1)
              Positioned(
                right: -size * 0.12,
                top: -size * 0.12,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: size * 0.42,
                    minHeight: size * 0.42,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Obangsaek.black,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Obangsaek.white, width: 1.2),
                  ),
                  child: Text(
                    '×$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
