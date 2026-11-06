import 'dart:math' as math;
import 'dart:typed_data';

import 'synth.dart';

/// 게임 2.0 효과음 목록. 모두 코드로 합성한다(저작권·파일 크기 걱정 없음).
enum GameSound {
  // 공통
  tap,
  select,
  confirm,
  turnMine,
  turnOpp,
  tick,
  warn,
  win,
  lose,
  draw,
  pop,
  whoosh,
  sparkle,
  start,
  // 카드
  cardDeal,
  cardFlip,
  cardPlace,
  cardShuffle,
  cardPair,
  joker,
  chip,
  bust,
  blackjack,
  // 해적
  knifeStab,
  barrelCreak,
  pirateBoom,
  pirateFly,
  heartbeat,
  // 축구
  whistle,
  kick,
  net,
  cheer,
  aww,
  save,
  // 제로
  drumroll,
  reveal,
  // 원카드
  colorChange,
  oneCardCall,
  caught,
  penaltyDraw,
  skip,
  reverse,
  // 윷놀이
  yutToss,
  yutClack,
  yutDrum,
  yutGong,
  yutKkwaeng,
  yutCapture,
  yutGoal,
  yutStack,
  yutStep,
  // 고스톱
  hwatuSlap,
  hwatuFlip,
  hwatuCapture,
  ppeok,
  sseul,
  goCall,
  coins,
}

/// 소리 레시피. [render]는 -1..1 PCM 샘플을 돌려준다.
class GameSoundRecipes {
  GameSoundRecipes._();

  static Float64List render(GameSound sound) => switch (sound) {
    GameSound.tap => _tap(),
    GameSound.select => _select(),
    GameSound.confirm => _confirm(),
    GameSound.turnMine => _turnMine(),
    GameSound.turnOpp => _turnOpp(),
    GameSound.tick => _tick(),
    GameSound.warn => _warn(),
    GameSound.win => _win(),
    GameSound.lose => _lose(),
    GameSound.draw => _drawResult(),
    GameSound.pop => _pop(),
    GameSound.whoosh => _whoosh(),
    GameSound.sparkle => _sparkle(),
    GameSound.start => _start(),
    GameSound.cardDeal => _cardDeal(),
    GameSound.cardFlip => _cardFlip(),
    GameSound.cardPlace => _cardPlace(),
    GameSound.cardShuffle => _cardShuffle(),
    GameSound.cardPair => _cardPair(),
    GameSound.joker => _joker(),
    GameSound.chip => _chip(),
    GameSound.bust => _bust(),
    GameSound.blackjack => _blackjack(),
    GameSound.knifeStab => _knifeStab(),
    GameSound.barrelCreak => _barrelCreak(),
    GameSound.pirateBoom => _pirateBoom(),
    GameSound.pirateFly => _pirateFly(),
    GameSound.heartbeat => _heartbeat(),
    GameSound.whistle => _whistle(),
    GameSound.kick => _kick(),
    GameSound.net => _net(),
    GameSound.cheer => _cheer(),
    GameSound.aww => _aww(),
    GameSound.save => _save(),
    GameSound.drumroll => _drumroll(),
    GameSound.reveal => _reveal(),
    GameSound.colorChange => _colorChange(),
    GameSound.oneCardCall => _oneCardCall(),
    GameSound.caught => _caught(),
    GameSound.penaltyDraw => _penaltyDraw(),
    GameSound.skip => _skip(),
    GameSound.reverse => _reverse(),
    GameSound.yutToss => _yutToss(),
    GameSound.yutClack => _yutClack(),
    GameSound.yutDrum => _yutDrum(),
    GameSound.yutGong => _yutGong(),
    GameSound.yutKkwaeng => _yutKkwaeng(),
    GameSound.yutCapture => _yutCapture(),
    GameSound.yutGoal => _yutGoal(),
    GameSound.yutStack => _yutStack(),
    GameSound.yutStep => _yutStep(),
    GameSound.hwatuSlap => _hwatuSlap(),
    GameSound.hwatuFlip => _hwatuFlip(),
    GameSound.hwatuCapture => _hwatuCapture(),
    GameSound.ppeok => _ppeok(),
    GameSound.sseul => _sseul(),
    GameSound.goCall => _goCall(),
    GameSound.coins => _coins(),
  };

  // ── 공통 ────────────────────────────────────────────────────────────────
  static Float64List _tap() {
    final o = Synth.buffer(0.06);
    Synth.tone(o, f0: 1800, f1: 1100, attack: 0.001, decay: 0.012, gain: 0.5);
    return Synth.finish(o, 0.28);
  }

  static Float64List _select() {
    final o = Synth.buffer(0.12);
    Synth.note(o, 880, 0, 0.1, Wave.triangle, decay: 0.05, gain: 0.5);
    Synth.note(o, 1320, 0.03, 0.08, Wave.sine, decay: 0.04, gain: 0.25);
    return Synth.finish(o, 0.32);
  }

  static Float64List _confirm() {
    final o = Synth.buffer(0.3);
    Synth.note(o, 660, 0, 0.12, Wave.triangle, decay: 0.07);
    Synth.note(o, 990, 0.08, 0.2, Wave.triangle, decay: 0.1);
    return Synth.finish(o, 0.4);
  }

  static Float64List _turnMine() {
    final o = Synth.buffer(0.7);
    Synth.bell(o, 784, 0, decay: 0.3, gain: 0.5);
    Synth.bell(o, 1175, 0.12, decay: 0.35, gain: 0.45);
    return Synth.finish(o, 0.42);
  }

  static Float64List _turnOpp() {
    final o = Synth.buffer(0.35);
    Synth.note(o, 523, 0, 0.3, Wave.sine, decay: 0.12, gain: 0.5);
    return Synth.finish(o, 0.25);
  }

  static Float64List _tick() {
    final o = Synth.buffer(0.05);
    Synth.tone(o, f0: 2400, f1: 2000, attack: 0.0005, decay: 0.008, gain: 0.6);
    return Synth.finish(o, 0.22);
  }

  static Float64List _warn() {
    final o = Synth.buffer(0.45);
    Synth.note(o, 880, 0, 0.14, Wave.squareSoft, decay: 0.08, gain: 0.4);
    Synth.note(o, 880, 0.2, 0.14, Wave.squareSoft, decay: 0.08, gain: 0.4);
    return Synth.finish(o, 0.32);
  }

  static Float64List _win() {
    final o = Synth.buffer(1.8);
    const seq = [523.25, 659.25, 783.99, 1046.5];
    for (int i = 0; i < seq.length; i++) {
      Synth.note(o, seq[i], i * 0.11, 0.25, Wave.triangle, decay: 0.12);
    }
    Synth.note(o, 1046.5, 0.44, 1.3, Wave.triangle, decay: 0.55, gain: 0.55);
    Synth.note(o, 783.99, 0.44, 1.3, Wave.triangle, decay: 0.55, gain: 0.32);
    Synth.note(o, 659.25, 0.44, 1.3, Wave.sine, decay: 0.55, gain: 0.3);
    Synth.bell(o, 2093, 0.44, decay: 0.4, gain: 0.18);
    return Synth.finish(o, 0.6);
  }

  static Float64List _lose() {
    final o = Synth.buffer(1.4);
    Synth.note(o, 392, 0, 0.32, Wave.sine, decay: 0.2);
    Synth.note(o, 349.2, 0.3, 0.32, Wave.sine, decay: 0.2);
    Synth.note(o, 293.7, 0.6, 0.8, Wave.sine, decay: 0.45);
    return Synth.finish(o, 0.45);
  }

  static Float64List _drawResult() {
    final o = Synth.buffer(0.9);
    Synth.note(o, 523.25, 0, 0.3, Wave.triangle, decay: 0.15);
    Synth.note(o, 523.25, 0.25, 0.6, Wave.triangle, decay: 0.3);
    Synth.note(o, 659.25, 0.25, 0.6, Wave.sine, decay: 0.3, gain: 0.3);
    return Synth.finish(o, 0.42);
  }

  static Float64List _pop() {
    final o = Synth.buffer(0.14);
    Synth.tone(o, f0: 420, f1: 1250, attack: 0.001, decay: 0.04, gain: 0.7);
    return Synth.finish(o, 0.38);
  }

  static Float64List _whoosh() {
    final o = Synth.buffer(0.42);
    Synth.noise(o, seed: 21, fc0: 600, fc1: 3600, attack: 0.12, decay: 0.12);
    return Synth.finish(o, 0.32);
  }

  static Float64List _sparkle() {
    final o = Synth.buffer(0.8);
    const notes = [1568.0, 2093.0, 2637.0, 3136.0];
    for (int i = 0; i < notes.length; i++) {
      Synth.bell(o, notes[i], i * 0.06, decay: 0.18, gain: 0.3);
    }
    return Synth.finish(o, 0.3);
  }

  static Float64List _start() {
    final o = Synth.buffer(0.9);
    Synth.note(o, 523.25, 0, 0.15, Wave.triangle, decay: 0.08);
    Synth.note(o, 659.25, 0.12, 0.15, Wave.triangle, decay: 0.08);
    Synth.bell(o, 1046.5, 0.24, decay: 0.4, gain: 0.5);
    return Synth.finish(o, 0.45);
  }

  // ── 카드 ────────────────────────────────────────────────────────────────
  static Float64List _cardDeal() {
    final o = Synth.buffer(0.18);
    Synth.noise(
      o,
      seed: 31,
      fc0: 5200,
      fc1: 1800,
      attack: 0.004,
      decay: 0.035,
      highpass: true,
    );
    Synth.noise(
      o,
      seed: 32,
      fc0: 900,
      fc1: 400,
      attack: 0.001,
      decay: 0.012,
      gain: 0.6,
      start: 0.07,
    );
    return Synth.finish(o, 0.42);
  }

  static Float64List _cardFlip() {
    final o = Synth.buffer(0.14);
    Synth.noise(
      o,
      seed: 33,
      fc0: 3800,
      fc1: 2200,
      attack: 0.002,
      decay: 0.02,
      highpass: true,
    );
    Synth.tone(
      o,
      f0: 260,
      f1: 160,
      attack: 0.001,
      decay: 0.02,
      gain: 0.5,
      start: 0.035,
    );
    return Synth.finish(o, 0.45);
  }

  static Float64List _cardPlace() {
    final o = Synth.buffer(0.12);
    Synth.noise(o, seed: 34, fc0: 1400, fc1: 600, attack: 0.001, decay: 0.018);
    Synth.tone(o, f0: 180, f1: 120, attack: 0.001, decay: 0.03, gain: 0.6);
    return Synth.finish(o, 0.5);
  }

  static Float64List _cardShuffle() {
    final o = Synth.buffer(0.7);
    for (int i = 0; i < 9; i++) {
      Synth.noise(
        o,
        seed: 40 + i,
        fc0: 4200,
        fc1: 2600,
        attack: 0.002,
        decay: 0.012,
        gain: 0.7,
        start: i * 0.065,
        length: 0.06,
        highpass: true,
      );
    }
    return Synth.finish(o, 0.36);
  }

  static Float64List _cardPair() {
    final o = Synth.buffer(0.6);
    Synth.bell(o, 1318.5, 0, decay: 0.22, gain: 0.45);
    Synth.bell(o, 1975.5, 0.08, decay: 0.28, gain: 0.4);
    return Synth.finish(o, 0.38);
  }

  static Float64List _joker() {
    final o = Synth.buffer(1.1);
    Synth.note(o, 311.1, 0, 0.3, Wave.triangle, decay: 0.18, gain: 0.5);
    Synth.note(o, 293.7, 0.22, 0.3, Wave.triangle, decay: 0.18, gain: 0.5);
    Synth.tone(
      o,
      f0: 277.2,
      f1: 246.9,
      attack: 0.01,
      decay: 0.35,
      gain: 0.5,
      start: 0.44,
      length: 0.6,
      wave: Wave.triangle,
      vibratoHz: 6,
      vibratoDepth: 0.02,
    );
    return Synth.finish(o, 0.42);
  }

  static Float64List _chip() {
    final o = Synth.buffer(0.2);
    Synth.bell(o, 2600, 0, length: 0.15, decay: 0.03, gain: 0.5);
    Synth.bell(o, 3100, 0.05, length: 0.12, decay: 0.025, gain: 0.35);
    return Synth.finish(o, 0.3);
  }

  static Float64List _bust() {
    final o = Synth.buffer(0.6);
    Synth.tone(
      o,
      f0: 220,
      f1: 70,
      attack: 0.002,
      decay: 0.18,
      gain: 0.8,
      wave: Wave.triangle,
    );
    Synth.noise(
      o,
      seed: 51,
      fc0: 900,
      fc1: 150,
      attack: 0.002,
      decay: 0.08,
      gain: 0.4,
    );
    return Synth.finish(o, 0.5);
  }

  static Float64List _blackjack() {
    final o = Synth.buffer(1.2);
    const notes = [1046.5, 1318.5, 1568.0, 2093.0];
    for (int i = 0; i < notes.length; i++) {
      Synth.bell(o, notes[i], i * 0.07, decay: 0.3, gain: 0.35);
    }
    Synth.note(o, 523.25, 0.28, 0.8, Wave.triangle, decay: 0.4, gain: 0.35);
    return Synth.finish(o, 0.48);
  }

  // ── 해적 ────────────────────────────────────────────────────────────────
  static Float64List _knifeStab() {
    final o = Synth.buffer(0.32);
    Synth.tone(o, f0: 3200, f1: 1600, attack: 0.001, decay: 0.04, gain: 0.25);
    Synth.noise(
      o,
      seed: 61,
      fc0: 2400,
      fc1: 500,
      attack: 0.001,
      decay: 0.03,
      gain: 0.7,
      start: 0.03,
    );
    Synth.tone(
      o,
      f0: 140,
      f1: 90,
      attack: 0.001,
      decay: 0.07,
      gain: 0.8,
      start: 0.03,
      wave: Wave.triangle,
    );
    return Synth.finish(o, 0.55);
  }

  static Float64List _barrelCreak() {
    final o = Synth.buffer(0.6);
    Synth.tone(
      o,
      f0: 140,
      f1: 210,
      attack: 0.05,
      decay: 0.3,
      gain: 0.5,
      wave: Wave.saw,
      vibratoHz: 23,
      vibratoDepth: 0.08,
      expSweep: false,
    );
    Synth.noise(
      o,
      seed: 62,
      fc0: 700,
      fc1: 500,
      attack: 0.05,
      decay: 0.25,
      gain: 0.25,
    );
    return Synth.finish(o, 0.3);
  }

  static Float64List _pirateBoom() {
    final o = Synth.buffer(1.3);
    Synth.noise(o, seed: 63, fc0: 2600, fc1: 140, attack: 0.003, decay: 0.3);
    Synth.tone(o, f0: 120, f1: 35, attack: 0.002, decay: 0.3, gain: 0.9);
    Synth.tone(
      o,
      f0: 660,
      f1: 1500,
      attack: 0.002,
      decay: 0.12,
      gain: 0.25,
      start: 0.02,
      wave: Wave.triangle,
    );
    return Synth.finish(o, 0.85);
  }

  static Float64List _pirateFly() {
    final o = Synth.buffer(1.0);
    Synth.tone(
      o,
      f0: 300,
      f1: 1600,
      attack: 0.02,
      decay: 0.5,
      gain: 0.45,
      wave: Wave.triangle,
      vibratoHz: 9,
      vibratoDepth: 0.03,
    );
    Synth.noise(
      o,
      seed: 64,
      fc0: 800,
      fc1: 4200,
      attack: 0.1,
      decay: 0.3,
      gain: 0.35,
    );
    return Synth.finish(o, 0.42);
  }

  static Float64List _heartbeat() {
    final o = Synth.buffer(0.7);
    Synth.tone(o, f0: 70, f1: 50, attack: 0.004, decay: 0.06, gain: 1);
    Synth.tone(
      o,
      f0: 64,
      f1: 46,
      attack: 0.004,
      decay: 0.07,
      gain: 0.8,
      start: 0.2,
    );
    return Synth.finish(o, 0.6);
  }

  // ── 축구 ────────────────────────────────────────────────────────────────
  static Float64List _whistle() {
    final o = Synth.buffer(0.75);
    Synth.tone(
      o,
      f0: 2900,
      f1: 2850,
      attack: 0.02,
      decay: 0.5,
      gain: 0.5,
      length: 0.6,
      vibratoHz: 38,
      vibratoDepth: 0.03,
    );
    Synth.noise(
      o,
      seed: 71,
      fc0: 3000,
      fc1: 3000,
      attack: 0.02,
      decay: 0.4,
      gain: 0.12,
      length: 0.6,
    );
    return Synth.finish(o, 0.32);
  }

  static Float64List _kick() {
    final o = Synth.buffer(0.3);
    Synth.tone(o, f0: 180, f1: 60, attack: 0.001, decay: 0.07, gain: 1);
    Synth.noise(
      o,
      seed: 72,
      fc0: 2500,
      fc1: 600,
      attack: 0.001,
      decay: 0.02,
      gain: 0.5,
    );
    return Synth.finish(o, 0.6);
  }

  static Float64List _net() {
    final o = Synth.buffer(0.6);
    Synth.noise(
      o,
      seed: 73,
      fc0: 5200,
      fc1: 1600,
      attack: 0.01,
      decay: 0.16,
      gain: 0.8,
      highpass: true,
    );
    Synth.tone(o, f0: 110, f1: 80, attack: 0.004, decay: 0.12, gain: 0.4);
    return Synth.finish(o, 0.45);
  }

  static Float64List _cheer() {
    final o = Synth.buffer(1.8);
    for (int i = 0; i < 6; i++) {
      Synth.noise(
        o,
        seed: 80 + i,
        fc0: 1600 + i * 180,
        fc1: 900,
        attack: 0.25,
        decay: 0.7,
        gain: 0.35,
      );
    }
    final rnd = math.Random(9);
    for (int i = 0; i < 14; i++) {
      Synth.tone(
        o,
        f0: 500 + rnd.nextDouble() * 500,
        f1: 700 + rnd.nextDouble() * 600,
        attack: 0.05,
        decay: 0.25,
        gain: 0.05,
        start: 0.1 + rnd.nextDouble() * 0.8,
        length: 0.5,
        wave: Wave.triangle,
        vibratoHz: 6,
        vibratoDepth: 0.04,
      );
    }
    return Synth.finish(o, 0.4);
  }

  static Float64List _aww() {
    final o = Synth.buffer(1.2);
    for (int i = 0; i < 4; i++) {
      Synth.tone(
        o,
        f0: 520 - i * 25,
        f1: 300 - i * 15,
        attack: 0.08,
        decay: 0.5,
        gain: 0.18,
        wave: Wave.triangle,
        vibratoHz: 5,
        vibratoDepth: 0.02,
      );
    }
    Synth.noise(
      o,
      seed: 90,
      fc0: 900,
      fc1: 400,
      attack: 0.1,
      decay: 0.45,
      gain: 0.25,
    );
    return Synth.finish(o, 0.34);
  }

  static Float64List _save() {
    final o = Synth.buffer(0.35);
    Synth.tone(o, f0: 130, f1: 80, attack: 0.001, decay: 0.06, gain: 0.9);
    Synth.noise(
      o,
      seed: 91,
      fc0: 1200,
      fc1: 400,
      attack: 0.001,
      decay: 0.04,
      gain: 0.6,
    );
    return Synth.finish(o, 0.55);
  }

  // ── 제로 ────────────────────────────────────────────────────────────────
  static Float64List _drumroll() {
    final o = Synth.buffer(1.2);
    for (int i = 0; i < 28; i++) {
      final g = 0.35 + 0.65 * (i / 28);
      Synth.noise(
        o,
        seed: 100 + i,
        fc0: 1800,
        fc1: 700,
        attack: 0.001,
        decay: 0.018,
        gain: g,
        start: i * 0.04,
        length: 0.05,
      );
      Synth.tone(
        o,
        f0: 190,
        f1: 150,
        attack: 0.001,
        decay: 0.02,
        gain: g * 0.5,
        start: i * 0.04,
        length: 0.05,
      );
    }
    return Synth.finish(o, 0.4);
  }

  static Float64List _reveal() {
    final o = Synth.buffer(1.3);
    Synth.noise(
      o,
      seed: 130,
      fc0: 7000,
      fc1: 3000,
      attack: 0.002,
      decay: 0.4,
      gain: 0.5,
      highpass: true,
    );
    Synth.tone(o, f0: 110, f1: 60, attack: 0.002, decay: 0.15, gain: 0.8);
    Synth.bell(o, 1568, 0.02, decay: 0.5, gain: 0.25);
    return Synth.finish(o, 0.5);
  }

  // ── 원카드 ──────────────────────────────────────────────────────────────
  static Float64List _colorChange() {
    final o = Synth.buffer(0.7);
    Synth.tone(
      o,
      f0: 400,
      f1: 1600,
      attack: 0.01,
      decay: 0.25,
      gain: 0.35,
      wave: Wave.triangle,
    );
    Synth.bell(o, 1760, 0.18, decay: 0.3, gain: 0.35);
    return Synth.finish(o, 0.38);
  }

  static Float64List _oneCardCall() {
    final o = Synth.buffer(1.0);
    Synth.note(o, 784, 0, 0.14, Wave.triangle, decay: 0.08);
    Synth.note(o, 1046.5, 0.1, 0.14, Wave.triangle, decay: 0.08);
    Synth.bell(o, 1568, 0.2, decay: 0.45, gain: 0.5);
    Synth.bell(o, 2093, 0.24, decay: 0.45, gain: 0.3);
    return Synth.finish(o, 0.5);
  }

  static Float64List _caught() {
    final o = Synth.buffer(0.55);
    Synth.note(o, 220, 0, 0.18, Wave.squareSoft, decay: 0.1, gain: 0.5);
    Synth.note(o, 185, 0.2, 0.3, Wave.squareSoft, decay: 0.15, gain: 0.5);
    return Synth.finish(o, 0.38);
  }

  static Float64List _penaltyDraw() {
    final o = Synth.buffer(0.6);
    for (int i = 0; i < 3; i++) {
      Synth.noise(
        o,
        seed: 140 + i,
        fc0: 4200,
        fc1: 1500,
        attack: 0.003,
        decay: 0.03,
        gain: 0.6,
        start: i * 0.1,
        length: 0.1,
        highpass: true,
      );
    }
    Synth.tone(
      o,
      f0: 330,
      f1: 165,
      attack: 0.002,
      decay: 0.15,
      gain: 0.5,
      start: 0.25,
      wave: Wave.triangle,
    );
    return Synth.finish(o, 0.42);
  }

  static Float64List _skip() {
    final o = Synth.buffer(0.35);
    Synth.tone(
      o,
      f0: 900,
      f1: 300,
      attack: 0.002,
      decay: 0.12,
      gain: 0.5,
      wave: Wave.triangle,
    );
    return Synth.finish(o, 0.36);
  }

  static Float64List _reverse() {
    final o = Synth.buffer(0.45);
    Synth.tone(
      o,
      f0: 500,
      f1: 1100,
      attack: 0.002,
      decay: 0.1,
      gain: 0.45,
      length: 0.18,
      wave: Wave.triangle,
    );
    Synth.tone(
      o,
      f0: 1100,
      f1: 500,
      attack: 0.002,
      decay: 0.1,
      gain: 0.45,
      start: 0.18,
      wave: Wave.triangle,
    );
    return Synth.finish(o, 0.36);
  }

  // ── 윷놀이: 나무 윷가락, 북, 꽹과리, 징 ───────────────────────────────────
  /// 나무 한 번 "딱" (높이·길이를 달리해 윷가락마다 다른 소리를 낸다).
  static void _woodKnock(
    Float64List o,
    double start,
    double pitch, {
    double gain = 0.8,
    int seed = 1,
  }) {
    Synth.noise(
      o,
      seed: seed,
      fc0: 3200,
      fc1: 900,
      attack: 0.0006,
      decay: 0.012,
      gain: gain,
      start: start,
      length: 0.05,
    );
    Synth.tone(
      o,
      f0: pitch * 1.5,
      f1: pitch,
      attack: 0.0008,
      decay: 0.03,
      gain: gain * 0.7,
      start: start,
      length: 0.09,
      wave: Wave.triangle,
    );
  }

  static Float64List _yutToss() {
    final o = Synth.buffer(0.7);
    Synth.noise(
      o,
      seed: 301,
      fc0: 500,
      fc1: 2600,
      attack: 0.1,
      decay: 0.1,
      gain: 0.35,
      length: 0.3,
    );
    // 윷가락 네 개가 서로 부딪히는 소리.
    for (int i = 0; i < 4; i++) {
      _woodKnock(o, 0.16 + i * 0.045, 820 + i * 90, gain: 0.55, seed: 310 + i);
    }
    return Synth.finish(o, 0.5);
  }

  static Float64List _yutClack() {
    final o = Synth.buffer(0.2);
    _woodKnock(o, 0, 700, gain: 0.9, seed: 320);
    _woodKnock(o, 0.045, 940, gain: 0.5, seed: 321);
    return Synth.finish(o, 0.55);
  }

  /// 북: 낮은 울림.
  static void _drumHit(
    Float64List o,
    double start, {
    double gain = 0.9,
    double pitch = 120,
  }) {
    Synth.tone(
      o,
      f0: pitch * 1.8,
      f1: pitch * 0.55,
      attack: 0.002,
      decay: 0.12,
      gain: gain,
      start: start,
      length: 0.35,
      wave: Wave.triangle,
    );
    Synth.noise(
      o,
      seed: 330 + (start * 100).round(),
      fc0: 900,
      fc1: 200,
      attack: 0.001,
      decay: 0.025,
      gain: gain * 0.5,
      start: start,
      length: 0.08,
    );
  }

  static Float64List _yutDrum() {
    final o = Synth.buffer(0.5);
    _drumHit(o, 0);
    return Synth.finish(o, 0.62);
  }

  static Float64List _yutGong() {
    final o = Synth.buffer(2.0);
    Synth.bell(o, 150, 0, length: 1.9, decay: 0.9, gain: 0.55);
    Synth.tone(
      o,
      f0: 210,
      f1: 175,
      attack: 0.004,
      decay: 0.7,
      gain: 0.35,
      length: 1.9,
      vibratoHz: 6,
      vibratoDepth: 0.01,
    );
    return Synth.finish(o, 0.5);
  }

  /// 꽹과리: 밝고 짧은 쇳소리 연타.
  static Float64List _yutKkwaeng() {
    final o = Synth.buffer(0.9);
    const hits = [0.0, 0.11, 0.22, 0.36];
    for (int i = 0; i < hits.length; i++) {
      Synth.bell(
        o,
        1180 + i * 40,
        hits[i],
        length: 0.3,
        decay: 0.07,
        gain: 0.5,
      );
      Synth.noise(
        o,
        seed: 340 + i,
        fc0: 6000,
        fc1: 3000,
        attack: 0.0005,
        decay: 0.01,
        gain: 0.35,
        start: hits[i],
        length: 0.04,
        highpass: true,
      );
    }
    _drumHit(o, 0, gain: 0.6);
    _drumHit(o, 0.36, gain: 0.7);
    return Synth.finish(o, 0.6);
  }

  static Float64List _yutCapture() {
    final o = Synth.buffer(1.3);
    Synth.bell(o, 1250, 0, length: 0.4, decay: 0.09, gain: 0.55);
    Synth.bell(o, 1250, 0.09, length: 0.4, decay: 0.09, gain: 0.55);
    _drumHit(o, 0.02, gain: 0.8, pitch: 100);
    _drumHit(o, 0.2, gain: 0.8, pitch: 90);
    Synth.bell(o, 150, 0.22, length: 1.0, decay: 0.5, gain: 0.5);
    Synth.noise(
      o,
      seed: 350,
      fc0: 3500,
      fc1: 400,
      attack: 0.002,
      decay: 0.12,
      gain: 0.35,
      start: 0.03,
      length: 0.3,
    );
    return Synth.finish(o, 0.6);
  }

  static Float64List _yutGoal() {
    final o = Synth.buffer(1.6);
    for (int i = 0; i < 3; i++) {
      _drumHit(o, i * 0.14, gain: 0.7 + i * 0.1, pitch: 110 + i * 14);
    }
    const notes = [587.33, 739.99, 880.0, 1174.66];
    for (int i = 0; i < notes.length; i++) {
      Synth.note(
        o,
        notes[i],
        0.42 + i * 0.08,
        0.5,
        Wave.triangle,
        decay: 0.2,
        gain: 0.45,
      );
    }
    Synth.bell(o, 1174.66, 0.75, length: 0.8, decay: 0.4, gain: 0.35);
    Synth.bell(o, 146.8, 0.45, length: 1.1, decay: 0.55, gain: 0.35);
    return Synth.finish(o, 0.55);
  }

  static Float64List _yutStack() {
    final o = Synth.buffer(0.3);
    _woodKnock(o, 0, 520, gain: 0.7, seed: 360);
    _woodKnock(o, 0.08, 620, gain: 0.7, seed: 361);
    Synth.note(o, 880, 0.1, 0.18, Wave.sine, decay: 0.08, gain: 0.25);
    return Synth.finish(o, 0.45);
  }

  /// 말이 한 칸 가는 소리(바둑돌 놓는 소리처럼).
  static Float64List _yutStep() {
    final o = Synth.buffer(0.12);
    Synth.tone(
      o,
      f0: 1500,
      f1: 700,
      attack: 0.0008,
      decay: 0.02,
      gain: 0.55,
      wave: Wave.triangle,
      length: 0.07,
    );
    Synth.noise(
      o,
      seed: 370,
      fc0: 3000,
      fc1: 1200,
      attack: 0.0005,
      decay: 0.008,
      gain: 0.3,
      length: 0.03,
    );
    return Synth.finish(o, 0.34);
  }

  // ── 고스톱 ──────────────────────────────────────────────────────────────
  // 두꺼운 화투를 판에 "탁" 내리치는 소리: 낮은 몸통 + 짧은 마찰.
  static Float64List _hwatuSlap() {
    final o = Synth.buffer(0.16);
    Synth.tone(o, f0: 210, f1: 90, attack: 0.001, decay: 0.045, gain: 1);
    Synth.noise(o, seed: 71, fc0: 2400, fc1: 700, attack: 0.001, decay: 0.02);
    Synth.noise(
      o,
      seed: 72,
      fc0: 5200,
      fc1: 3000,
      attack: 0.001,
      decay: 0.008,
      gain: 0.5,
      highpass: true,
    );
    return Synth.finish(o, 0.62);
  }

  // 더미에서 뒤집는 소리: 얇은 스치는 소리 뒤에 가벼운 착지.
  static Float64List _hwatuFlip() {
    final o = Synth.buffer(0.24);
    Synth.noise(
      o,
      seed: 73,
      fc0: 1800,
      fc1: 4800,
      attack: 0.04,
      decay: 0.05,
      gain: 0.7,
      highpass: true,
    );
    Synth.tone(
      o,
      f0: 240,
      f1: 130,
      attack: 0.001,
      decay: 0.03,
      gain: 0.7,
      start: 0.1,
    );
    Synth.noise(
      o,
      seed: 74,
      fc0: 1600,
      fc1: 600,
      attack: 0.001,
      decay: 0.014,
      start: 0.1,
    );
    return Synth.finish(o, 0.5);
  }

  // 먹는 소리: 두 번 맑게 울리는 짝 소리.
  static Float64List _hwatuCapture() {
    final o = Synth.buffer(0.55);
    Synth.tone(o, f0: 190, f1: 100, attack: 0.001, decay: 0.04, gain: 0.8);
    Synth.bell(o, 1046.5, 0.03, decay: 0.2, gain: 0.45);
    Synth.bell(o, 1568, 0.11, decay: 0.28, gain: 0.4);
    return Synth.finish(o, 0.5);
  }

  // 뻑: 어긋나는 낮은 두 음.
  static Float64List _ppeok() {
    final o = Synth.buffer(0.7);
    Synth.tone(
      o,
      f0: 300,
      f1: 90,
      attack: 0.002,
      decay: 0.2,
      gain: 0.8,
      wave: Wave.saw,
    );
    Synth.note(o, 196, 0.12, 0.28, Wave.squareSoft, decay: 0.16, gain: 0.45);
    Synth.note(o, 185, 0.26, 0.34, Wave.squareSoft, decay: 0.2, gain: 0.45);
    return Synth.finish(o, 0.5);
  }

  // 쓸: 위로 쓸어 올리는 반짝임.
  static Float64List _sseul() {
    final o = Synth.buffer(0.9);
    Synth.noise(
      o,
      seed: 75,
      fc0: 500,
      fc1: 4200,
      attack: 0.18,
      decay: 0.1,
      gain: 0.5,
    );
    const notes = [880.0, 1175.0, 1568.0, 2093.0];
    for (int i = 0; i < notes.length; i++) {
      Synth.bell(o, notes[i], 0.12 + i * 0.07, decay: 0.3, gain: 0.35);
    }
    return Synth.finish(o, 0.5);
  }

  // "고!": 힘 있게 올라가는 두 음 + 긴 종소리.
  static Float64List _goCall() {
    final o = Synth.buffer(1.1);
    Synth.note(o, 392, 0, 0.16, Wave.triangle, decay: 0.09, gain: 0.7);
    Synth.note(o, 587.3, 0.12, 0.2, Wave.triangle, decay: 0.1, gain: 0.7);
    Synth.bell(o, 1174.7, 0.26, decay: 0.5, gain: 0.55);
    Synth.bell(o, 1568, 0.3, decay: 0.5, gain: 0.3);
    return Synth.finish(o, 0.52);
  }

  // 정산 동전: 짧은 쨍 소리 여러 번.
  static Float64List _coins() {
    final o = Synth.buffer(1.0);
    const starts = [0.0, 0.07, 0.13, 0.22, 0.29, 0.4];
    const freqs = [2600.0, 3100.0, 2800.0, 3300.0, 2700.0, 3500.0];
    for (int i = 0; i < starts.length; i++) {
      Synth.bell(
        o,
        freqs[i],
        starts[i],
        length: 0.16,
        decay: 0.035,
        gain: 0.45,
      );
    }
    Synth.bell(o, 1568, 0.45, decay: 0.3, gain: 0.25);
    return Synth.finish(o, 0.4);
  }
}
