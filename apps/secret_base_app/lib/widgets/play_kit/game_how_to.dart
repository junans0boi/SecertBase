import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_buttons.dart';
import 'game_theme.dart';

/// 규칙 요약 한 화면. [showHowToOnce]는 처음 한 번만 띄운다(기기에 저장).
Future<void> showGameHowTo(
  BuildContext context, {
  required GameTheme theme,
  required String title,
  required List<String> lines,
  String emoji = '💡',
}) {
  final t = theme;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: GamePanel(
        theme: t,
        radius: 26,
        opaque: true,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.display(size: 24),
            ),
            const SizedBox(height: 14),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: t.gold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: t.body(size: 14.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            GamePrimaryButton(
              theme: t,
              label: '알겠어요',
              height: 50,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

final Set<String> _howToRequested = {};

/// 테스트용: 이번 실행에서 띄운 기록을 지운다.
@visibleForTesting
void resetHowToRequests() => _howToRequested.clear();

Future<void> showHowToOnce(
  BuildContext context, {
  required String prefKey,
  required GameTheme theme,
  required String title,
  required List<String> lines,
  String emoji = '💡',
}) async {
  // 같은 화면에서 거의 동시에 두 번 불려도 한 번만 띄운다(저장 확인은 비동기라 경합이 생긴다).
  if (!_howToRequested.add(prefKey)) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefKey) == true) return;
    await prefs.setBool(prefKey, true);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  await showGameHowTo(
    context,
    theme: theme,
    title: title,
    lines: lines,
    emoji: emoji,
  );
}
