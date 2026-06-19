import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
import '../../core/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _auth = AuthService();

  void _register() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _auth.register(
      _emailCtrl.text.trim(),
      _passwordCtrl.text.trim(),
      _nameCtrl.text.trim(),
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공! 로그인해주세요.')),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _loading = false;
        _error = '회원가입에 실패했습니다. 이미 사용 중인 이메일일 수 있습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kMainInk),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CozyPage(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    Text('비밀기지 시작하기', style: mainTitle(size: 28)),
                    const SizedBox(height: 32),
                    _form(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return MainCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('이름'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDecoration('이름 입력', Icons.person_outline),
          ),
          const SizedBox(height: 16),
          _label('이메일'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('example@email.com', Icons.email_outlined),
          ),
          const SizedBox(height: 16),
          _label('비밀번호'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: _inputDecoration('비밀번호 입력', Icons.lock_outline),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: mainBody(size: 13, color: kError)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _register,
              style: FilledButton.styleFrom(
                backgroundColor: kMainInk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('회원가입', style: mainBody(size: 16, color: Colors.white, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text, style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700));

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: kMainMuted, size: 20),
      filled: true,
      fillColor: kMainPaperSoft,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }
}
