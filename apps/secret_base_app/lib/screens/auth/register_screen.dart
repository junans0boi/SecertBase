import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';
import 'password_reset_screen.dart';

/// 이메일 가입(2단계). 1/2 이름·닉네임·생일, 2/2 이메일·비밀번호·동의.
/// 가입이 끝나면 바로 로그인한다. 자동 로그인에 실패했을 때만 이메일을 돌려준다.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _nicknameMax = 10;

  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  DateTime? _birthDate;
  ConsentValue _consent = const ConsentValue();
  int _step = 0;
  bool _loading = false;
  bool _welcome = false;

  String? _nameError;
  String? _nicknameError;
  String? _birthError;
  String? _emailError;
  bool _emailTaken = false;
  String? _passwordError;
  String? _formError;

  final _auth = AuthService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final picked = await pickBirthDate(context, _birthDate);
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _birthCtrl.text = formatBirthDate(picked);
        _birthError = null;
      });
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    setState(() {
      _nameError = name.isEmpty ? '이름을 입력해 주세요.' : null;
      _nicknameError = nickname.isEmpty ? '닉네임을 입력해 주세요.' : null;
      _birthError = _birthDate == null
          ? '생일을 선택해 주세요.'
          : (isAtLeast14(_birthDate!) ? null : '만 14세 이상만 가입할 수 있어요.');
    });
    if (_nameError == null && _nicknameError == null && _birthError == null) {
      setState(() => _step = 1);
    }
  }

  bool get _canSubmit =>
      !_loading &&
      isValidEmail(_emailCtrl.text) &&
      isStrongPassword(_passwordCtrl.text) &&
      _consent.requiredOk;

  Future<void> _register() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() {
      _emailTaken = false;
      _emailError = isValidEmail(email) ? null : '이메일 주소를 확인해 주세요.';
      _passwordError = isStrongPassword(password)
          ? null
          : '비밀번호는 8자 이상, 영문과 숫자를 함께 써 주세요.';
      _formError = _consent.requiredOk ? null : '필수 항목에 동의하면 가입할 수 있어요.';
    });
    if (_emailError != null || _passwordError != null || _formError != null) {
      return;
    }
    setState(() => _loading = true);
    final code = await _auth.registerAccount(
      email: email,
      password: password,
      fullName: _nameCtrl.text.trim(),
      nickname: _nicknameCtrl.text.trim(),
      birthDate: isoDate(_birthDate!),
      consents: _consent.toJson(),
    );
    if (!mounted) return;
    if (code != null) {
      setState(() {
        _loading = false;
        switch (code) {
          case 'email_already_exists':
            _emailError = '이미 가입된 이메일이에요.';
            _emailTaken = true;
          case 'weak_password':
            _passwordError = authErrorMessage(code);
          case 'under_age':
          case 'invalid_birth_date':
            _step = 0;
            _birthError = authErrorMessage(code);
          default:
            _formError = authErrorMessage(code);
        }
      });
      return;
    }
    TextInput.finishAutofillContext();
    setState(() => _welcome = true);
    final loginCode = await _auth.loginWithEmail(email, password);
    if (!mounted) return;
    if (loginCode == null) {
      // 메인 화면이 바뀐 뒤 위에 쌓인 가입/로그인 화면을 걷어 낸다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    } else {
      Navigator.pop(context, email);
    }
  }

  void _toLogin() => Navigator.pop(context, _emailCtrl.text.trim());

  void _toReset() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => PasswordResetScreen(initialEmail: _emailCtrl.text.trim()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_welcome) {
      final nick = _nicknameCtrl.text.trim();
      return AuthFrame(
        hero: true,
        body: Padding(
          padding: const EdgeInsets.only(top: V2Space.x12),
          child: Column(
            children: [
              const AuthEmblem(size: 96),
              const SizedBox(height: V2Space.x6),
              Text('$nick님, 환영해요!', style: V2Text.title),
              const SizedBox(height: V2Space.x2),
              Text(
                V2Text.keepAll('로그인하는 중이에요. 곧 상대와 연결할 수 있어요.'),
                textAlign: TextAlign.center,
                style: V2Text.cap,
              ),
              const SizedBox(height: V2Space.x6),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      );
    }

    final p = V2Palette.of(context);
    return PopScope(
      canPop: _step == 0 && !_loading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_loading && _step == 1) setState(() => _step = 0);
      },
      child: V2Theme(
        child: Scaffold(
          appBar: V2Header(
            title: '가입하기',
            onBack: () {
              if (_loading) return;
              if (_step == 1) {
                setState(() => _step = 0);
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        V2Space.page,
                        V2Space.x1,
                        V2Space.page,
                        0,
                      ),
                      child: Semantics(
                        label: '2단계 중 ${_step + 1}단계',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              for (var i = 0; i < 2; i++) ...[
                                Expanded(
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: i <= _step ? p.primary : p.soft2,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                                if (i == 0) const SizedBox(width: V2Space.x2),
                              ],
                              const SizedBox(width: V2Space.x3),
                              Text(
                                '${_step + 1}/2',
                                style: V2Text.bodyStrong.copyWith(color: p.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(V2Space.page),
                        child: AutofillGroup(
                          child: _step == 0 ? _stepProfile() : _stepAccount(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        V2Space.page,
                        V2Space.x2,
                        V2Space.page,
                        V2Space.x5,
                      ),
                      child: _step == 0
                          ? V2Button(label: '다음', onPressed: _next)
                          : V2Button(
                              label: _loading ? '가입하는 중이에요' : '가입하기',
                              loading: _loading,
                              onPressed: _canSubmit ? _register : null,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepProfile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('먼저 나를 소개해 주세요', style: V2Text.title),
      const SizedBox(height: V2Space.x1),
      Text('상대에게 보이는 이름과 운세에 쓰는 생일이에요.', style: V2Text.cap),
      const SizedBox(height: V2Space.x6),
      V2TextField(
        label: '이름',
        hint: '이름',
        controller: _nameCtrl,
        error: _nameError,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        onChanged: (_) => setState(() => _nameError = null),
      ),
      const SizedBox(height: V2Space.x4),
      V2TextField(
        label: '닉네임',
        hint: '상대에게 보여질 이름',
        controller: _nicknameCtrl,
        error: _nicknameError,
        maxLength: _nicknameMax,
        help: '상대에게 이 이름으로 보여요. 나중에 바꿀 수 있어요.',
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() => _nicknameError = null),
      ),
      const SizedBox(height: V2Space.x4),
      V2TextField(
        label: '생일',
        hint: '생일을 선택해 주세요',
        controller: _birthCtrl,
        readOnly: true,
        onTap: _pickBirth,
        error: _birthError,
        help: '사주와 운세를 계산하는 데만 써요.',
        prefixIcon: V2Icons.calendar,
      ),
    ],
  );

  Widget _stepAccount() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      V2TextField(
        label: '이메일',
        hint: 'name@example.com',
        controller: _emailCtrl,
        enabled: !_loading,
        error: _emailError,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newUsername],
        onChanged: (_) => setState(() {
          _emailError = null;
          _emailTaken = false;
        }),
      ),
      if (_emailTaken)
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              V2Button(
                label: '로그인',
                variant: V2ButtonVariant.text,
                size: V2ButtonSize.sm,
                onPressed: _toLogin,
              ),
              Text('·', style: V2Text.cap),
              V2Button(
                label: '비밀번호 재설정',
                variant: V2ButtonVariant.text,
                size: V2ButtonSize.sm,
                onPressed: _toReset,
              ),
            ],
          ),
        ),
      const SizedBox(height: V2Space.x4),
      V2TextField(
        label: '비밀번호',
        hint: '비밀번호',
        controller: _passwordCtrl,
        enabled: !_loading,
        password: true,
        error: _passwordError,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() => _passwordError = null),
        onSubmitted: (_) {
          if (_canSubmit) _register();
        },
      ),
      PasswordChecklist(_passwordCtrl.text),
      const SizedBox(height: V2Space.x6),
      ConsentChecks(
        value: _consent,
        enabled: !_loading,
        onChanged: (v) => setState(() {
          _consent = v;
          _formError = null;
        }),
      ),
      if (_formError != null) AuthErrorLine(_formError!),
      if (!_consent.requiredOk && _formError == null)
        Padding(
          padding: const EdgeInsets.only(top: V2Space.x2),
          child: Text('필수 항목에 동의하면 가입할 수 있어요', style: V2Text.cap),
        ),
    ],
  );
}
