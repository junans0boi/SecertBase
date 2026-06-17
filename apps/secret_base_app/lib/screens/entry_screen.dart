import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../core/socket_service.dart';

const _defaultUrl = String.fromEnvironment('SOCKET_URL', defaultValue: 'http://localhost:4100');

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> with SingleTickerProviderStateMixin {
  final _urlCtrl = TextEditingController(text: _defaultUrl);
  final _roomCtrl = TextEditingController(text: 'secret-room');
  final _secretCtrl = TextEditingController(text: 'secretbase');
  String _selectedUser = 'jun';
  bool _connecting = false;
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
    _socket.addListener(_onSocketChange);
  }

  @override
  void dispose() {
    _anim.dispose();
    _urlCtrl.dispose();
    _roomCtrl.dispose();
    _secretCtrl.dispose();
    _socket.removeListener(_onSocketChange);
    super.dispose();
  }

  void _onSocketChange() {
    if (!mounted) return;
    setState(() => _connecting = false);
  }

  void _connect() {
    if (_connecting) return;
    setState(() => _connecting = true);
    _socket.connect(
      _urlCtrl.text.trim(),
      _roomCtrl.text.trim(),
      _secretCtrl.text.trim(),
      _selectedUser,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 40),
                        _buildCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.2,
          colors: [
            kPrimary.withOpacity(0.15),
            kBg,
          ],
        ),
      ),
      child: CustomPaint(painter: _StarPainter()),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: kPrimaryGrad,
            boxShadow: [
              BoxShadow(color: kPrimary.withOpacity(0.4), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: const Center(
            child: Text('🔐', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '비밀기지',
          style: GoogleFonts.notoSans(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: kText,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'SECRET BASE · 우리만의 공간',
          style: GoogleFonts.notoSans(
            fontSize: 12,
            color: kTextMuted,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('서버 주소'),
          const SizedBox(height: 6),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: kText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'http://localhost:4100',
              prefixIcon: Icon(Icons.dns_outlined, color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          _label('방 코드'),
          const SizedBox(height: 6),
          TextField(
            controller: _roomCtrl,
            style: const TextStyle(color: kText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'secret-room',
              prefixIcon: Icon(Icons.meeting_room_outlined, color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          _label('비밀번호'),
          const SizedBox(height: 6),
          TextField(
            controller: _secretCtrl,
            obscureText: true,
            style: const TextStyle(color: kText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: '••••••••',
              prefixIcon: Icon(Icons.lock_outline, color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          _label('나는 누구?'),
          const SizedBox(height: 10),
          Row(
            children: [
              _userChip('jun', '💙 준'),
              const SizedBox(width: 12),
              _userChip('gf', '🩷 GF'),
            ],
          ),
          const SizedBox(height: 28),
          if (_socket.status != '대기 중' && !_socket.isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kError.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kError.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: kError, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _socket.status,
                        style: const TextStyle(color: kError, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildConnectButton(),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.notoSans(
        color: kTextMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _userChip(String value, String label) {
    final selected = _selectedUser == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedUser = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? kPrimary.withOpacity(0.15) : kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kPrimary : kBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.notoSans(
                color: selected ? kPrimary : kTextMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _connecting ? null : kPrimaryGrad,
          color: _connecting ? kBorder : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _connecting
              ? null
              : [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: MaterialButton(
          onPressed: _connecting ? null : _connect,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: _connecting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimary),
                )
              : Text(
                  '입장하기',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    const stars = [
      (0.1, 0.12), (0.85, 0.08), (0.45, 0.05), (0.72, 0.18),
      (0.25, 0.22), (0.6, 0.28), (0.9, 0.35), (0.05, 0.45),
      (0.38, 0.55), (0.78, 0.62), (0.18, 0.75), (0.55, 0.82),
      (0.92, 0.88), (0.33, 0.91), (0.67, 0.95),
    ];
    for (final (x, y) in stars) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
