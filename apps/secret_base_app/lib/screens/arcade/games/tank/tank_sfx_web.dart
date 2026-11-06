// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

/// 웹: 합성한 WAV를 data URI로 만들어 오디오 요소로 재생한다.
class TankSfxBackend {
  bool get supported => true;

  String prepare(Uint8List wav) => 'data:audio/wav;base64,${base64Encode(wav)}';

  void play(String handle, double volume) {
    _play(handle, volume);
  }

  Future<void> _play(String handle, double volume) async {
    try {
      final audio = html.AudioElement(handle)..volume = volume;
      await audio.play();
    } catch (_) {
      // 브라우저 자동재생 제한 등은 무시한다.
    }
  }
}
