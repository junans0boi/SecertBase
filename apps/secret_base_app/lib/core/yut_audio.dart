import 'dart:math';

import 'yut_audio_stub.dart'
    if (dart.library.html) 'yut_audio_web.dart' as impl;

class YutAudio {
  YutAudio._();
  static final YutAudio instance = YutAudio._();

  final _backend = impl.YutAudioBackend();
  final _random = Random();

  bool _enabled = true;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) stopBackground();
  }

  Future<void> playCharacterSelect(String character) =>
      _play('${character}01.mp3');

  Future<void> playGameStart({
    required String? bgm,
    required List<String> characters,
  }) async {
    if (bgm != null) {
      await playBackground(bgm);
    }
    for (final character in characters) {
      await _play('${character}01.mp3');
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }
  }

  Future<void> playBackground(String file) async {
    if (!_enabled) return;
    await _backend.playBackground(file);
  }

  Future<void> stopBackground() => _backend.stopBackground();

  Future<void> playThrow() => _play('yutthrow.mp3');

  Future<void> playThrowResult(
    String character,
    String resultName, {
    int? seed,
  }) {
    final code = switch (resultName) {
      '도' => '09',
      '개' => '10',
      '걸' => '11',
      '백도' => '03',
      '윷' => _pickVariant(['02', '12'], seed),
      '모' => _pickVariant(['02', '13'], seed),
      _ => null,
    };
    if (code == null) return Future.value();
    return _play('$character$code.mp3');
  }

  Future<void> playCaptured(String character) => _play('${character}04.mp3');
  Future<void> playGotCaptured(String character) => _play('${character}05.mp3');
  Future<void> playStacked(String character) => _play('${character}06.mp3');
  Future<void> playVictory(String character) => _play('${character}07.mp3');
  Future<void> playDefeat(String character) => _play('${character}08.mp3');

  String _pickVariant(List<String> values, int? seed) {
    if (seed == null) return values[_random.nextInt(values.length)];
    return values[seed.abs() % values.length];
  }

  Future<void> _play(String file) async {
    if (!_enabled) return;
    await _backend.play(file);
  }
}
