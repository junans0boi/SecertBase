// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class YutAudioBackend {
  html.AudioElement? _background;

  static String _url(String file) => 'assets/assets/sounds/yut/$file';

  Future<void> play(String file) async {
    try {
      final audio = html.AudioElement(_url(file));
      await audio.play();
    } catch (_) {}
  }

  Future<void> playBackground(String file) async {
    try {
      await stopBackground();
      final audio = html.AudioElement(_url(file))
        ..loop = true
        ..volume = 0.42;
      _background = audio;
      await audio.play();
    } catch (_) {}
  }

  Future<void> stopBackground() async {
    try {
      _background?.pause();
      _background?.remove();
    } catch (_) {
      // Ignore browser autoplay/teardown edge cases.
    } finally {
      _background = null;
    }
  }
}
