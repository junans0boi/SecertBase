import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tank_data.dart';
import 'tank_synth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 서버 shotResult.events → 재생 타임라인(연출·효과음·흔들림·직격 정지).
// 시간 단위는 ms. "유효 시간"은 직격 순간의 짧은 정지(hit-stop)를 뺀 연출 시간이다.
// ─────────────────────────────────────────────────────────────────────────────

class TankShellTrack {
  final List<Offset> path;
  final int stage;
  final String weapon;
  const TankShellTrack(this.path, this.stage, this.weapon);
}

enum TankBoomKind { blast, quake, drill, mound, split, teleport, ko }

class TankBoom {
  final double col;
  final double row;
  final double radius;
  final int stage;
  final TankBoomKind kind;

  /// 해당 단계 폭발 시각 기준 추가 지연.
  final double delayMs;
  const TankBoom(
    this.col,
    this.row,
    this.radius,
    this.stage,
    this.kind, {
    this.delayMs = 0,
  });
}

class TankPopup {
  /// 전차 번호(-1이면 [col]/[row] 좌표 사용).
  final int target;
  final String text;
  final Color color;
  final int stage;
  final double size;
  final double delayMs;
  final double col;
  final double row;
  const TankPopup(
    this.target,
    this.text,
    this.color,
    this.stage, {
    this.size = 18,
    this.delayMs = 0,
    this.col = 0,
    this.row = 0,
  });
}

class TankHit {
  final int target;
  final int stage;
  final int amount;
  final bool direct;
  const TankHit(this.target, this.stage, this.amount, this.direct);
}

class TankSoundCue {
  final double atMs;
  final TankSound sound;
  final double volume;
  const TankSoundCue(this.atMs, this.sound, [this.volume = 1]);
}

class TankShake {
  final double atMs;
  final double power;
  final double durMs;
  const TankShake(this.atMs, this.power, this.durMs);
}

class TankHold {
  final double atMs;
  final double durMs;
  const TankHold(this.atMs, this.durMs);
}

class TankPlayback {
  static const double preRollMs = 150;
  static const double boomMs = 650;
  static const double splitGapMs = 110;

  final int shooter;
  final String weapon;
  final double angle;
  final List<TankShellTrack> shells;
  final List<TankBoom> booms;
  final List<TankPopup> popups;
  final List<TankHit> hits;
  final List<TankSoundCue> cues;
  final List<TankShake> shakes;
  final List<TankShake> flashes;
  final List<TankHold> holds;
  final List<double> stageStartMs;
  final List<double> stageFlightMs;

  /// 유효 시간 기준 전체 길이.
  final double totalMs;

  /// 마지막 폭발(격파 포함)이 끝나는 유효 시각: 이때 새 상태로 바꿔 그린다.
  final double settleMs;

  TankPlayback._({
    required this.shooter,
    required this.weapon,
    required this.angle,
    required this.shells,
    required this.booms,
    required this.popups,
    required this.hits,
    required this.cues,
    required this.shakes,
    required this.flashes,
    required this.holds,
    required this.stageStartMs,
    required this.stageFlightMs,
    required this.totalMs,
    required this.settleMs,
  });

  int get stageCount => stageStartMs.length;

  /// 단계 [s]의 폭발 시각(유효 시간).
  double boomStart(int s) {
    if (stageStartMs.isEmpty) return preRollMs;
    final i = s.clamp(0, stageStartMs.length - 1);
    return stageStartMs[i] + stageFlightMs[i];
  }

  double boomAt(TankBoom b) => boomStart(b.stage) + b.delayMs;

  /// 실제 경과 시간(직격 정지 포함) 전체 길이.
  double get rawTotalMs =>
      totalMs + holds.fold<double>(0, (sum, h) => sum + h.durMs);

  /// 실제 경과 시간 → 유효 시간(직격 정지 동안 멈춘다).
  double effective(double raw) {
    double shift = 0;
    for (final h in holds) {
      final rawStart = h.atMs + shift;
      if (raw <= rawStart) break;
      if (raw <= rawStart + h.durMs) return h.atMs;
      shift += h.durMs;
    }
    return raw - shift;
  }

  /// 유효 시각 [t]의 화면 흔들림 세기(px 기준 배율).
  double shakeAt(double t) {
    double power = 0;
    for (final s in shakes) {
      final dt = t - s.atMs;
      if (dt < 0 || dt > s.durMs) continue;
      power = math.max(power, s.power * (1 - dt / s.durMs));
    }
    return power;
  }

  /// 유효 시각 [t]의 화면 섬광 세기(0..1).
  double flashAt(double t) {
    double a = 0;
    for (final f in flashes) {
      final dt = t - f.atMs;
      if (dt < 0 || dt > f.durMs) continue;
      a = math.max(a, f.power * (1 - dt / f.durMs));
    }
    return a.clamp(0.0, 1.0);
  }

  /// [shot]: 서버 shotResult. [pre]: 발사 직전 상태(격파 판정·위치용).
  /// 서버는 shot을 새 상태보다 먼저 보내므로 격파 여부는 이벤트로 계산한다.
  factory TankPlayback.fromShot(
    Map<String, dynamic> shot, {
    Map<String, dynamic>? pre,
  }) {
    final weapon = shot['weapon'] as String? ?? 'basic';
    final shooter = (shot['shooter'] as num?)?.toInt() ?? 0;
    final angle = (shot['angle'] as num?)?.toDouble() ?? 45;
    final events = (shot['events'] as List?) ?? const [];

    final shells = <TankShellTrack>[];
    final booms = <TankBoom>[];
    final popups = <TankPopup>[];
    final hits = <TankHit>[];
    final damageByStage = <int, int>{};
    final directStages = <int>{};
    final shieldStages = <int>{};
    bool anyCrate = false;
    bool anyHeal = false;
    bool anyFallDamage = false;
    int maxStage = 0;
    final hpLoss = <int, int>{};
    final fallRows = <int, double>{};
    final moved = <int, Offset>{};

    for (final raw in events) {
      if (raw is! Map) continue;
      final e = Map<String, dynamic>.from(raw);
      final stage = (e['stage'] as num?)?.toInt() ?? 0;
      if (e['type'] == 'shell' || e['type'] == 'blast') {
        maxStage = math.max(maxStage, stage);
      }
      switch (e['type']) {
        case 'shell':
          final pts = ((e['path'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (p) => Offset(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ),
              )
              .toList();
          if (pts.length >= 2) shells.add(TankShellTrack(pts, stage, weapon));
          break;
        case 'blast':
          final r = (e['r'] as num?)?.toDouble() ?? 3;
          final kind = e['drill'] == true
              ? TankBoomKind.drill
              : weapon == 'quake'
              ? TankBoomKind.quake
              : TankBoomKind.blast;
          booms.add(
            TankBoom(
              (e['col'] as num).toDouble(),
              (e['row'] as num).toDouble(),
              r,
              stage,
              kind,
            ),
          );
          break;
        case 'mound':
          booms.add(
            TankBoom(
              (e['col'] as num).toDouble(),
              (e['row'] as num?)?.toDouble() ?? kTerrainH / 2,
              (e['r'] as num?)?.toDouble() ?? 4,
              stage,
              TankBoomKind.mound,
            ),
          );
          break;
        case 'split':
          booms.add(
            TankBoom(
              (e['col'] as num).toDouble(),
              (e['row'] as num).toDouble(),
              1.5,
              stage,
              TankBoomKind.split,
            ),
          );
          break;
        case 'teleport':
          moved[(e['target'] as num).toInt()] = Offset(
            (e['col'] as num).toDouble(),
            (e['row'] as num).toDouble(),
          );
          booms.add(
            TankBoom(
              (e['col'] as num).toDouble(),
              (e['row'] as num).toDouble(),
              3,
              stage,
              TankBoomKind.teleport,
            ),
          );
          popups.add(
            TankPopup(
              (e['target'] as num).toInt(),
              '순간이동!',
              TankUi.purple,
              stage,
              delayMs: 120,
            ),
          );
          break;
        case 'damage':
          final target = (e['target'] as num).toInt();
          final amount = (e['amount'] as num?)?.toInt() ?? 0;
          final direct = e['direct'] == true;
          hits.add(TankHit(target, stage, amount, direct));
          hpLoss[target] = (hpLoss[target] ?? 0) + amount;
          damageByStage[stage] = (damageByStage[stage] ?? 0) + amount;
          if (direct) directStages.add(stage);
          popups.add(
            TankPopup(
              target,
              direct ? '직격! -$amount' : '-$amount',
              direct ? const Color(0xFFFF3D3D) : const Color(0xFFFF8A4C),
              stage,
              size: direct ? 26 : 20,
            ),
          );
          break;
        case 'shield':
          shieldStages.add(stage);
          popups.add(
            TankPopup(
              (e['target'] as num).toInt(),
              '보호막 ${(e['absorbed'] as num?)?.toInt() ?? 0} 흡수',
              TankUi.cyan,
              stage,
              size: 15,
              delayMs: 260,
            ),
          );
          break;
        case 'crate':
          anyCrate = true;
          popups.add(
            TankPopup(
              (e['owner'] as num?)?.toInt() ?? 0,
              '${kTankCrateNames[e['item']] ?? '보급'} 획득!',
              TankUi.gold,
              -1,
              size: 15,
              delayMs: 320,
            ),
          );
          break;
        case 'heal':
          final healed = (e['amount'] as num?)?.toInt() ?? 0;
          if (healed > 0) {
            anyHeal = true;
            popups.add(
              TankPopup(
                (e['target'] as num).toInt(),
                e['cause'] == 'regen' ? '재생 +$healed' : '회복 +$healed',
                const Color(0xFF4CD787),
                -1,
                size: 15,
                delayMs: 520,
              ),
            );
          }
          break;
        case 'fall':
          final dmg = (e['damage'] as num?)?.toInt() ?? 0;
          final fallTarget = (e['target'] as num).toInt();
          fallRows[fallTarget] =
              (fallRows[fallTarget] ?? 0) +
              ((e['rows'] as num?)?.toDouble() ?? 0);
          hpLoss[fallTarget] = (hpLoss[fallTarget] ?? 0) + dmg;
          if (dmg > 0) {
            anyFallDamage = true;
            popups.add(
              TankPopup(
                (e['target'] as num).toInt(),
                '낙하 -$dmg',
                const Color(0xFFB07CFF),
                -1,
                size: 17,
                delayMs: 260,
              ),
            );
          }
          break;
        case 'sudden_death':
          popups.add(
            const TankPopup(
              -1,
              '서든데스! 피해 1.5배',
              Color(0xFFFF4D6D),
              -1,
              size: 22,
              delayMs: 600,
              col: kTerrainW / 2,
              row: 6,
            ),
          );
          break;
        default:
          break;
      }
    }

    // ── 단계별 시간 ──
    final stageStart = <double>[];
    final stageFlight = <double>[];
    double cursor = preRollMs;
    for (int s = 0; s <= maxStage; s++) {
      final longest = shells
          .where((sh) => sh.stage == s)
          .fold<int>(0, (m, sh) => math.max(m, sh.path.length));
      final double flight = longest == 0
          ? 0.0
          : (longest * (s == 0 ? 15.0 : 11.0)).clamp(450.0, 2400.0).toDouble();
      stageStart.add(cursor);
      stageFlight.add(flight);
      final onlySplit =
          booms.where((b) => b.stage == s).isNotEmpty &&
          booms
              .where((b) => b.stage == s)
              .every((b) => b.kind == TankBoomKind.split);
      cursor += flight + (onlySplit ? splitGapMs : boomMs);
    }
    double boomStartOf(int s) {
      if (stageStart.isEmpty) return preRollMs;
      final i = s.clamp(0, stageStart.length - 1);
      return stageStart[i] + stageFlight[i];
    }

    final lastBoom = boomStartOf(maxStage);
    // 단계가 -1인 팝업(보급·회복·낙하)은 마지막 폭발 뒤에 띄운다.
    final fixedPopups = [
      for (final p in popups)
        p.stage >= 0
            ? p
            : TankPopup(
                p.target,
                p.text,
                p.color,
                maxStage,
                size: p.size,
                delayMs: p.delayMs,
                col: p.col,
                row: p.row,
              ),
    ];

    // ── 격파 ──
    final cues = <TankSoundCue>[];
    final shakes = <TankShake>[];
    final flashes = <TankShake>[];
    double end = cursor;
    final prePlayers = (pre?['players'] as List?) ?? const [];
    for (int i = 0; i < prePlayers.length; i++) {
      final p = prePlayers[i];
      if (p is! Map) continue;
      final before = (p['hp'] as num?)?.toInt() ?? 1;
      final loss = hpLoss[i] ?? 0;
      if (before <= 0 || loss <= 0 || before - loss > 0) continue;
      final at =
          moved[i] ??
          Offset((p['col'] as num).toDouble(), (p['row'] as num).toDouble());
      const koDelay = 260.0;
      booms.add(
        TankBoom(
          at.dx,
          at.dy + (fallRows[i] ?? 0),
          6,
          maxStage,
          TankBoomKind.ko,
          delayMs: koDelay,
        ),
      );
      fixedPopups.add(
        TankPopup(
          i,
          '격파!',
          TankUi.gold,
          maxStage,
          size: 30,
          delayMs: koDelay + 80,
        ),
      );
      cues.add(TankSoundCue(lastBoom + koDelay, TankSound.explosionBig));
      cues.add(TankSoundCue(lastBoom + koDelay + 40, TankSound.clang, 0.7));
      shakes.add(TankShake(lastBoom + koDelay, 13, 700));
      flashes.add(TankShake(lastBoom + koDelay, 0.55, 260));
      end = math.max(end, lastBoom + koDelay + 1300);
    }

    // ── 효과음 ──
    cues.add(TankSoundCue(0, _fireSound(weapon)));
    if (stageFlight.isNotEmpty && stageFlight.first >= 600) {
      cues.add(TankSoundCue(stageStart.first + 60, TankSound.whistle, 0.55));
    }
    for (int s = 0; s <= maxStage; s++) {
      final at = boomStartOf(s);
      final stageBooms = booms.where(
        (b) => b.stage == s && b.kind != TankBoomKind.ko,
      );
      if (stageBooms.isEmpty) continue;
      final kinds = stageBooms.map((b) => b.kind).toSet();
      final maxR = stageBooms.fold<double>(0, (m, b) => math.max(m, b.radius));
      final dmg = damageByStage[s] ?? 0;
      if (kinds.contains(TankBoomKind.quake)) {
        cues.add(TankSoundCue(at, TankSound.explosionBig));
        shakes.add(TankShake(at, 16, 650));
        flashes.add(TankShake(at, 0.35, 200));
      } else if (kinds.contains(TankBoomKind.drill)) {
        cues.add(TankSoundCue(at - 120, TankSound.drill));
        cues.add(TankSoundCue(at, TankSound.explosion, 0.8));
        shakes.add(TankShake(at, 6 + dmg / 12, 360));
      } else if (kinds.contains(TankBoomKind.blast)) {
        final count = stageBooms
            .where((b) => b.kind == TankBoomKind.blast)
            .length;
        final sound = maxR >= 5
            ? TankSound.explosionBig
            : count > 1 || maxR <= 2.5
            ? TankSound.explosionSmall
            : TankSound.explosion;
        cues.add(TankSoundCue(at, sound));
        if (count > 1) {
          cues.add(TankSoundCue(at + 90, TankSound.explosionSmall, 0.7));
        }
        shakes.add(TankShake(at, 2.5 + maxR * 0.7 + dmg / 14, 340));
      }
      if (kinds.contains(TankBoomKind.mound)) {
        cues.add(TankSoundCue(at, TankSound.mound));
        shakes.add(TankShake(at, 3, 300));
      }
      if (kinds.contains(TankBoomKind.split)) {
        cues.add(TankSoundCue(at, TankSound.fireLight, 0.6));
      }
      if (kinds.contains(TankBoomKind.teleport)) {
        cues.add(TankSoundCue(at, TankSound.teleport));
      }
      if (directStages.contains(s)) {
        cues.add(TankSoundCue(at + 10, TankSound.clang, 0.8));
        shakes.add(TankShake(at, 9 + dmg / 10, 420));
        flashes.add(TankShake(at, 0.3, 160));
      }
      if (shieldStages.contains(s)) {
        cues.add(TankSoundCue(at + 200, TankSound.shield));
      }
    }
    if (anyFallDamage) cues.add(TankSoundCue(lastBoom + 260, TankSound.thud));
    if (anyCrate) cues.add(TankSoundCue(lastBoom + 320, TankSound.pickup));
    if (anyHeal) cues.add(TankSoundCue(lastBoom + 520, TankSound.heal, 0.8));
    cues.sort((a, b) => a.atMs.compareTo(b.atMs));

    // 직격 순간 짧게 멈춘다(타격감).
    final holds = <TankHold>[
      for (final s in directStages.toList()..sort())
        TankHold(boomStartOf(s) + 30, 110),
    ];

    final settle = booms.isEmpty
        ? lastBoom
        : booms.map((b) => boomStartOf(b.stage) + b.delayMs).reduce(math.max) +
              boomMs * 0.5;

    return TankPlayback._(
      shooter: shooter,
      weapon: weapon,
      angle: angle,
      shells: shells,
      booms: booms,
      popups: fixedPopups,
      hits: hits,
      cues: cues,
      shakes: shakes,
      flashes: flashes,
      holds: holds,
      stageStartMs: stageStart,
      stageFlightMs: stageFlight,
      totalMs: end + 450,
      settleMs: settle,
    );
  }

  static TankSound _fireSound(String weapon) => switch (weapon) {
    'heavy' || 'quake' => TankSound.fireHeavy,
    'triple' || 'shotgun' || 'cluster' => TankSound.fireLight,
    'teleport' => TankSound.fireLight,
    _ => TankSound.fire,
  };
}
