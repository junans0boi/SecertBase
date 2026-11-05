import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/arcade/games/tank/tank_camera.dart';
import 'package:secret_base_app/screens/arcade/games/tank/tank_playback.dart';
import 'package:secret_base_app/screens/arcade/games/tank/tank_synth.dart';

import 'tank_test_support.dart';

void main() {
  group('TankSynth', () {
    test('every sound renders a valid, non-silent, clipped-safe WAV', () {
      for (final sound in TankSound.values) {
        final samples = TankSynth.render(sound);
        expect(samples.length, greaterThan(500), reason: '$sound length');
        double peak = 0;
        for (final v in samples) {
          if (v.abs() > peak) peak = v.abs();
        }
        expect(peak, greaterThan(0.05), reason: '$sound is silent');
        expect(peak, lessThanOrEqualTo(1.0), reason: '$sound clips');

        final wav = TankSynth.wav(samples);
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        final data = ByteData.sublistView(wav);
        expect(data.getUint32(24, Endian.little), TankSynth.sampleRate);
        expect(data.getUint32(40, Endian.little), samples.length * 2);
        expect(wav.length, 44 + samples.length * 2);
      }
    });

    test('rendering is deterministic', () {
      final a = TankSynth.render(TankSound.explosion);
      final b = TankSynth.render(TankSound.explosion);
      expect(a, b);
    });
  });

  group('TankCamera', () {
    const phone = Size(375, 700);
    const desktop = Size(1280, 720);

    test('keeps cells square and zooms in on phones', () {
      final view = TankCamera.target(
        size: phone,
        insetTop: 128,
        insetBottom: 196,
        focus: const Offset(20, 22),
      );
      final cols = phone.width / view.scale;
      expect(cols, lessThan(60));
      expect(view.left, greaterThanOrEqualTo(-0.5));
      // 초점이 보이는 띠 안에 들어온다.
      final p = view.toScreen(20, 22);
      expect(p.dx, inInclusiveRange(0, phone.width));
      expect(p.dy, inInclusiveRange(128, phone.height - 196));
    });

    test('overview fits the whole width', () {
      final view = TankCamera.target(
        size: phone,
        insetTop: 128,
        insetBottom: 196,
        focus: const Offset(80, 20),
        overview: true,
      );
      expect(view.toScreen(-0.5, 0).dx, closeTo(0, 0.5));
      expect(view.toScreen(99.5, 0).dx, closeTo(phone.width, 0.5));
    });

    test('never shows past the map edges when zoomed in', () {
      for (final focusX in [0.0, 50.0, 99.0]) {
        final view = TankCamera.target(
          size: desktop,
          insetTop: 128,
          insetBottom: 196,
          focus: Offset(focusX, 20),
        );
        expect(view.left, greaterThanOrEqualTo(-0.5 - 1e-9));
        expect(
          view.left + desktop.width / view.scale,
          lessThanOrEqualTo(99.5 + 1e-9),
        );
        // 땅 밑바닥이 조작부 위로 떠오르지 않는다.
        expect(
          view.toScreen(0, 40).dy,
          greaterThanOrEqualTo(desktop.height - 196 - 1e-6),
        );
      }
    });

    test('toWorld inverts toScreen', () {
      const view = TankView(10, -20, 7.5);
      final p = view.toScreen(33, 12);
      final w = view.toWorld(p);
      expect(w.dx, closeTo(33, 1e-9));
      expect(w.dy, closeTo(12, 1e-9));
    });
  });

  group('TankPlayback', () {
    test('builds a timeline with fire, flight, blast, hit-stop and KO', () {
      final state = tankTestState(oppHp: 30);
      final pb = TankPlayback.fromShot(
        tankTestShot(state, damage: 40),
        pre: state,
      );
      expect(pb.shells, hasLength(1));
      expect(pb.stageCount, 1);
      expect(pb.booms.where((b) => b.kind == TankBoomKind.blast), hasLength(1));
      // 상대 HP 30에 피해 40: 격파 연출
      expect(pb.booms.where((b) => b.kind == TankBoomKind.ko), hasLength(1));
      expect(pb.popups.any((p) => p.text == '격파!'), isTrue);
      expect(pb.popups.any((p) => p.text.startsWith('직격!')), isTrue);
      expect(pb.cues.first.atMs, 0);
      expect(pb.cues.any((c) => c.sound == TankSound.clang), isTrue);
      expect(pb.cues.any((c) => c.sound == TankSound.explosionBig), isTrue);
      // 직격 정지(hit-stop)
      expect(pb.holds, hasLength(1));
      expect(pb.rawTotalMs, greaterThan(pb.totalMs));
      final hold = pb.holds.first;
      expect(pb.effective(hold.atMs + hold.durMs / 2), hold.atMs);
      expect(pb.effective(pb.rawTotalMs), closeTo(pb.totalMs, 1e-6));
      expect(pb.settleMs, greaterThan(pb.boomStart(0)));
      expect(pb.shakeAt(pb.boomStart(0) + 10), greaterThan(0));
    });

    test('no KO when the target survives', () {
      final state = tankTestState(oppHp: 70);
      final pb = TankPlayback.fromShot(
        tankTestShot(state, damage: 40),
        pre: state,
      );
      expect(pb.booms.where((b) => b.kind == TankBoomKind.ko), isEmpty);
    });

    test('cluster split uses a short gap before bomblets', () {
      final shot = {
        'shooter': 0,
        'weapon': 'cluster',
        'angle': 60,
        'events': [
          {
            'type': 'shell',
            'stage': 0,
            'path': [
              {'x': 10, 'y': 20},
              {'x': 20, 'y': 5},
            ],
          },
          {'type': 'split', 'col': 20, 'row': 5, 'stage': 0},
          for (int i = 0; i < 4; i++)
            {
              'type': 'shell',
              'stage': 1,
              'path': [
                {'x': 20, 'y': 5},
                {'x': 22 + i, 'y': 20},
              ],
            },
          for (int i = 0; i < 4; i++)
            {'type': 'blast', 'col': 22 + i, 'row': 20, 'r': 3, 'stage': 1},
        ],
      };
      final pb = TankPlayback.fromShot(shot);
      expect(pb.stageCount, 2);
      final gap = pb.stageStartMs[1] - pb.boomStart(0);
      expect(gap, TankPlayback.splitGapMs);
      expect(pb.booms.where((b) => b.kind == TankBoomKind.split), hasLength(1));
    });
  });
}
