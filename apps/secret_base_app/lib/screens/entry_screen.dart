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
  final _urlCtrl    = TextEditingController(text: _defaultUrl);
  final _roomCtrl   = TextEditingController(text: 'secret-room');
  final _secretCtrl = TextEditingController(text: 'secretbase');
  String _user      = 'jun';
  bool _connecting  = false;

  late AnimationController _anim;
  late Animation<double> _fadeIn;
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
    _socket.addListener(_onSocket);
  }

  @override
  void dispose() {
    _anim.dispose();
    _urlCtrl.dispose();
    _roomCtrl.dispose();
    _secretCtrl.dispose();
    _socket.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    if (!mounted) return;
    setState(() => _connecting = false);
  }

  void _connect() {
    if (_connecting) return;
    FocusScope.of(context).unfocus();
    setState(() => _connecting = true);
    _socket.connect(_urlCtrl.text.trim(), _roomCtrl.text.trim(), _secretCtrl.text.trim(), _user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // 배경 그라데이션
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFE4EF), Color(0xFFFFF5F8), Color(0xFFFFEBF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 하트 장식
          const _Decoration(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 36),
                        _buildForm(),
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

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: kPrimaryGrad,
            boxShadow: [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: const Center(child: Text('💌', style: TextStyle(fontSize: 40))),
        ),
        const SizedBox(height: 20),
        Text(
          '비밀기지',
          style: GoogleFonts.notoSans(fontSize: 34, fontWeight: FontWeight.w900, color: kText, letterSpacing: -1),
        ),
        const SizedBox(height: 6),
        Text(
          '우리 둘만의 공간 💕',
          style: GoogleFonts.notoSans(fontSize: 14, color: kTextSub),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: kPrimary.withAlpha(20), blurRadius: 32, offset: const Offset(0, 8)),
          const BoxShadow(color: Colors.white, blurRadius: 0, offset: Offset(0, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('서버 주소'),
          const SizedBox(height: 6),
          TextField(
            controller: _urlCtrl,
            style: GoogleFonts.notoSans(color: kText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'http://192.168.x.x:4100',
              prefixIcon: Icon(Icons.dns_outlined, color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          _label('방 코드'),
          const SizedBox(height: 6),
          TextField(
            controller: _roomCtrl,
            style: GoogleFonts.notoSans(color: kText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'secret-room',
              prefixIcon: Icon(Icons.favorite_border, color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          _label('비밀번호'),
          const SizedBox(height: 6),
          TextField(
            controller: _secretCtrl,
            obscureText: true,
            style: GoogleFonts.notoSans(color: kText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: '••••••••',
              prefixIcon: Icon(Icons.lock_outline, color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          _label('나는 누구?'),
          const SizedBox(height: 10),
          Row(children: [
            _userTile('jun', '💙 준'),
            const SizedBox(width: 10),
            _userTile('gf', '🩷 GF'),
          ]),
          const SizedBox(height: 24),
          if (_socket.status != '대기 중' && !_socket.isConnected && !_connecting)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kError.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kError.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: kError, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_socket.status, style: GoogleFonts.notoSans(color: kError, fontSize: 13))),
                ]),
              ),
            ),
          _buildBtn(),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4),
  );

  Widget _userTile(String val, String label) {
    final sel = _user == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _user = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sel ? kPrimary.withAlpha(20) : const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? kPrimary : kBorder, width: sel ? 1.5 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.notoSans(
                color: sel ? kPrimary : kTextSub,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBtn() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _connecting ? null : kPrimaryGrad,
          color: _connecting ? kBorder : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _connecting ? null : [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: MaterialButton(
          onPressed: _connecting ? null : _connect,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: _connecting
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimary))
            : Text('우리 방 입장 💌', style: GoogleFonts.notoSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _Decoration extends StatelessWidget {
  const _Decoration();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _HeartPainter(),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFB6D1).withAlpha(50);
    const hearts = [(0.1, 0.08), (0.88, 0.12), (0.05, 0.55), (0.92, 0.48), (0.5, 0.04), (0.75, 0.85), (0.2, 0.92)];
    for (final (x, y) in hearts) {
      final cx = size.width * x;
      final cy = size.height * y;
      _drawHeart(canvas, paint, cx, cy, 12);
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path()
      ..moveTo(cx, cy + r * 0.3)
      ..cubicTo(cx, cy - r * 0.5, cx - r, cy - r * 0.5, cx - r, cy)
      ..cubicTo(cx - r, cy + r * 0.8, cx, cy + r * 1.2, cx, cy + r * 1.4)
      ..cubicTo(cx, cy + r * 1.2, cx + r, cy + r * 0.8, cx + r, cy)
      ..cubicTo(cx + r, cy - r * 0.5, cx, cy - r * 0.5, cx, cy + r * 0.3)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
