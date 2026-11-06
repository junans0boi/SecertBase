import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';

const kWithdrawPhrase = '탈퇴합니다';

/// 회원 탈퇴: 경고 → 마지막 확인(비밀번호 + 확인 문구) → 완료.
/// 연결 전에도, 연결 뒤에도 열 수 있다. "그대로 남을게요"가 큰 버튼이다.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

enum _Step { warn, confirm, done }

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _auth = AuthService();
  final _passwordCtrl = TextEditingController();
  final _phraseCtrl = TextEditingController();
  _Step _step = _Step.warn;
  bool _loading = false;
  String? _passwordError;
  String? _error;

  bool get _needsPassword {
    final provider =
        '${_auth.user?['AuthProvider'] ?? _auth.user?['authProvider'] ?? 'password'}'
            .toLowerCase();
    return provider != 'google';
  }

  bool get _canSubmit =>
      !_loading &&
      _phraseCtrl.text.trim() == kWithdrawPhrase &&
      (!_needsPassword || _passwordCtrl.text.isNotEmpty);

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _phraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _passwordError = null;
      _error = null;
    });
    final code = await _auth.deleteAccount(
      password: _needsPassword ? _passwordCtrl.text : null,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (code) {
        case null:
          _step = _Step.done;
        case 'invalid_password' || 'password_required':
          _passwordError = '비밀번호가 맞지 않아요. 다시 확인해 주세요.';
        default:
          _error = authErrorMessage(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    switch (_step) {
      case _Step.warn:
        return AuthFrame(
          header: const V2Header(title: '회원 탈퇴'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('탈퇴하기 전에\n확인해 주세요', style: V2Text.title),
              const SizedBox(height: V2Space.x5),
              for (final line in const [
                '내 프로필과 기록, 사진이 모두 지워져요.',
                '연결된 상대가 있으면 연결도 함께 끊겨요.',
                '지운 데이터는 되돌릴 수 없어요.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: V2Space.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(V2Icons.warn, size: 20, color: p.primary),
                      const SizedBox(width: V2Space.x3),
                      Expanded(child: Text(line, style: V2Text.body)),
                    ],
                  ),
                ),
            ],
          ),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V2Button(
                label: '그대로 남을게요',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: V2Space.x1),
              V2Button(
                label: '탈퇴 계속하기',
                variant: V2ButtonVariant.text,
                onPressed: () => setState(() => _step = _Step.confirm),
              ),
            ],
          ),
        );
      case _Step.confirm:
        return AuthFrame(
          header: V2Header(
            title: '회원 탈퇴',
            onBack: _loading ? () {} : () => setState(() => _step = _Step.warn),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('마지막으로 확인할게요', style: V2Text.title),
              const SizedBox(height: V2Space.x2),
              Text('아래 칸에 "$kWithdrawPhrase"를 그대로 입력해 주세요.', style: V2Text.cap),
              const SizedBox(height: V2Space.x5),
              if (_needsPassword) ...[
                V2TextField(
                  label: '비밀번호',
                  controller: _passwordCtrl,
                  password: true,
                  enabled: !_loading,
                  error: _passwordError,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _passwordError = null),
                ),
                const SizedBox(height: V2Space.x4),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: V2Space.x4),
                  child: Text('Google 계정으로 가입해서 비밀번호는 필요 없어요.', style: V2Text.cap),
                ),
              V2TextField(
                label: '확인 문구',
                hint: kWithdrawPhrase,
                controller: _phraseCtrl,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _withdraw(),
              ),
              if (_error != null) AuthErrorLine(_error!),
            ],
          ),
          footer: V2Button(
            label: '탈퇴하기',
            variant: V2ButtonVariant.danger,
            loading: _loading,
            onPressed: _canSubmit ? _withdraw : null,
          ),
        );
      case _Step.done:
        return AuthFrame(
          hero: true,
          body: Padding(
            padding: const EdgeInsets.only(top: V2Space.x12),
            child: Column(
              children: [
                const V2SceneIllustration(V2Scene.letter),
                const SizedBox(height: V2Space.x6),
                Text('탈퇴가 끝났어요', style: V2Text.title),
                const SizedBox(height: V2Space.x2),
                Text(
                  V2Text.keepAll('그동안 비밀기지를 써 주셔서 고마워요. 모든 데이터는 지워졌어요.'),
                  textAlign: TextAlign.center,
                  style: V2Text.cap,
                ),
              ],
            ),
          ),
          footer: V2Button(
            label: '처음 화면으로',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        );
    }
  }
}
