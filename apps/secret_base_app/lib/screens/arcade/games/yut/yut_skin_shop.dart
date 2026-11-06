import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'yut_palette.dart';
import 'yut_sticks.dart';

const _gradeOrder = {'B': 0, 'A': 1, 'S': 2, 'SS': 3, 'SSS': 4};

/// 윷 스킨 한 개의 효과(상점 카드용 짧은 이름, 미리보기용 긴 이름, 값 뒤에 붙는 단위).
class YutSkinEffect {
  final String short;
  final String long;
  final String value;

  const YutSkinEffect(this.short, this.long, this.value);
}

/// 아이템의 `stats`(서버가 주는 `[{key, value}]`)에서 첫 효과를 읽는다. 없으면 null.
YutSkinEffect? yutSkinEffect(Map<String, dynamic> item) {
  final stats = item['stats'];
  if (stats is! List || stats.isEmpty) return null;
  final first = stats.first;
  if (first is! Map) return null;
  final key = '${first['key']}';
  final v = num.tryParse('${first['value']}') ?? 0;
  final text = _fmt(v);
  return switch (key) {
    'yut_control_pct' => YutSkinEffect('윷·모', '윷·모 확률', '+$text%p'),
    'yut_mo_rate_pct' => YutSkinEffect('모', '모 확률', '+$text%p'),
    'piece_catch_resist_pct' => YutSkinEffect('방어', '잡힘 방어', '+$text%'),
    'yut_backdo_shield_pct' => YutSkinEffect('빽도', '빽도 방어', '+$text%'),
    'yut_win_coin_pct' => YutSkinEffect('코인', '윷·모 코인 보너스', '+$text%'),
    'yut_overturn_pct' => YutSkinEffect('역전', '지고 있을 때 윷·모 확률', '+$text%p'),
    _ => null,
  };
}

String _fmt(num value) {
  final v = value.toDouble();
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// 상점의 윷 스킨 화면: 위에 고른 스킨(처음엔 장착 중인 것)을 크게 보여 주고,
/// 아래에 등급 순으로 윷가락 모양이 그려진 카드를 3열로 늘어놓는다.
/// 카드를 누르면 위 미리보기가 바뀌고, 기존 구매/장착 시트도 함께 열린다.
class YutSkinShop extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Set<int> ownedIds;
  final Set<int> equippedIds;
  final String Function(int) formatCoins;
  final void Function(Map<String, dynamic>) onItemTap;

  const YutSkinShop({
    super.key,
    required this.items,
    required this.ownedIds,
    required this.equippedIds,
    required this.formatCoins,
    required this.onItemTap,
  });

  @override
  State<YutSkinShop> createState() => _YutSkinShopState();
}

class _YutSkinShopState extends State<YutSkinShop> {
  int? _selected;

  int _id(Map<String, dynamic> i) => (i['id'] as num).toInt();

  List<Map<String, dynamic>> get _sorted {
    final list = [...widget.items];
    list.sort((a, b) {
      final g = (_gradeOrder['${a['grade']}'] ?? 9).compareTo(
        _gradeOrder['${b['grade']}'] ?? 9,
      );
      return g != 0 ? g : _id(a).compareTo(_id(b));
    });
    return list;
  }

  Map<String, dynamic> _hero(List<Map<String, dynamic>> list) {
    for (final i in list) {
      if (_id(i) == _selected) return i;
    }
    for (final i in list) {
      if (widget.equippedIds.contains(_id(i))) return i;
    }
    return list.first;
  }

  @override
  Widget build(BuildContext context) {
    const p = YutPalette.daylight;
    final list = _sorted;
    final hero = _hero(list);
    return YutPaletteScope(
      palette: p,
      child: Container(
        key: const ValueKey('yut_skin_shop'),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 18)],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GameBackdrop(
                theme: p.theme,
                frame: false,
                child: const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Hero(
                    p: p,
                    item: hero,
                    owned: widget.ownedIds.contains(_id(hero)),
                    equipped: widget.equippedIds.contains(_id(hero)),
                    formatCoins: widget.formatCoins,
                    onTap: () => widget.onItemTap(hero),
                  ),
                  const SizedBox(height: 10),
                  for (var row = 0; row < (list.length + 2) ~/ 3; row++) ...[
                    if (row > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < 3; col++) ...[
                          if (col > 0) const SizedBox(width: 8),
                          Expanded(
                            child: row * 3 + col < list.length
                                ? _Card(
                                    p: p,
                                    item: list[row * 3 + col],
                                    selected:
                                        _id(list[row * 3 + col]) == _id(hero),
                                    owned: widget.ownedIds.contains(
                                      _id(list[row * 3 + col]),
                                    ),
                                    equipped: widget.equippedIds.contains(
                                      _id(list[row * 3 + col]),
                                    ),
                                    formatCoins: widget.formatCoins,
                                    onTap: () {
                                      final item = list[row * 3 + col];
                                      setState(() => _selected = _id(item));
                                      widget.onItemTap(item);
                                    },
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _gradeFill(String grade) => switch (grade) {
  'SSS' => const Color(0xFFFF5FA8),
  'SS' => const Color(0xFF8E52F2),
  'S' => const Color(0xFFE5A019),
  'A' => const Color(0xFF8A96B3),
  _ => const Color(0xFF6FA583),
};

class _GradeTag extends StatelessWidget {
  final String grade;

  const _GradeTag(this.grade);

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: _gradeFill(grade),
        gradient: grade == 'SSS'
            ? const LinearGradient(
                colors: [
                  Color(0xFFFF5FA8),
                  Color(0xFF8E52F2),
                  Color(0xFF3FA6FF),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        grade,
        style: p.display(size: 14, color: Colors.white, height: 1.2),
      ),
    );
  }
}

/// 가격·보유·장착 상태 알약.
class _StatusChip extends StatelessWidget {
  final YutPalette p;
  final Map<String, dynamic> item;
  final bool owned;
  final bool equipped;
  final String Function(int) formatCoins;
  final bool large;

  const _StatusChip({
    required this.p,
    required this.item,
    required this.owned,
    required this.equipped,
    required this.formatCoins,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final grade = '${item['grade']}';
    final gachaOnly = price <= 0 && grade != 'B' && grade != 'A';
    final size = large ? 17.0 : 14.0;
    final pad = EdgeInsets.symmetric(
      horizontal: large ? 18 : 9,
      vertical: large ? 11 : 6,
    );
    if (equipped) {
      return Container(
        padding: pad,
        decoration: BoxDecoration(
          color: p.acc.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (large) ...[
              Icon(Icons.check_rounded, size: size + 2, color: p.accText),
              const SizedBox(width: 3),
            ],
            Text(
              '장착 중',
              style: p.display(size: size, color: p.accText),
            ),
          ],
        ),
      );
    }
    if (owned) {
      return Container(
        padding: pad,
        decoration: BoxDecoration(
          color: p.sub.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '보유',
          style: p.display(size: size, color: p.sub),
        ),
      );
    }
    if (gachaOnly) {
      return Container(
        padding: pad,
        decoration: BoxDecoration(
          color: _gradeFill(grade).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '뽑기 전용',
          style: p.display(size: size, color: _gradeFill(grade)),
        ),
      );
    }
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: p.acc,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: p.acc2, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD35A),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            formatCoins(price),
            style: p.display(size: size, color: p.onAcc),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final YutPalette p;
  final Map<String, dynamic> item;
  final bool owned;
  final bool equipped;
  final String Function(int) formatCoins;
  final VoidCallback onTap;

  const _Hero({
    required this.p,
    required this.item,
    required this.owned,
    required this.equipped,
    required this.formatCoins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final look = YutStickLook.fromItem(item);
    final effect = yutSkinEffect(item);
    final grade = '${item['grade']}';
    return Container(
      key: const ValueKey('yut_skin_hero'),
      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: p.panelEdge, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            height: 120,
            child: YutSkinSticks(look: look, seed: 3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _GradeTag(grade),
                const SizedBox(height: 4),
                Text(
                  '${item['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.display(size: 26),
                ),
                if (effect != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${effect.long} '),
                        TextSpan(
                          text: effect.value,
                          style: TextStyle(color: p.accText),
                        ),
                      ],
                    ),
                    style: p.body(size: 14, weight: FontWeight.w800),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${item['description'] ?? ''}'.split(' · ').first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(size: 12, color: p.sub, height: 1.3),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  key: const ValueKey('yut_skin_hero_action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    child: _StatusChip(
                      p: p,
                      item: item,
                      owned: owned,
                      equipped: equipped,
                      formatCoins: formatCoins,
                      large: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final YutPalette p;
  final Map<String, dynamic> item;
  final bool selected;
  final bool owned;
  final bool equipped;
  final String Function(int) formatCoins;
  final VoidCallback onTap;

  const _Card({
    required this.p,
    required this.item,
    required this.selected,
    required this.owned,
    required this.equipped,
    required this.formatCoins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final look = YutStickLook.fromItem(item);
    final effect = yutSkinEffect(item);
    final grade = '${item['grade']}';
    final high = (_gradeOrder[grade] ?? 0) >= 2;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${item['name']}, $grade등급${effect == null ? '' : ', ${effect.long} ${effect.value}'}',
      child: GestureDetector(
        key: ValueKey('shop_item_${item['id']}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 164,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? p.acc
                  : high
                  ? _gradeFill(grade).withValues(alpha: 0.4)
                  : Colors.transparent,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected ? p.acc2 : p.panelEdge,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _GradeTag(grade),
                ),
              ),
              SizedBox(
                height: 54,
                width: 76,
                child: YutSkinSticks(look: look, seed: 5),
              ),
              const SizedBox(height: 4),
              Text(
                '${item['name'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.display(size: 16),
              ),
              if (effect != null)
                Text(
                  '${effect.short} ${effect.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(size: 12, color: p.sub),
                ),
              const Spacer(),
              _StatusChip(
                p: p,
                item: item,
                owned: owned,
                equipped: equipped,
                formatCoins: formatCoins,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 윷가락 네 개를 세워 놓은 그림(상점 카드·미리보기). 스킨의 색·무늬·빛·반짝임을 그대로 쓴다.
class YutSkinSticks extends StatelessWidget {
  final YutStickLook look;
  final int seed;

  const YutSkinSticks({super.key, required this.look, this.seed = 1});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkinSticksPainter(look, seed),
      size: Size.infinite,
    );
  }
}

class _SkinSticksPainter extends CustomPainter {
  final YutStickLook look;
  final int seed;

  _SkinSticksPainter(this.look, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 바닥 그림자
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.95),
        width: w * 0.9,
        height: h * 0.12,
      ),
      Paint()
        ..color = const Color(0x333C5F96)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final stickW = w * 0.13;
    final stickH = h * 0.86;
    final rng = math.Random(seed);
    if (look.glow != null) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.5),
          width: w * 1.0,
          height: h * 0.9,
        ),
        Paint()
          ..color = look.glow!.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
      );
    }
    for (var i = 0; i < 4; i++) {
      final cx = w * (0.17 + 0.222 * i);
      final tilt = (i - 1.5) * 0.045;
      canvas.save();
      canvas.translate(cx, h * 0.5);
      canvas.rotate(tilt);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: stickW, height: stickH),
        Radius.circular(stickW / 2),
      );
      // 옆면(그림자 쪽)
      canvas.drawRRect(
        body.shift(Offset(stickW * 0.1, stickW * 0.05)),
        Paint()..color = look.round,
      );
      canvas.drawRRect(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(look.flat, Colors.white, 0.35)!,
              look.flat,
              Color.lerp(look.flat, look.round, 0.35)!,
            ],
          ).createShader(body.outerRect),
      );
      final grain = Paint()
        ..color = look.grain.withValues(alpha: 0.35)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      for (final dx in [-0.2, 0.15]) {
        canvas.drawLine(
          Offset(stickW * dx, -stickH * 0.42),
          Offset(stickW * dx, stickH * 0.42),
          grain,
        );
      }
      if (look.stripe != null) {
        final stripe = Paint()
          ..color = look.stripe!.withValues(alpha: 0.7)
          ..strokeWidth = math.max(1.6, stickW * 0.12)
          ..strokeCap = StrokeCap.round;
        for (final dy in [-0.28, 0.0, 0.28]) {
          canvas.drawLine(
            Offset(-stickW * 0.3, stickH * dy + stickW * 0.1),
            Offset(stickW * 0.3, stickH * dy - stickW * 0.1),
            stripe,
          );
        }
      }
      if (look.glassy) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-stickW * 0.18, 0),
              width: stickW * 0.22,
              height: stickH * 0.8,
            ),
            Radius.circular(stickW * 0.1),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }
      if (i == 1) {
        final mark = Paint()
          ..color = const Color(0xFFD83A2E)
          ..strokeWidth = math.max(1.8, stickW * 0.14)
          ..strokeCap = StrokeCap.round;
        final a = stickW * 0.22;
        final my = stickH * 0.18;
        canvas.drawLine(Offset(-a, my - a), Offset(a, my + a), mark);
        canvas.drawLine(Offset(-a, my + a), Offset(a, my - a), mark);
      }
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x992A1A0A),
      );
      if (look.sparkle) {
        for (var k = 0; k < 2; k++) {
          final py = (rng.nextDouble() - 0.5) * stickH * 0.7;
          final r = stickW * (0.2 + 0.12 * rng.nextDouble());
          final color = look.rainbow
              ? HSVColor.fromAHSV(
                  1,
                  (i * 70 + k * 130) % 360.0,
                  0.5,
                  1,
                ).toColor()
              : Colors.white;
          final star = Path()
            ..moveTo(0, py - r)
            ..quadraticBezierTo(0, py, r, py)
            ..quadraticBezierTo(0, py, 0, py + r)
            ..quadraticBezierTo(0, py, -r, py)
            ..quadraticBezierTo(0, py, 0, py - r);
          canvas.drawPath(star, Paint()..color = color);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SkinSticksPainter old) =>
      old.look.id != look.id || old.seed != seed;
}
