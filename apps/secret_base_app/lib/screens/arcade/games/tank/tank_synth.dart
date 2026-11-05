import 'dart:math' as math;
import 'dart:typed_data';

/// 탱크 대작전 효과음. 오디오 파일 없이 코드로 파형을 합성한다(저작권 걱정 없음).
enum TankSound {
  fireLight,
  fire,
  fireHeavy,
  whistle,
  explosionSmall,
  explosion,
  explosionBig,
  drill,
  clang,
  thud,
  mound,
  teleport,
  pickup,
  heal,
  shield,
  turnMine,
  turnOpp,
  tick,
  warn,
  win,
  lose,
  click,
  engine,
}

enum _Wave { sine, triangle, squareSoft, saw }

/// 순수 Dart 합성기: 플랫폼과 무관하게 같은 결과를 낸다(테스트 가능).
class TankSynth {
  TankSynth._();

  static const int sampleRate = 22050;

  /// [sound]의 PCM 샘플(-1..1).
  static Float64List render(TankSound sound) {
    return switch (sound) {
      TankSound.fire => _fire(),
      TankSound.fireHeavy => _fireHeavy(),
      TankSound.fireLight => _fireLight(),
      TankSound.whistle => _whistle(),
      TankSound.explosionSmall => _explosionSmall(),
      TankSound.explosion => _explosion(),
      TankSound.explosionBig => _explosionBig(),
      TankSound.drill => _drill(),
      TankSound.clang => _clang(),
      TankSound.thud => _thud(),
      TankSound.mound => _mound(),
      TankSound.teleport => _teleport(),
      TankSound.pickup => _pickup(),
      TankSound.heal => _heal(),
      TankSound.shield => _shield(),
      TankSound.turnMine => _turnMine(),
      TankSound.turnOpp => _turnOpp(),
      TankSound.tick => _tick(),
      TankSound.warn => _warn(),
      TankSound.win => _win(),
      TankSound.lose => _lose(),
      TankSound.click => _click(),
      TankSound.engine => _engine(),
    };
  }

  /// 16비트 모노 PCM WAV 바이트.
  static Uint8List wav(Float64List samples) {
    final dataLen = samples.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        b.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }

  // ── 레시피 ────────────────────────────────────────────────────────────────

  static Float64List _fire() {
    final o = _buf(0.45);
    _tone(o, f0: 120, f1: 40, attack: 0.002, decay: 0.12, gain: 0.9);
    _noise(o, seed: 1, fc0: 3000, fc1: 400, attack: 0.001, decay: 0.05);
    return _finish(o, 0.8);
  }

  static Float64List _fireHeavy() {
    final o = _buf(0.65);
    _tone(o, f0: 95, f1: 32, attack: 0.002, decay: 0.2, gain: 1);
    _noise(o, seed: 2, fc0: 2200, fc1: 250, attack: 0.001, decay: 0.09);
    return _finish(o, 0.9);
  }

  static Float64List _fireLight() {
    final o = _buf(0.3);
    _tone(o, f0: 200, f1: 80, attack: 0.001, decay: 0.06, gain: 0.7);
    _noise(o, seed: 3, fc0: 5000, fc1: 1500, attack: 0.001, decay: 0.03);
    return _finish(o, 0.7);
  }

  static Float64List _whistle() {
    final o = _buf(1.2);
    _tone(
      o,
      f0: 1500,
      f1: 520,
      attack: 0.2,
      decay: 0.6,
      gain: 0.3,
      vibratoHz: 7,
      vibratoDepth: 0.012,
    );
    return _finish(o, 0.3);
  }

  static Float64List _explosionSmall() {
    final o = _buf(0.5);
    _noise(o, seed: 4, fc0: 1800, fc1: 200, attack: 0.002, decay: 0.1);
    _tone(o, f0: 90, f1: 40, attack: 0.002, decay: 0.08, gain: 0.6);
    return _finish(o, 0.7);
  }

  static Float64List _explosion() {
    final o = _buf(1.3);
    _noise(o, seed: 5, fc0: 1400, fc1: 120, attack: 0.004, decay: 0.28);
    _tone(o, f0: 70, f1: 28, attack: 0.003, decay: 0.25, gain: 0.8);
    return _finish(o, 0.9);
  }

  static Float64List _explosionBig() {
    final o = _buf(2.0);
    _noise(o, seed: 6, fc0: 1000, fc1: 80, attack: 0.006, decay: 0.5);
    _tone(o, f0: 55, f1: 22, attack: 0.004, decay: 0.45, gain: 1);
    _noise(
      o,
      seed: 7,
      fc0: 300,
      fc1: 60,
      attack: 0.05,
      decay: 0.6,
      gain: 0.6,
      start: 0.15,
    );
    return _finish(o, 1.0);
  }

  static Float64List _drill() {
    final o = _buf(0.7);
    _tone(
      o,
      f0: 180,
      f1: 260,
      attack: 0.01,
      decay: 0.5,
      gain: 0.35,
      wave: _Wave.saw,
      expSweep: false,
      vibratoHz: 30,
      vibratoDepth: 0.08,
    );
    _noise(
      o,
      seed: 8,
      fc0: 4000,
      fc1: 2000,
      attack: 0.01,
      decay: 0.3,
      gain: 0.25,
    );
    return _finish(o, 0.6);
  }

  static Float64List _clang() {
    final o = _buf(0.7);
    const partials = [523.0, 1187.0, 1840.0, 2731.0];
    const decays = [0.3, 0.2, 0.12, 0.08];
    const gains = [0.5, 0.35, 0.25, 0.2];
    for (int i = 0; i < partials.length; i++) {
      _tone(
        o,
        f0: partials[i],
        f1: partials[i],
        attack: 0.001,
        decay: decays[i],
        gain: gains[i],
      );
    }
    _noise(o, seed: 9, fc0: 6000, fc1: 6000, attack: 0, decay: 0.01, gain: 0.4);
    return _finish(o, 0.7);
  }

  static Float64List _thud() {
    final o = _buf(0.35);
    _tone(o, f0: 80, f1: 40, attack: 0.002, decay: 0.08, gain: 1);
    _noise(o, seed: 10, fc0: 600, fc1: 150, attack: 0.002, decay: 0.05, gain: 0.5);
    return _finish(o, 0.65);
  }

  static Float64List _mound() {
    final o = _buf(0.5);
    _noise(o, seed: 11, fc0: 900, fc1: 200, attack: 0.01, decay: 0.15, gain: 0.9);
    _tone(o, f0: 70, f1: 45, attack: 0.005, decay: 0.1, gain: 0.6);
    return _finish(o, 0.6);
  }

  static Float64List _teleport() {
    final o = _buf(0.8);
    _tone(
      o,
      f0: 300,
      f1: 1800,
      attack: 0.05,
      decay: 0.5,
      gain: 0.5,
      vibratoHz: 18,
      vibratoDepth: 0.05,
    );
    _tone(
      o,
      f0: 600,
      f1: 3600,
      attack: 0.05,
      decay: 0.5,
      gain: 0.2,
      vibratoHz: 18,
      vibratoDepth: 0.05,
    );
    return _finish(o, 0.55);
  }

  static Float64List _pickup() {
    final o = _buf(0.45);
    _note(o, 1047, 0, 0.1, _Wave.triangle);
    _note(o, 1319, 0.08, 0.1, _Wave.triangle);
    _note(o, 1568, 0.16, 0.25, _Wave.triangle);
    return _finish(o, 0.55);
  }

  static Float64List _heal() {
    final o = _buf(0.5);
    _note(o, 660, 0, 0.2, _Wave.sine);
    _note(o, 990, 0.12, 0.35, _Wave.sine);
    return _finish(o, 0.5);
  }

  static Float64List _shield() {
    final o = _buf(0.5);
    _tone(
      o,
      f0: 1200,
      f1: 1400,
      attack: 0.005,
      decay: 0.18,
      gain: 0.6,
      vibratoHz: 14,
      vibratoDepth: 0.03,
    );
    return _finish(o, 0.5);
  }

  static Float64List _turnMine() {
    final o = _buf(0.45);
    _note(o, 660, 0, 0.15, _Wave.triangle);
    _note(o, 880, 0.12, 0.3, _Wave.triangle);
    return _finish(o, 0.55);
  }

  static Float64List _turnOpp() {
    final o = _buf(0.4);
    _note(o, 440, 0, 0.15, _Wave.triangle);
    _note(o, 330, 0.12, 0.25, _Wave.triangle);
    return _finish(o, 0.4);
  }

  static Float64List _tick() {
    final o = _buf(0.06);
    _tone(o, f0: 1100, f1: 1100, attack: 0.001, decay: 0.015, gain: 0.6);
    return _finish(o, 0.35);
  }

  static Float64List _warn() {
    final o = _buf(0.14);
    _tone(
      o,
      f0: 880,
      f1: 880,
      attack: 0.002,
      decay: 0.05,
      gain: 0.6,
      wave: _Wave.squareSoft,
    );
    return _finish(o, 0.45);
  }

  static Float64List _win() {
    final o = _buf(1.6);
    _note(o, 523, 0, 0.2, _Wave.triangle);
    _note(o, 659, 0.12, 0.2, _Wave.triangle);
    _note(o, 784, 0.24, 0.2, _Wave.triangle);
    _note(o, 1047, 0.36, 1.2, _Wave.triangle, decay: 0.5);
    _note(o, 784, 0.36, 1.2, _Wave.triangle, decay: 0.5, gain: 0.35);
    _note(o, 659, 0.36, 1.2, _Wave.triangle, decay: 0.5, gain: 0.3);
    return _finish(o, 0.6);
  }

  static Float64List _lose() {
    final o = _buf(1.4);
    _note(o, 392, 0, 0.3, _Wave.sine);
    _note(o, 330, 0.3, 0.3, _Wave.sine);
    _note(o, 262, 0.6, 0.8, _Wave.sine, decay: 0.4);
    return _finish(o, 0.5);
  }

  static Float64List _click() {
    final o = _buf(0.05);
    _tone(o, f0: 1600, f1: 900, attack: 0.001, decay: 0.01, gain: 0.5);
    return _finish(o, 0.3);
  }

  static Float64List _engine() {
    final o = _buf(0.35);
    _tone(
      o,
      f0: 55,
      f1: 70,
      attack: 0.03,
      decay: 0.25,
      gain: 0.5,
      wave: _Wave.saw,
      expSweep: false,
    );
    _noise(o, seed: 12, fc0: 500, fc1: 500, attack: 0.02, decay: 0.15, gain: 0.3);
    return _finish(o, 0.45);
  }

  // ── 빌딩 블록 ─────────────────────────────────────────────────────────────

  static Float64List _buf(double seconds) =>
      Float64List((seconds * sampleRate).round());

  static double _env(double t, double attack, double decay) {
    if (t < attack) return attack <= 0 ? 1 : t / attack;
    return math.exp(-(t - attack) / decay);
  }

  static double _wave(_Wave wave, double phase) => switch (wave) {
    _Wave.sine => math.sin(phase),
    _Wave.triangle => (2 / math.pi) * math.asin(math.sin(phase)),
    _Wave.squareSoft =>
      (math.sin(phase) + math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5) *
          0.8,
    _Wave.saw =>
      2 *
          (phase / (2 * math.pi) -
              (phase / (2 * math.pi) + 0.5).floorToDouble()),
  };

  /// 저역 통과 필터를 거친 잡음(차단 주파수가 fc0→fc1로 이동).
  static void _noise(
    Float64List out, {
    required int seed,
    required double fc0,
    required double fc1,
    required double attack,
    required double decay,
    double gain = 1,
    double start = 0,
  }) {
    final rnd = math.Random(seed);
    final s0 = (start * sampleRate).round();
    final total = (out.length - s0) / sampleRate;
    double y = 0;
    for (int i = s0; i < out.length; i++) {
      final t = (i - s0) / sampleRate;
      final fc = fc0 + (fc1 - fc0) * (total <= 0 ? 0 : t / total);
      final a = 1 - math.exp(-2 * math.pi * fc / sampleRate);
      y += a * ((rnd.nextDouble() * 2 - 1) - y);
      out[i] += y * _env(t, attack, decay) * gain;
    }
  }

  /// 주파수가 f0→f1로 바뀌는 음.
  static void _tone(
    Float64List out, {
    required double f0,
    required double f1,
    required double attack,
    required double decay,
    required double gain,
    double start = 0,
    double? length,
    _Wave wave = _Wave.sine,
    bool expSweep = true,
    double vibratoHz = 0,
    double vibratoDepth = 0,
  }) {
    final s0 = (start * sampleRate).round();
    if (s0 >= out.length) return;
    final s1 = length == null
        ? out.length
        : math.min(out.length, s0 + (length * sampleRate).round());
    final dur = (s1 - s0) / sampleRate;
    double phase = 0;
    for (int i = s0; i < s1; i++) {
      final t = (i - s0) / sampleRate;
      final k = dur <= 0 ? 0.0 : t / dur;
      double f = expSweep
          ? f0 * math.pow(f1 / f0, k).toDouble()
          : f0 + (f1 - f0) * k;
      if (vibratoHz > 0) {
        f *= 1 + vibratoDepth * math.sin(2 * math.pi * vibratoHz * t);
      }
      phase += 2 * math.pi * f / sampleRate;
      out[i] += _wave(wave, phase) * _env(t, attack, decay) * gain;
    }
  }

  static void _note(
    Float64List out,
    double freq,
    double start,
    double length,
    _Wave wave, {
    double decay = 0.15,
    double gain = 0.6,
  }) {
    _tone(
      out,
      f0: freq,
      f1: freq,
      attack: 0.004,
      decay: decay,
      gain: gain,
      start: start,
      length: length,
      wave: wave,
    );
  }

  /// 최대 진폭을 [peak]로 맞추고 끝을 짧게 페이드아웃(딸깍 소리 방지).
  static Float64List _finish(Float64List out, double peak) {
    double maxAbs = 0;
    for (final v in out) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    final scale = maxAbs <= 0 ? 0.0 : peak / maxAbs;
    final fade = math.min(out.length, (0.006 * sampleRate).round());
    for (int i = 0; i < out.length; i++) {
      var v = out[i] * scale;
      final fromEnd = out.length - 1 - i;
      if (fromEnd < fade) v *= fromEnd / fade;
      out[i] = v;
    }
    return out;
  }
}
