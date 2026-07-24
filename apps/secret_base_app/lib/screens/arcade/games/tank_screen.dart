import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/main_design.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

// Engine constants mirrored from fortress-engine.js
const int kTerrainW = 100;
const int kTerrainH = 40;

class TankScreen extends StatefulWidget {
  const TankScreen({super.key});
  @override
  State<TankScreen> createState() => _TankScreenState();
}

class _TankScreenState extends State<TankScreen> with TickerProviderStateMixin {
  final _socket = SocketService();

  // Local aim — synced from server after each turn, edited locally while aiming
  double _localAngle = 45;
  double _localPower = 50;
  String _selectedWeapon = 'basic';

  // Track the last shot we've animated to avoid replaying
  Object? _lastAnimatedShot;

  late final AnimationController _explosionCtrl;

  static const _weaponNames = {
    'basic': '기본탄',
    'heavy': '대형탄',
    'triple': '3연발탄',
    'mole': '두더지탄',
  };

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);

    _explosionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() => setState(() {}));

    // Start a new game
    _socket.startTank(stake: _socket.lobbyStartedStake);
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    _explosionCtrl.dispose();
    super.dispose();
  }

  void _onSocket() {
    if (!mounted) return;

    // New shot arrived — animate explosion once
    final shot = _socket.tankLastShot;
    if (shot != null && !identical(shot, _lastAnimatedShot)) {
      _lastAnimatedShot = shot;
      _explosionCtrl.reset();
      _explosionCtrl.forward();
    }

    // Sync local aim to new server state (after turn end)
    final myPlayer = _myPlayer();
    if (myPlayer != null) {
      _localAngle = (myPlayer['angle'] as num).toDouble();
      _localPower = (myPlayer['power'] as num).toDouble();
      _selectedWeapon = myPlayer['weapon'] as String? ?? 'basic';
    }

    setState(() {});
  }

  Map<String, dynamic>? _myPlayer() {
    final players = _socket.tankState?['players'] as List?;
    if (players == null) return null;
    for (final p in players) {
      if ((p as Map)['id'] == _socket.userId) {
        return Map<String, dynamic>.from(p);
      }
    }
    return null;
  }

  bool get _isMyTurn {
    final state = _socket.tankState;
    if (state == null) return false;
    final players = state['players'] as List?;
    if (players == null) return false;
    final turnIdx = state['turn'] as int? ?? 0;
    return (players[turnIdx] as Map)['id'] == _socket.userId;
  }

  void _sendAim() {
    _socket.aimTank(_localAngle.round(), _localPower.round());
  }

  void _move(int delta) => _socket.moveTank(delta);

  void _fire() => _socket.fireTank();

  void _selectWeapon(String w) {
    setState(() => _selectedWeapon = w);
    _socket.selectTankWeapon(w);
  }

  @override
  Widget build(BuildContext context) {
    final state = _socket.tankState;
    final winner = _socket.tankWinner;

    return GameScaffold(
      title: '탱크 대작전',
      fullBleed: true,
      child: state == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusBar(state),
                Expanded(child: _buildBattlefield(state, winner)),
                if (winner == null && state['phase'] != 'result')
                  _buildControls(state),
              ],
            ),
    );
  }

  Widget _buildStatusBar(Map<String, dynamic> state) {
    final players = state['players'] as List;
    final p0 = players[0] as Map;
    final p1 = players[1] as Map;
    final wind = (state['wind'] as num).toDouble();
    final turn = state['turn'] as int;
    final turnNum = (state['turnNumber'] as int? ?? 0) + 1;
    final windDir = wind >= 0 ? '→' : '←';

    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _HpBar(label: 'P1', hp: (p0['hp'] as num).toInt(), active: turn == 0),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('바람 $windDir ${wind.abs().toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 11, color: kMainSub)),
                Text('$turnNum턴',
                    style: TextStyle(fontSize: 10, color: kMainMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HpBar(
            label: 'P2',
            hp: (p1['hp'] as num).toInt(),
            active: turn == 1,
            reverse: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBattlefield(Map<String, dynamic> state, String? winner) {
    final terrain = (state['terrain'] as List).cast<int>();
    final players = (state['players'] as List).cast<Map>();
    final shot = _socket.tankLastShot;
    final exploding = _explosionCtrl.isAnimating || _explosionCtrl.value > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _BattlefieldPainter(
              terrain: terrain,
              players: players,
              lastShot: shot,
              showExplosion: exploding,
              explosionProgress: _explosionCtrl.value,
              myUserId: _socket.userId ?? '',
            ),
          ),
        ),
        if (winner != null) _buildResultOverlay(winner),
      ],
    );
  }

  Widget _buildResultOverlay(String winner) {
    final isWin = winner == _socket.userId;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWin ? '승리!' : '패배...',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: isWin ? kMainHoney : kMainRose,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(Map<String, dynamic> state) {
    final myTurn = _isMyTurn;
    final myPlayer = _myPlayer();
    final fuel = myPlayer != null ? (myPlayer['fuel'] as num).toInt() : 0;
    final ammo = myPlayer?['ammo'] as Map?;

    return Container(
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weapon picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _weaponNames.entries.map((e) {
                final rawCount = ammo?[e.key];
                final isInf = rawCount == null ||
                    rawCount == double.infinity ||
                    (rawCount is num && rawCount > 900);
                final count = isInf ? '∞' : '$rawCount';
                final hasAmmo = isInf || (rawCount != null && (rawCount as num) > 0);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _WeaponChip(
                    label: e.value,
                    count: count,
                    selected: _selectedWeapon == e.key,
                    enabled: myTurn && hasAmmo,
                    onTap: (myTurn && hasAmmo) ? () => _selectWeapon(e.key) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Angle slider
          Row(
            children: [
              SizedBox(width: 34, child: Text('각도', style: TextStyle(fontSize: 11, color: kMainMuted))),
              Expanded(
                child: Slider(
                  value: _localAngle,
                  min: 0,
                  max: 180,
                  divisions: 180,
                  onChanged: myTurn
                      ? (v) { setState(() => _localAngle = v); _sendAim(); }
                      : null,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${_localAngle.round()}°',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          // Power slider
          Row(
            children: [
              SizedBox(width: 34, child: Text('파워', style: TextStyle(fontSize: 11, color: kMainMuted))),
              Expanded(
                child: Slider(
                  value: _localPower,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  onChanged: myTurn
                      ? (v) { setState(() => _localPower = v); _sendAim(); }
                      : null,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${_localPower.round()}',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          // Move + fire row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: myTurn ? () => _move(-2) : null,
                tooltip: '이동 ←',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('연료 $fuel',
                    style: TextStyle(fontSize: 11, color: kMainMuted)),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                onPressed: myTurn ? () => _move(2) : null,
                tooltip: '이동 →',
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.rocket_launch, size: 16),
                label: const Text('발사!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: myTurn ? kMainHoney : kMainMuted,
                  foregroundColor: Colors.white,
                ),
                onPressed: myTurn ? _fire : null,
              ),
            ],
          ),
          if (!myTurn)
            Text('상대방 턴 대기 중...',
                style: TextStyle(fontSize: 11, color: kMainMuted)),
        ],
      ),
    );
  }
}

// ── CustomPainter ────────────────────────────────────────────────────────────

class _BattlefieldPainter extends CustomPainter {
  final List<int> terrain;
  final List<Map> players;
  final Map<String, dynamic>? lastShot;
  final bool showExplosion;
  final double explosionProgress;
  final String myUserId;

  const _BattlefieldPainter({
    required this.terrain,
    required this.players,
    required this.lastShot,
    required this.showExplosion,
    required this.explosionProgress,
    required this.myUserId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / kTerrainW;
    final cellH = size.height / kTerrainH;

    // Sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1a2a4a), Color(0xFF2d4a7a)],
      ).createShader(Rect.fromLTWH(0, 0, 1, 1));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Stars (static)
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
    final rand = math.Random(42);
    for (int i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height * 0.6),
        0.8,
        starPaint,
      );
    }

    // Terrain
    final terrainPaint = Paint()..color = const Color(0xFF3a6a2a);
    final terrainTopPaint = Paint()..color = const Color(0xFF5a9a4a);

    for (int x = 0; x < kTerrainW; x++) {
      final h = terrain[x];
      final surfaceRow = kTerrainH - h;
      final top = surfaceRow * cellH;
      canvas.drawRect(
        Rect.fromLTWH(x * cellW, top + 3, cellW + 0.5, size.height - top),
        terrainPaint,
      );
      // Grass top strip
      canvas.drawRect(
        Rect.fromLTWH(x * cellW, top, cellW + 0.5, 3),
        terrainTopPaint,
      );
    }

    // Trajectory lines
    if (lastShot != null) {
      final paths = lastShot!['paths'] as List?;
      if (paths != null) {
        final trajPaint = Paint()
          ..color = Colors.yellow.withValues(alpha: 0.55)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        for (final pts in paths) {
          final ptList = (pts as List);
          if (ptList.length < 2) continue;
          final trajPath = Path();
          for (int i = 0; i < ptList.length; i++) {
            final pt = ptList[i] as Map;
            final px = (pt['x'] as num).toDouble() * cellW;
            final py = (pt['y'] as num).toDouble() * cellH;
            if (i == 0) { trajPath.moveTo(px, py); } else { trajPath.lineTo(px, py); }
          }
          canvas.drawPath(trajPath, trajPaint);
        }
      }
    }

    // Explosion
    if (showExplosion && lastShot != null) {
      final impact = lastShot!['impact'] as Map?;
      final blastR = (lastShot!['blastR'] as num?)?.toDouble() ?? 3.0;
      if (impact != null) {
        final ix = (impact['col'] as num).toDouble() * cellW;
        final iy = (impact['row'] as num).toDouble() * cellH;
        final progress = explosionProgress;
        final alpha = (1.0 - progress).clamp(0.0, 1.0);
        final radius = blastR * cellW * (1.0 + progress * 2.0);

        canvas.drawCircle(
          Offset(ix, iy),
          radius,
          Paint()..color = Colors.orange.withValues(alpha: alpha * 0.85),
        );
        canvas.drawCircle(
          Offset(ix, iy),
          radius * 0.55,
          Paint()..color = Colors.yellow.withValues(alpha: alpha * 0.9),
        );
        canvas.drawCircle(
          Offset(ix, iy),
          radius * 0.25,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.7),
        );
      }
    }

    // Tanks
    for (int pi = 0; pi < players.length; pi++) {
      final p = players[pi];
      final col = (p['col'] as num).toDouble();
      final row = (p['row'] as num).toDouble();
      final isMe = p['id'] == myUserId;
      final hp = (p['hp'] as num).toInt();
      final angle = (p['angle'] as num?)?.toDouble() ?? 45.0;
      _drawTank(canvas, col * cellW, row * cellH, cellW, cellH, isMe, hp, angle);
    }
  }

  void _drawTank(Canvas canvas, double px, double py, double cw, double ch,
      bool isMe, int hp, double angle) {
    final color = isMe ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final bodyPaint = Paint()..color = color;
    final trackPaint = Paint()..color = color.withValues(alpha: 0.65);

    // Tracks
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(px, py + ch * 0.7), width: cw * 4.2, height: ch * 0.55),
        const Radius.circular(2),
      ),
      trackPaint,
    );
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(px, py), width: cw * 3.2, height: ch * 1.1),
        const Radius.circular(3),
      ),
      bodyPaint,
    );
    // Turret dome
    canvas.drawCircle(Offset(px, py - ch * 0.35), cw * 1.1, bodyPaint);

    // Barrel (angle from engine is degrees, 0=right, 90=up, 180=left)
    final radians = -angle * math.pi / 180.0;
    final barrelLen = cw * 2.4;
    final barrelEnd = Offset(
      px + math.cos(radians) * barrelLen,
      py - ch * 0.35 + math.sin(radians) * barrelLen,
    );
    canvas.drawLine(
      Offset(px, py - ch * 0.35),
      barrelEnd,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = cw * 0.9
        ..strokeCap = StrokeCap.round,
    );

    // HP text
    final tp = TextPainter(
      text: TextSpan(
        text: '$hp',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(px - tp.width / 2, py - ch * 2.8));
  }

  @override
  bool shouldRepaint(_BattlefieldPainter old) =>
      old.terrain != terrain ||
      old.showExplosion != showExplosion ||
      old.explosionProgress != explosionProgress ||
      old.lastShot != lastShot ||
      old.players != players;
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HpBar extends StatelessWidget {
  final String label;
  final int hp;
  final bool active;
  final bool reverse;
  const _HpBar({
    required this.label,
    required this.hp,
    required this.active,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = hp > 50
        ? const Color(0xFF4CAF50)
        : hp > 25
            ? Colors.orange
            : Colors.red;
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: active ? FontWeight.w900 : FontWeight.w400,
      color: active ? kMainHoney : kMainMuted,
    );
    final hpStyle = TextStyle(fontSize: 9, color: kMainMuted);
    final bar = SizedBox(
      width: 70,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: hp / 100.0,
          backgroundColor: kMainMuted.withValues(alpha: 0.25),
          valueColor: AlwaysStoppedAnimation(barColor),
        ),
      ),
    );

    final items = [
      Text(label, style: labelStyle),
      const SizedBox(height: 2),
      bar,
      Text('$hp HP', style: hpStyle),
    ];

    return Column(
      crossAxisAlignment:
          reverse ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }
}

class _WeaponChip extends StatelessWidget {
  final String label;
  final String count;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _WeaponChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? kMainHoney : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? kMainHoney
                : kMainMuted.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : enabled
                        ? const Color(0xFF222233)
                        : kMainMuted,
              ),
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.white70 : kMainMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
