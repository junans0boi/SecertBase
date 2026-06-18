import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/main_design.dart';
import '../core/socket_service.dart';

const _defaultUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://localhost:4100',
);

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  final _urlCtrl = TextEditingController(text: _defaultUrl);
  final _roomCtrl = TextEditingController(text: 'secret-room');
  final _secretCtrl = TextEditingController(text: 'secretbase');
  String _user = 'jun';
  bool _connecting = false;

  late final AnimationController _anim;
  late final Animation<double> _fadeIn;
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
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
    _socket.connect(
      _urlCtrl.text.trim(),
      _roomCtrl.text.trim(),
      _secretCtrl.text.trim(),
      _user,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      body: CozyPage(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [_intro(), const SizedBox(height: 22), _form()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Column(
      children: [
        Text(
          '답변 속 진심을 먹고 자라요',
          style: mainTitle(size: 20, color: kMainSub, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text('두 분만의 비밀기지', style: mainTitle(size: 34)),
        const SizedBox(height: 22),
        SizedBox(
          height: 152,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 40, top: 22, child: _softHeart(kMainSky, 18)),
              Positioned(right: 48, top: 18, child: _softHeart(kMainRose, 14)),
              Positioned(
                left: 82,
                bottom: 20,
                child: _softHeart(kMainRose, 10),
              ),
              Positioned(
                right: 74,
                bottom: 30,
                child: _softHeart(kMainSage, 12),
              ),
              const CozyMascot(size: 124),
              Positioned(
                left: 34,
                bottom: 12,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kMainHoneySoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kMainHoney),
                    ),
                    child: Text(
                      'Secret',
                      style: mainBody(
                        size: 11,
                        color: kMainSub,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('짜잔!', style: mainTitle(size: 22)),
        const SizedBox(height: 6),
        Text(
          '안녕하세요. 오늘의 비밀기지로 들어가 볼까요?',
          style: mainBody(size: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _softHeart(Color color, double size) {
    return Icon(Icons.favorite, color: color.withAlpha(120), size: size);
  }

  Widget _form() {
    return MainCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('서버 주소'),
          const SizedBox(height: 6),
          TextField(
            controller: _urlCtrl,
            style: mainBody(size: 14, color: kMainInk),
            decoration: _inputDecoration(
              'http://192.168.x.x:4100',
              Icons.dns_outlined,
            ),
          ),
          const SizedBox(height: 14),
          _label('방 코드'),
          const SizedBox(height: 6),
          TextField(
            controller: _roomCtrl,
            style: mainBody(size: 14, color: kMainInk),
            decoration: _inputDecoration(
              'secret-room',
              Icons.meeting_room_outlined,
            ),
          ),
          const SizedBox(height: 14),
          _label('비밀번호'),
          const SizedBox(height: 6),
          TextField(
            controller: _secretCtrl,
            obscureText: true,
            style: mainBody(size: 14, color: kMainInk),
            decoration: _inputDecoration('비밀 단어', Icons.lock_outline),
          ),
          const SizedBox(height: 18),
          _label('나는 누구?'),
          const SizedBox(height: 9),
          Row(
            children: [
              _userTile('jun', '준'),
              const SizedBox(width: 10),
              _userTile('gf', 'GF'),
            ],
          ),
          const SizedBox(height: 20),
          if (_socket.status != '대기 중' && !_socket.isConnected && !_connecting)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: kError.withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kError.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: kError, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _socket.status,
                        style: mainBody(
                          size: 12,
                          color: kError,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _enterButton(),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: mainBody(size: 13, color: kMainMuted),
      prefixIcon: Icon(icon, color: kMainMuted, size: 19),
      filled: true,
      fillColor: kMainPaperSoft.withAlpha(170),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kMainLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kMainLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kMainSage, width: 1.4),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: mainBody(
        size: 12,
        color: kMainSub,
        weight: FontWeight.w700,
        height: 1.1,
      ),
    );
  }

  Widget _userTile(String val, String label) {
    final selected = _user == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _user = val),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? kMainSageSoft : kMainPaperSoft.withAlpha(150),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kMainSage : kMainLine,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected ? kMainSage : kMainMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: mainBody(
                  size: 14,
                  color: selected ? kMainInk : kMainSub,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enterButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: _connecting ? null : _connect,
        style: FilledButton.styleFrom(
          backgroundColor: kMainInk,
          disabledBackgroundColor: kMainLine,
          foregroundColor: kMainPaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _connecting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: kMainInk,
                ),
              )
            : Text(
                '우리 방 입장',
                style: mainBody(
                  size: 15,
                  color: kMainPaper,
                  weight: FontWeight.w700,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
