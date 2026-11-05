import 'package:shared_preferences/shared_preferences.dart';

import 'tank_sfx_stub.dart' if (dart.library.html) 'tank_sfx_web.dart';
import 'tank_synth.dart';

export 'tank_synth.dart' show TankSound;

/// 탱크 대작전 효과음 재생기. 웹에서만 소리를 내고, 그 밖의 환경(테스트 등)에서는
/// 아무것도 하지 않는다. 음소거 설정은 기기에 저장한다.
class TankSfx {
  TankSfx._();
  static final TankSfx instance = TankSfx._();

  static const _prefKey = 'tank_sfx_muted';
  static const double masterVolume = 0.7;

  final TankSfxBackend _backend = TankSfxBackend();
  final Map<TankSound, String> _cache = {};
  bool muted = false;
  bool _initialized = false;

  bool get supported => _backend.supported;

  /// 저장된 음소거 설정을 읽고, 소리를 미리 만들어 둔다(첫 재생 끊김 방지).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      muted = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      // 설정을 못 읽어도 소리는 낸다.
    }
    if (_backend.supported) await _prewarm();
  }

  Future<void> _prewarm() async {
    for (final sound in TankSound.values) {
      if (_cache.containsKey(sound)) continue;
      // 한 프레임씩 나눠 만들어 화면이 멈추지 않게 한다.
      await Future<void>.delayed(const Duration(milliseconds: 16));
      _handle(sound);
    }
  }

  String _handle(TankSound sound) => _cache.putIfAbsent(
    sound,
    () => _backend.prepare(TankSynth.wav(TankSynth.render(sound))),
  );

  void play(TankSound sound, {double volume = 1}) {
    if (muted || !_backend.supported) return;
    _backend.play(_handle(sound), (volume * masterVolume).clamp(0.0, 1.0));
  }

  Future<void> setMuted(bool value) async {
    muted = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {
      // 저장 실패는 무시(이번 세션에는 반영됨).
    }
  }
}
