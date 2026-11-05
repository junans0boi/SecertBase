import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A dialog is pushed on the root navigator, but screens inside the home tabs
/// live in a nested navigator. If a dialog's buttons call
/// `Navigator.pop(context)` with the *screen's* context instead of the
/// dialog's own, the screen underneath is popped and the dialog stays open:
/// logout left its dialog over the login screen, and the partner-disconnect,
/// account-deletion and anniversary-delete confirmations never completed.
///
/// Game screens are excluded; they are tracked separately.
void main() {
  test('dialogs close themselves with their own builder context', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('arcade') && !f.path.contains('game'));

    final opener = RegExp(r'show(?:Dialog|ModalBottomSheet)(?:<[^>]*>)?\(');
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in opener.allMatches(source)) {
        var depth = 1;
        var i = match.end;
        while (depth > 0 && i < source.length) {
          final c = source[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        final block = source.substring(match.start, i);
        final discardsOwnContext = RegExp(
          r'builder:\s*\(_\)\s*=>',
        ).hasMatch(block);
        final popsOuterContext = RegExp(
          r'Navigator\.pop\(\s*context\b',
        ).hasMatch(block);
        if (discardsOwnContext && popsOuterContext) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          offenders.add('${file.path}:${line + 1}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
