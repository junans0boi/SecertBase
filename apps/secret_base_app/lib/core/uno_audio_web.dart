// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class UnoAudioBackend {
  static String _url(String file) => 'assets/assets/sounds/uno/$file';

  Future<void> play(String file) async {
    try {
      final audio = html.AudioElement(_url(file));
      await audio.play();
    } catch (_) {}
  }
}
