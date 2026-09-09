import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_service.dart';
import 'auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  DateTime? _birthDate;
  int _step = 0;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  final _auth = AuthService();

  bool _validateProfile() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return false;
    }
    if (_nicknameCtrl.text.trim().isEmpty) {
      setState(() => _error = '닉네임을 입력해주세요.');
      return false;
    }
    if (_birthDate == null) {
      setState(() => _error = '생년월일을 선택해주세요.');
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_validateProfile()) return;
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _register() async {
    if (_loading) return;
    final emailError = validateAuthEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    if (_passwordCtrl.text.trim().isEmpty) {
      setState(() => _error = '비밀번호를 입력해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _auth.register(
      _emailCtrl.text.trim(),
      _passwordCtrl.text.trim(),
      _nameCtrl.text.trim(),
      _nicknameCtrl.text.trim(),
      _dateOnly(_birthDate),
    );

    if (!mounted) return;
    if (success) {
      TextInput.finishAutofillContext();
      Navigator.pop(context, _emailCtrl.text.trim());
      return;
    }

    setState(() {
      _loading = false;
      _error = '회원가입에 실패했습니다. 이미 사용 중인 이메일일 수 있습니다.';
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthTheme(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _topBar(),
                      const SizedBox(height: 40),
                      AuthHeading(
                        title: _step == 0
                            ? '가입을 축하해요!\n어떻게 불러드릴까요?'
                            : '로그인 정보를\n만들어볼게요.',
                        description: _step == 0
                            ? '두 분만의 기록을 시작하기 전에\n간단한 정보를 알려주세요.'
                            : '다음부터 이메일과 비밀번호로\n안전하게 입장할 수 있어요.',
                      ),
                      const SizedBox(height: 34),
                      _step == 0 ? _profileForm() : _accountForm(),
                      if (_error != null) AuthError(_error!),
                      const SizedBox(height: 22),
                      AuthButton(
                        label: _step == 0 ? '다음' : '회원가입',
                        loading: _loading,
                        onPressed: _step == 0 ? _nextStep : _register,
                      ),
                      if (_step == 1) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _step = 0;
                                  _error = null;
                                }),
                          child: Text(
                            '이전 단계',
                            style: authText(size: 14, color: authSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          tooltip: '뒤로가기',
          onPressed: _loading ? null : () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(child: AuthProgress(current: _step + 1, total: 2)),
        const SizedBox(width: 14),
        Text(
          '${_step + 1}/2',
          style: authText(size: 14, color: authMuted, weight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _profileForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: '이름',
            child: TextField(
              controller: _nameCtrl,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: authText(),
              decoration: const InputDecoration(hintText: '이름을 입력해주세요'),
            ),
          ),
          const SizedBox(height: 20),
          AuthField(
            label: '닉네임',
            child: TextField(
              controller: _nicknameCtrl,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              style: authText(),
              decoration: const InputDecoration(hintText: '앱에서 사용할 이름을 입력해주세요'),
            ),
          ),
          const SizedBox(height: 20),
          AuthField(
            label: '생년월일',
            child: InkWell(
              onTap: _loading ? null : _pickBirthDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: '생년월일을 선택해주세요',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                ),
                child: Text(
                  _birthDate == null ? '' : _dateOnly(_birthDate),
                  style: authText(
                    color: _birthDate == null ? authMuted : authInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: '이메일',
            child: TextField(
              controller: _emailCtrl,
              enabled: !_loading,
              style: authText(),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              decoration: const InputDecoration(hintText: '이메일 주소를 입력해주세요'),
            ),
          ),
          const SizedBox(height: 20),
          AuthField(
            label: '비밀번호',
            child: TextField(
              controller: _passwordCtrl,
              enabled: !_loading,
              style: authText(),
              obscureText: !_showPassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              decoration: InputDecoration(
                hintText: '비밀번호를 입력해주세요',
                suffixIcon: IconButton(
                  tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '입력한 이메일은 로그인과 계정 안내에 사용돼요.',
            style: authText(size: 12, color: authMuted),
          ),
        ],
      ),
    );
  }

  String _dateOnly(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '생년월일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _error = null;
      });
    }
  }
}
