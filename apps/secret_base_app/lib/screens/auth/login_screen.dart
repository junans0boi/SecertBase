import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import '../../widgets/google_sign_in_button.dart';
import 'auth_parts.dart';
import 'password_reset_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openLogin({String? email, bool justRegistered = false}) =>
      showV2Sheet<void>(
        context,
        title: justRegistered ? '가입을 축하해요!' : '이메일로 로그인',
        subtitle: justRegistered ? '만든 계정으로 로그인해 시작해 보세요.' : null,
        builder: (sheetContext) => _EmailLoginForm(
          initialEmail: email,
          onForgot: (typed) {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PasswordResetScreen(initialEmail: typed),
              ),
            );
          },
        ),
      );

  Future<void> _openRegister() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    // 가입 직후 자동 로그인에 실패했을 때만 이메일이 돌아온다.
    if (mounted && email != null) {
      await _openLogin(email: email, justRegistered: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final googleOn = _auth.isGoogleLoginConfigured;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      260.0,
      420.0,
    );
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        body: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  SizedBox(
                    height: heroHeight,
                    width: double.infinity,
                    child: AuthHeroBlock(
                      expand: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AuthHeartKey(size: 112),
                          const SizedBox(height: V2Space.x3),
                          Semantics(
                            header: true,
                            child: Text(
                              '비밀기지',
                              style: V2Text.display.copyWith(
                                color: Colors.white,
                                fontSize: 36,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          V2Space.page,
                          V2Space.x5,
                          V2Space.page,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '우리 둘만의 아지트',
                              textAlign: TextAlign.center,
                              style: V2Text.head.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: V2Space.x1),
                            Text(
                              V2Text.keepAll('로그인하고 서로의 하루를 이어 가요'),
                              textAlign: TextAlign.center,
                              style: V2Text.cap,
                            ),
                            const SizedBox(height: V2Space.x6),
                            if (googleOn) ...[
                              if (kIsWeb)
                                buildGoogleSignInButton(
                                  onPressed: () => _auth.loginWithGoogle(),
                                  loading: _auth.googleLoading,
                                )
                              else
                                _GoogleButton(
                                  loading: _auth.googleLoading,
                                  onPressed: () => _auth.loginWithGoogle(),
                                ),
                              if (_auth.googleError != null)
                                AuthErrorLine(_auth.googleError!),
                              const SizedBox(height: V2Space.x3),
                            ],
                            V2Button(
                              label: '이메일로 로그인',
                              icon: V2Icons.mail,
                              variant: googleOn
                                  ? V2ButtonVariant.ghost
                                  : V2ButtonVariant.primary,
                              onPressed: _auth.googleLoading
                                  ? null
                                  : _openLogin,
                            ),
                            const SizedBox(height: V2Space.x4),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('처음이세요? ', style: V2Text.cap),
                                InkWell(
                                  onTap: _auth.googleLoading
                                      ? null
                                      : _openRegister,
                                  borderRadius: BorderRadius.circular(6),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: V2Space.tap,
                                    ),
                                    child: Center(
                                      widthFactor: 1,
                                      child: Text(
                                        '이메일로 가입하기',
                                        style: V2Text.bodyStrong.copyWith(
                                          color: p.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      V2Space.page,
                      V2Space.x2,
                      V2Space.page,
                      V2Space.x4,
                    ),
                    child: SafeArea(top: false, child: LegalLinks()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 어두운 'Google로 계속하기' 버튼(앱). 웹은 Google이 그리는 버튼을 쓴다.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed, this.loading = false});
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      label: 'Google로 계속하기',
      excludeSemantics: true,
      child: Material(
        color: p.ink,
        borderRadius: V2Radius.buttonAll,
        child: InkWell(
          borderRadius: V2Radius.buttonAll,
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 52,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Text(
                            'G',
                            textScaler: TextScaler.noScaling,
                            style: V2Text.sans(
                              size: 16,
                              weight: FontWeight.w800,
                              color: V2Colors.skyText,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: V2Space.x3),
                        Text(
                          'Google로 계속하기',
                          style: V2Text.button.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailLoginForm extends StatefulWidget {
  const _EmailLoginForm({this.initialEmail, required this.onForgot});
  final String? initialEmail;
  final ValueChanged<String> onForgot;
  @override
  State<_EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<_EmailLoginForm> {
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  String? _emailError;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    if (!isValidEmail(email)) {
      setState(() {
        _emailError = email.isEmpty ? '이메일을 입력해 주세요.' : '이메일 주소를 확인해 주세요.';
        _error = null;
      });
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      setState(() {
        _emailError = null;
        _error = '비밀번호를 입력해 주세요.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _emailError = null;
    });
    // 비밀번호는 다듬지 않는다(공백도 비밀번호의 일부).
    final code = await AuthService().loginWithEmail(email, _passwordCtrl.text);
    if (!mounted) return;
    if (code == null) {
      TextInput.finishAutofillContext();
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    setState(() {
      _loading = false;
      _error = authErrorMessage(code);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          V2TextField(
            label: '이메일',
            hint: 'name@example.com',
            controller: _emailCtrl,
            enabled: !_loading,
            error: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: V2Space.x4),
          V2TextField(
            label: '비밀번호',
            hint: '비밀번호',
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            enabled: !_loading,
            password: true,
            error: _error,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _login(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: V2Button(
              label: '비밀번호를 잊으셨나요?',
              variant: V2ButtonVariant.text,
              size: V2ButtonSize.sm,
              onPressed: _loading
                  ? null
                  : () => widget.onForgot(_emailCtrl.text.trim()),
            ),
          ),
          const SizedBox(height: V2Space.x2),
          V2Button(
            label: _loading ? '로그인 중이에요' : '로그인',
            loading: _loading,
            onPressed: _loading ? null : _login,
          ),
          const SizedBox(height: V2Space.x2),
        ],
      ),
    ),
  );
}
