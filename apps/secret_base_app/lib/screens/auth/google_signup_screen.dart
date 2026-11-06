import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';

/// Google로 처음 로그인한 사람의 가입 마무리: 닉네임·생일·약관 동의.
/// 마치기 전에는 앱 안으로 들어갈 수 없다(main.dart가 이 화면을 먼저 보여 준다).
class GoogleSignupScreen extends StatefulWidget {
  const GoogleSignupScreen({super.key});

  @override
  State<GoogleSignupScreen> createState() => _GoogleSignupScreenState();
}

class _GoogleSignupScreenState extends State<GoogleSignupScreen> {
  final _auth = AuthService();
  late final _nicknameCtrl = TextEditingController(
    text: '${_auth.user?['Nickname'] ?? ''}'.trim(),
  );
  final _birthCtrl = TextEditingController();
  DateTime? _birthDate;
  ConsentValue _consent = const ConsentValue();
  bool _loading = false;
  String? _nicknameError;
  String? _birthError;
  String? _formError;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
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

  bool get _canSubmit =>
      !_loading &&
      _nicknameCtrl.text.trim().isNotEmpty &&
      _birthDate != null &&
      _consent.requiredOk;

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _nicknameError = _nicknameCtrl.text.trim().isEmpty
          ? '닉네임을 입력해 주세요.'
          : null;
      _birthError = _birthDate == null
          ? '생일을 선택해 주세요.'
          : (isAtLeast14(_birthDate!) ? null : authErrorMessage('under_age'));
      _formError = _consent.requiredOk ? null : '필수 항목에 동의하면 시작할 수 있어요.';
    });
    if (_nicknameError != null || _birthError != null || _formError != null) {
      return;
    }
    setState(() => _loading = true);
    final code = await _auth.completeSignup(
      nickname: _nicknameCtrl.text.trim(),
      birthDate: isoDate(_birthDate!),
      consents: _consent.toJson(),
    );
    if (!mounted) return;
    // 성공하면 프로필이 갱신되어 main.dart가 다음 화면으로 넘어간다.
    setState(() {
      _loading = false;
      if (code != null) {
        if (code == 'under_age' || code == 'invalid_birth_date') {
          _birthError = authErrorMessage(code);
        } else {
          _formError = authErrorMessage(code);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final email = '${_auth.user?['Email'] ?? _auth.user?['email'] ?? ''}';
    return AuthFrame(
      header: V2Header(
        title: '가입 마무리',
        showBack: false,
        actions: [
          V2Button(
            label: '로그아웃',
            variant: V2ButtonVariant.text,
            size: V2ButtonSize.sm,
            onPressed: _loading ? null : () => _auth.logout(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2Card(
            variant: V2CardVariant.soft,
            child: Row(
              children: [
                Icon(V2Icons.person, color: p.primary),
                const SizedBox(width: V2Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google 계정으로 가입 중이에요', style: V2Text.bodyStrong),
                      if (email.isNotEmpty) Text(email, style: V2Text.cap),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: V2Space.x5),
          V2TextField(
            label: '닉네임',
            hint: '상대에게 보여질 이름',
            controller: _nicknameCtrl,
            enabled: !_loading,
            maxLength: 10,
            error: _nicknameError,
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
            enabled: !_loading,
            onTap: _pickBirth,
            error: _birthError,
            help: '필수예요. 사주와 운세를 계산하는 데만 써요.',
            prefixIcon: V2Icons.calendar,
          ),
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
        ],
      ),
      footer: V2Button(
        label: _loading ? '시작하는 중이에요' : '시작하기',
        loading: _loading,
        onPressed: _canSubmit ? _submit : null,
      ),
    );
  }
}
