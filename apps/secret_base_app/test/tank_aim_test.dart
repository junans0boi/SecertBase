import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/arcade/games/tank/tank_aim.dart';
import 'package:secret_base_app/screens/arcade/games/tank/tank_battlefield.dart';

import 'tank_test_support.dart';

void main() {
  test('pulling down-left aims up-right (finger opposite the shot)', () {
    final r = TankAim.fromPull(const Offset(100, -100), 200); // anchor-finger
    expect(r.angle, 45);
    expect(r.power, closeTo(71, 1));
  });

  test('power clamps and angle never goes below horizon', () {
    expect(TankAim.fromPull(const Offset(900, 0), 200).power, 100);
    expect(TankAim.fromPull(const Offset(50, 40), 200).angle, 0);
    expect(TankAim.fromPull(const Offset(-50, 40), 200).angle, 180);
    expect(TankAim.fromPull(Offset.zero, 200).power, 1);
  });

  test('touch start keeps current angle/power (no jump)', () {
    const touch = Offset(120, 300);
    final a = TankAim.anchorFor(touch, angle: 60, power: 50, reach: 200);
    final r = TankAim.fromPull(a - touch, 200);
    expect(r.angle, 60);
    expect(r.power, 50);
    expect(a.dy < touch.dy, isTrue);
    expect(a.dx, closeTo(touch.dx + 100 * math.cos(math.pi / 3), 1e-6));
  });

  testWidgets('dragging down-left aims up-right via onAim', (tester) async {
    final terrain = tankTestTerrain();
    final state = <String, dynamic>{
      'phase': 'aiming',
      'turn': 0,
      'terrain': terrain,
      'players': [
        tankTestPlayer('a', terrain, col: 20),
        tankTestPlayer('b', terrain, col: 80, facingRight: false),
      ],
    };
    double? angle, power;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: TankBattlefield(
            state: state,
            myIndex: 0,
            playMs: () => 0,
            canAim: true,
            myAngle: 45,
            myPower: 50,
            onAim: (a, p) {
              angle = a;
              power = p;
            },
          ),
        ),
      ),
    );
    final g = await tester.startGesture(const Offset(200, 300));
    await g.moveBy(const Offset(-60, 60));
    await g.moveBy(const Offset(-20, 20));
    await tester.pump();
    expect(angle, isNotNull);
    expect(angle, lessThan(60));
    expect(angle, greaterThan(30));
    expect(power, greaterThan(50));
    await g.up();
    await tester.pump();
  });
}
