import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'settings_common.dart';

/// 내 프로필 편집: 닉네임, 생일, 로그인 방법, 비밀번호 변경.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _maxNickname = 10;

  final _auth = AuthService();
  final _nickname = TextEditingController();
  final _birthCtrl = TextEditingController();
  DateTime? _birth;
  bool _saving = false;
  String? _error;
  String _fullName = '';

  @override
  void initState() {
    super.initState();
    final user = _auth.user;
    _nickname.text = myDisplayName(user) == '나' && user?['Nickname'] == null
        ? ''
        : myDisplayName(user);
    _fullName =
        '${user?['FullName'] ?? user?['fullName'] ?? user?['UserName'] ?? ''}'
            .trim();
    _birth = parseDateOnly(user?['BirthDate'] ?? user?['birthDate']);
    _birthCtrl.text = _birth == null ? '' : koreanDate(_birth!);
    _nickname.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nickname.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  bool get _dirty {
    final user = _auth.user;
    final before = parseDateOnly(user?['BirthDate'] ?? user?['birthDate']);
    return _nickname.text.trim() != myDisplayName(user) || _birth != before;
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '생일을 골라 주세요',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked != null && mounted) {
      setState(() {
        _birth = picked;
        _birthCtrl.text = koreanDate(picked);
      });
    }
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요.');
      return;
    }
    if (_birth == null) {
      setState(() => _error = '생일을 골라 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await _auth.updateProfile(
      fullName: _fullName.isEmpty ? nickname : _fullName,
      nickname: nickname,
      birthDate: isoDate(_birth!),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showV2Snack(context, '프로필을 저장했어요');
      Navigator.of(context).pop();
    } else {
      setState(() => _error = '저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _changePassword() async {
    final done = await showV2Sheet<bool>(
      context,
      title: '비밀번호 바꾸기',
      builder: (_) => const _PasswordSheet(),
    );
    if (done == true && mounted) {
      showV2Snack(context, '비밀번호를 바꿨어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.user;
    final google = isGoogleAccount(user);
    final email = '${user?['Email'] ?? user?['email'] ?? ''}'.trim();
    final p = V2Palette.of(context);
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '내 프로필'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Center(
              child: V2Avatar(
                name: _nickname.text.trim().isEmpty
                    ? myDisplayName(user)
                    : _nickname.text.trim(),
                size: V2AvatarSize.xl,
              ),
            ),
            const SizedBox(height: 24),
            V2TextField(
              label: '닉네임',
              controller: _nickname,
              maxLength: _maxNickname,
              textInputAction: TextInputAction.done,
              help: partnerDisplayName(user) == null
                  ? '파트너에게 보이는 이름이에요'
                  : '${partnerDisplayName(user)}에게 보이는 이름이에요',
            ),
            const SizedBox(height: 16),
            V2TextField(
              label: '생일',
              readOnly: true,
              controller: _birthCtrl,
              hint: '생일을 골라 주세요',
              help: '운세와 사주 풀이에 쓰여요. 바꾸면 결과도 달라져요.',
              suffix: Icon(V2Icons.calendar, color: p.muted),
              onTap: _pickBirth,
            ),
            const SizedBox(height: 20),
            MoreInfoGroup(
              children: [
                MoreInfoRow(label: '로그인 방법', value: google ? 'Google' : '이메일'),
                if (email.isNotEmpty) MoreInfoRow(label: '계정', value: email),
                if (!google)
                  V2ListTile(
                    icon: V2Icons.lock,
                    tone: V2Tone.lilac,
                    title: '비밀번호 바꾸기',
                    onTap: _changePassword,
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              V2Banner(tone: V2BannerTone.err, message: _error!),
            ],
            const SizedBox(height: 24),
            V2Button(
              label: '저장하기',
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  static bool _strong(String v) =>
      v.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(v) &&
      RegExp(r'\d').hasMatch(v);

  Future<void> _submit() async {
    final current = _current.text.trim();
    final next = _next.text.trim();
    if (current.isEmpty) {
      setState(() => _error = '지금 쓰는 비밀번호를 입력해 주세요.');
      return;
    }
    if (!_strong(next)) {
      setState(() => _error = '새 비밀번호는 8자 이상, 영문과 숫자를 함께 써 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await AuthService().updatePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2TextField(label: '지금 비밀번호', password: true, controller: _current),
        const SizedBox(height: 12),
        V2TextField(
          label: '새 비밀번호',
          password: true,
          controller: _next,
          help: '8자 이상, 영문과 숫자를 함께 써 주세요',
          error: _error,
        ),
        const SizedBox(height: 16),
        V2Button(label: '바꾸기', loading: _saving, onPressed: _submit),
      ],
    );
  }
}
