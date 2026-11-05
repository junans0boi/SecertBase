import 'dart:math' as math;
import 'dart:typed_data';

/// 파형 종류.
enum Wave { sine, triangle, squareSoft, saw }

/// 순수 Dart 합성기 빌딩 블록(게임 2.0 공용). 오디오 파일 없이 코드로 소리를 만든다.
/// 플랫폼과 무관하게 같은 결과를 내므로 테스트에서 파형을 검증할 수 있다.
/// 탱크 대작전의 합성기(TankSynth)와 같은 방식이다.
class Synth {
  Synth._();

  static const int sampleRate = 22050;

  static Float64List buffer(double seconds) =>
      Float64List((seconds * sampleRate).round());

  static double env(double t, double attack, double decay) {
    if (t < attack) return attack <= 0 ? 1 : t / attack;
    return math.exp(-(t - attack) / decay);
  }

  static double wave(Wave w, double phase) => switch (w) {
    Wave.sine => math.sin(phase),
    Wave.triangle => (2 / math.pi) * math.asin(math.sin(phase)),
    Wave.squareSoft =>
      (math.sin(phase) + math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5) *
          0.8,
    Wave.saw =>
      2 *
          (phase / (2 * math.pi) -
              (phase / (2 * math.pi) + 0.5).floorToDouble()),
  };

  /// 저역 통과 필터를 거친 잡음(차단 주파수가 fc0→fc1로 이동).
  static void noise(
    Float64List out, {
    required int seed,
    required double fc0,
    required double fc1,
    required double attack,
    required double decay,
    double gain = 1,
    double start = 0,
    double? length,
    bool highpass = false,
  }) {
    final rnd = math.Random(seed);
    final s0 = (start * sampleRate).round();
    if (s0 >= out.length) return;
    final s1 = length == null
        ? out.length
        : math.min(out.length, s0 + (length * sampleRate).round());
    final total = (s1 - s0) / sampleRate;
    double y = 0;
    for (int i = s0; i < s1; i++) {
      final t = (i - s0) / sampleRate;
      final fc = fc0 + (fc1 - fc0) * (total <= 0 ? 0 : t / total);
      final a = 1 - math.exp(-2 * math.pi * fc / sampleRate);
      final x = rnd.nextDouble() * 2 - 1;
      y += a * (x - y);
      final v = highpass ? x - y : y;
      out[i] += v * env(t, attack, decay) * gain;
    }
  }

  /// 주파수가 f0→f1로 바뀌는 음.
  static void tone(
    Float64List out, {
    required double f0,
    required double f1,
    required double attack,
    required double decay,
    required double gain,
    double start = 0,
    double? length,
    Wave wave = Wave.sine,
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
      out[i] += Synth.wave(wave, phase) * env(t, attack, decay) * gain;
    }
  }

  /// 고정 음높이 음표.
  static void note(
    Float64List out,
    double freq,
    double start,
    double length,
    Wave wave, {
    double decay = 0.15,
    double gain = 0.6,
    double attack = 0.004,
  }) {
    tone(
      out,
      f0: freq,
      f1: freq,
      attack: attack,
      decay: decay,
      gain: gain,
      start: start,
      length: length,
      wave: wave,
    );
  }

  /// 종·유리잔 같은 금속성 울림(배음 몇 개를 겹친다).
  static void bell(
    Float64List out,
    double freq,
    double start, {
    double length = 0.9,
    double decay = 0.35,
    double gain = 0.5,
  }) {
    const partials = [1.0, 2.76, 5.4, 8.93];
    const gains = [1.0, 0.5, 0.25, 0.12];
    for (int i = 0; i < partials.length; i++) {
      note(
        out,
        freq * partials[i],
        start,
        length,
        Wave.sine,
        decay: decay / (1 + i * 0.6),
        gain: gain * gains[i],
        attack: 0.002,
      );
    }
  }

  /// 최대 진폭을 [peak]로 맞추고 끝을 짧게 페이드아웃(딸깍 소리 방지).
  static Float64List finish(Float64List out, double peak) {
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
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
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
}
