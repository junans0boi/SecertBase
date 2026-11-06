import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';

/// 비밀번호 재설정: 이메일 → 메일로 받은 6자리 코드 → 새 비밀번호 → 완료.
/// 가입 여부를 드러내지 않도록 어떤 이메일이든 같은 안내를 보여 준다.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail});
  final String? initialEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

enum _ResetStep { email, code, password, done }

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  static const _cooldownSeconds = 60;

  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService();

  _ResetStep _step = _ResetStep.email;
  bool _loading = false;
  String? _error;
  bool _mailUnavailable = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown = (_cooldown - 1).clamp(0, _cooldownSeconds));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _error = '이메일 주소를 확인해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _mailUnavailable = false;
    });
    final code = await _auth.requestPasswordReset(email);
    if (!mounted) return;
    if (code == null) {
      setState(() {
        _loading = false;
        _step = _ResetStep.code;
        _codeCtrl.clear();
      });
      _startCooldown();
      if (resend) showV2Snack(context, '메일을 다시 보냈어요');
      return;
    }
    setState(() {
      _loading = false;
      _mailUnavailable = code == 'mail_unavailable';
      _error = authErrorMessage(code);
    });
  }

  Future<void> _verify() async {
    if (_loading) return;
    final code = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '메일로 받은 6자리 숫자를 입력해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _auth.verifyPasswordResetCode(
      _emailCtrl.text.trim(),
      code,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err == null) {
        _step = _ResetStep.password;
      } else {
        _error = authErrorMessage(err);
      }
    });
  }

  Future<void> _confirm() async {
    if (_loading) return;
    final password = _passwordCtrl.text;
    if (!isStrongPassword(password)) {
      setState(() => _error = authErrorMessage('weak_password'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _auth.confirmPasswordReset(
      email: _emailCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
      password: password,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err == null) {
        _step = _ResetStep.done;
      } else {
        _error = authErrorMessage(err);
        // 코드가 더 쓸 수 없으면 코드 입력부터 다시.
        if (err == 'invalid_code' ||
            err == 'code_expired' ||
            err == 'too_many_attempts') {
          _step = _ResetStep.code;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final (title, body, button) = switch (_step) {
      _ResetStep.email => ('비밀번호를 잊으셨나요?', _emailStep(), _sendButton()),
      _ResetStep.code => ('메일을 보냈어요', _codeStep(), _codeButton()),
      _ResetStep.password => ('새 비밀번호를 만들어요', _passwordStep(), _confirmButton()),
      _ResetStep.done => ('비밀번호를 바꿨어요', _doneStep(), _doneButton()),
    };
    return AuthFrame(
      header: V2Header(
        title: '비밀번호 재설정',
        onBack: _loading ? () {} : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: V2Text.title),
          const SizedBox(height: V2Space.x4),
          body,
        ],
      ),
      footer: button,
    );
  }

  Widget _sendButton() => V2Button(
    label: '재설정 메일 보내기',
    loading: _loading,
    onPressed: _loading ? null : _send,
  );

  Widget _emailStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '가입한 이메일을 알려주세요. 비밀번호를 다시 만드는 6자리 코드를 보내드려요.',
        style: V2Text.cap,
      ),
      const SizedBox(height: V2Space.x5),
      V2TextField(
        label: '이메일',
        hint: 'name@example.com',
        controller: _emailCtrl,
        enabled: !_loading,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        error: _mailUnavailable ? null : _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _send(),
      ),
      if (_mailUnavailable)
        Padding(
          padding: const EdgeInsets.only(top: V2Space.x3),
          child: V2Banner(
            tone: V2BannerTone.warn,
            message: '지금은 메일을 보낼 수 없어요. 잠시 후 다시 시도해 주세요.',
            actionLabel: '다시 시도',
            onAction: _loading ? null : _send,
          ),
        ),
    ],
  );

  Widget _codeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          style: V2Text.body,
          children: [
            TextSpan(
              text: _emailCtrl.text.trim(),
              style: V2Text.bodyStrong,
            ),
            const TextSpan(text: '으로 재설정 코드를 보냈어요.'),
          ],
        ),
      ),
      const SizedBox(height: V2Space.x2),
      Text('메일이 보이지 않으면 스팸함을 확인해 주세요.', style: V2Text.cap),
      Text('코드는 1시간 동안만 쓸 수 있어요.', style: V2Text.cap),
      Text('가입하지 않은 이메일이어도 같은 안내가 나와요.', style: V2Text.cap),
      const SizedBox(height: V2Space.x5),
      V2TextField(
        label: '6자리 코드',
        hint: '123456',
        controller: _codeCtrl,
        enabled: !_loading,
        autofocus: true,
        maxLength: 6,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofillHints: const [AutofillHints.oneTimeCode],
        error: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: V2Space.x2),
      Align(
        alignment: Alignment.centerLeft,
        child: V2Button(
          label: _cooldown > 0 ? '메일 다시 보내기 ($_cooldown초 후)' : '메일 다시 보내기',
          variant: V2ButtonVariant.text,
          size: V2ButtonSize.sm,
          onPressed: (_loading || _cooldown > 0)
              ? null
              : () => _send(resend: true),
        ),
      ),
    ],
  );

  Widget _codeButton() => V2Button(
    label: '다음',
    loading: _loading,
    onPressed: _loading ? null : _verify,
  );

  Widget _passwordStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('앞으로 로그인에 쓸 비밀번호예요.', style: V2Text.cap),
      const SizedBox(height: V2Space.x5),
      V2TextField(
        label: '새 비밀번호',
        hint: '새 비밀번호',
        controller: _passwordCtrl,
        enabled: !_loading,
        autofocus: true,
        password: true,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        error: _error,
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _confirm(),
      ),
      PasswordChecklist(_passwordCtrl.text),
    ],
  );

  Widget _confirmButton() => V2Button(
    label: '비밀번호 바꾸기',
    loading: _loading,
    onPressed: _loading ? null : _confirm,
  );

  Widget _doneStep() => Column(
    children: [
      const SizedBox(height: V2Space.x6),
      const V2SceneIllustration(V2Scene.letter),
      const SizedBox(height: V2Space.x5),
      Text(
        V2Text.keepAll('새 비밀번호로 로그인해 주세요.'),
        textAlign: TextAlign.center,
        style: V2Text.body,
      ),
    ],
  );

  Widget _doneButton() => V2Button(
    label: '로그인으로 돌아가기',
    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
  );
}
