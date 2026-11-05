import 'package:shared_preferences/shared_preferences.dart';

import 'game_sfx_stub.dart' if (dart.library.html) 'game_sfx_web.dart';
import 'game_sounds.dart';
import 'synth.dart';

export 'game_sounds.dart' show GameSound;

/// 게임 2.0 공용 효과음 재생기. 웹에서만 소리를 내고, 그 밖의 환경(테스트 등)에서는
/// 아무것도 하지 않는다. 음소거 설정은 기기에 저장되고 모든 게임이 같이 쓴다.
class GameSfx {
  GameSfx._();
  static final GameSfx instance = GameSfx._();

  static const _prefKey = 'game_sfx_muted';
  static const double masterVolume = 0.6;

  final GameSfxBackend _backend = GameSfxBackend();
  final Map<GameSound, String> _cache = {};
  final Map<GameSound, int> _lastPlayedMs = {};
  bool muted = false;
  bool _prefsLoaded = false;

  bool get supported => _backend.supported;

  /// 저장된 음소거 설정을 읽고, [sounds]를 미리 만들어 둔다(첫 재생 끊김 방지).
  Future<void> init(Iterable<GameSound> sounds) async {
    if (!_prefsLoaded) {
      _prefsLoaded = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        muted = prefs.getBool(_prefKey) ?? false;
      } catch (_) {
        // 설정을 못 읽어도 소리는 낸다.
      }
    }
    if (!_backend.supported) return;
    for (final sound in sounds) {
      if (_cache.containsKey(sound)) continue;
      // 한 프레임씩 나눠 만들어 화면이 멈추지 않게 한다.
      await Future<void>.delayed(const Duration(milliseconds: 16));
      _handle(sound);
    }
  }

  String _handle(GameSound sound) => _cache.putIfAbsent(
    sound,
    () => _backend.prepare(Synth.wav(GameSoundRecipes.render(sound))),
  );

  /// 같은 소리가 [minGapMs] 안에 겹치면 건너뛴다(연타·중복 이벤트로 소리가 뭉개지지 않게).
  void play(GameSound sound, {double volume = 1, int minGapMs = 40}) {
    if (muted || !_backend.supported) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastPlayedMs[sound] ?? 0;
    if (now - last < minGapMs) return;
    _lastPlayedMs[sound] = now;
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
