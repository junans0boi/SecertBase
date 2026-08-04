import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'yut_audio_stub.dart'
    if (dart.library.html) 'yut_audio_web.dart'
    as impl;

class YutAudio {
  YutAudio._();
  static final YutAudio instance = YutAudio._();

  final _backend = impl.YutAudioBackend();
  final _random = Random();

  static const _effectsEnabledKey = 'yut_audio_effects_enabled';
  static const _backgroundMusicEnabledKey = 'yut_audio_background_enabled';

  bool _effectsEnabled = true;
  bool _backgroundMusicEnabled = true;
  String? _requestedBackground;

  bool get effectsEnabled => _effectsEnabled;
  bool get backgroundMusicEnabled => _backgroundMusicEnabled;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _effectsEnabled = prefs.getBool(_effectsEnabledKey) ?? true;
    _backgroundMusicEnabled = prefs.getBool(_backgroundMusicEnabledKey) ?? true;
  }

  Future<void> setEffectsEnabled(bool value) async {
    _effectsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_effectsEnabledKey, value);
  }

  Future<void> setBackgroundMusicEnabled(bool value) async {
    _backgroundMusicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundMusicEnabledKey, value);
    if (!value) {
      await _backend.stopBackground();
    } else if (_requestedBackground != null) {
      await _backend.playBackground(_requestedBackground!);
    }
  }

  Future<void> playCharacterSelect(String character) =>
      _play('${character}01.mp3');

  Future<void> playGameStart({required String? bgm}) async {
    if (bgm != null) {
      await playBackground(bgm);
    }
  }

  Future<void> playBackground(String file) async {
    _requestedBackground = file;
    if (!_backgroundMusicEnabled) return;
    await _backend.playBackground(file);
  }

  Future<void> stopBackground() {
    _requestedBackground = null;
    return _backend.stopBackground();
  }

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
    if (!_effectsEnabled) return;
    await _backend.play(file);
  }
}
