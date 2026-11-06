import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import '../../core/socket_service.dart';
import '../../v2/v2.dart';
import 'settings_common.dart';

/// 회원 탈퇴 3단계. 1·2단계에서는 "그만두기"가 큰 버튼이고, 마지막 단계만
/// 빨간 "탈퇴하기"가 주 버튼이에요.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, this.apiClient});

  /// Tests inject a fake-server client.
  final ApiClient? apiClient;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _reasons = [
    '자주 쓰지 않아요',
    '상대와 연결이 끊겼어요',
    '개인정보가 걱정돼요',
    '쓰기 불편해요',
    '기타',
  ];

  final _auth = AuthService();
  final _password = TextEditingController();
  final _phrase = TextEditingController();
  int _step = 0;
  bool _acknowledged = false;
  String? _reason;
  bool _deleting = false;
  String? _passwordError;
  String? _failure;

  /// 탈퇴 요청은 전용 클라이언트로 보내요. 앱 공용 클라이언트는 401을 받으면
  /// 자동으로 로그아웃시키는데, 서버가 "비밀번호가 틀림"도 401로 알려 줘서
  /// 비밀번호를 잘못 쳐도 로그아웃돼 버리기 때문이에요.
  Future<String?> _requestDelete() async {
    final api =
        widget.apiClient ??
        ApiClient(baseUrl: _auth.baseUrl, tokenProvider: () => _auth.token);
    try {
      final body = <String, dynamic>{};
      final password = _password.text.trim();
      if (_needsPassword && password.isNotEmpty) body['password'] = password;
      await api.deleteJson('/api/user', body: body);
      await _auth.logout();
      return null;
    } on ApiException catch (e) {
      return e.code;
    } catch (_) {
      return 'network_error';
    }
  }

  bool get _needsPassword => needsPasswordToDelete(_auth.user);

  @override
  void dispose() {
    _password.dispose();
    _phrase.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _passwordError = null;
      _failure = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    final error = await _requestDelete();
    if (!mounted) return;
    if (error == null) {
      SocketService().disconnect();
      // 로그아웃은 deleteAccount 안에서 끝났어요. 쌓인 화면을 비워 처음 화면을 보여 줘요.
      nav.popUntil((r) => r.isFirst);
      messenger?.showSnackBar(
        const SnackBar(content: Text('계정과 기록이 삭제됐어요. 그동안 함께해 주셔서 고마워요.')),
      );
      return;
    }
    setState(() {
      _deleting = false;
      switch (error) {
        case 'invalid_password':
          _passwordError = '비밀번호가 맞지 않아요.';
        case 'password_required':
          _passwordError = '비밀번호를 입력해 주세요.';
        default:
          _failure = '탈퇴를 마치지 못했어요. 네트워크를 확인하고 다시 시도해 주세요. 계정과 기록은 그대로예요.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final partner = partnerDisplayName(_auth.user);
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(
          title: '회원 탈퇴',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: MoreStepChip(step: _step + 1, total: 3)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: switch (_step) {
            0 => _stepOne(partner),
            1 => _stepTwo(),
            _ => _stepThree(),
          },
        ),
      ),
    );
  }

  List<Widget> _stepOne(String? partner) {
    return [
      Text('정말 떠나시나요?', style: V2Text.title),
      const SizedBox(height: 6),
      Text('탈퇴하면 아래 내용이 모두 삭제돼요.', style: V2Text.cap),
      const SizedBox(height: 16),
      V2List(
        children: [
          const V2ListTile(
            icon: V2Icons.record,
            tone: V2Tone.rose,
            title: '내가 남긴 기록',
            subtitle: '사진 · 영상 · 글',
          ),
          const V2ListTile(
            icon: V2Icons.lock,
            tone: V2Tone.sage,
            title: '개인 보관함',
            subtitle: '연결 전에 남긴 기록',
          ),
          const V2ListTile(
            icon: V2Icons.shop,
            tone: V2Tone.honey,
            title: '코인과 모은 아이템',
            subtitle: '복구할 수 없어요',
          ),
          if (partner != null)
            V2ListTile(
              icon: V2Icons.couple,
              tone: V2Tone.lilac,
              title: '${withWaGwa(partner)}의 연결',
              subtitle: '함께 쓰던 공간이 닫혀요',
            ),
        ],
      ),
      const SizedBox(height: 16),
      V2Check(
        value: _acknowledged,
        onChanged: (v) => setState(() => _acknowledged = v),
        label: '되돌릴 수 없다는 걸 확인했어요',
      ),
      const SizedBox(height: 24),
      V2Button(label: '그만두기', onPressed: _cancel),
      const SizedBox(height: 8),
      V2Button(
        label: '계속 탈퇴하기',
        variant: V2ButtonVariant.text,
        onPressed: _acknowledged ? () => setState(() => _step = 1) : null,
      ),
    ];
  }

  List<Widget> _stepTwo() {
    return [
      Text('떠나는 이유를 알려 주실래요?', style: V2Text.title),
      const SizedBox(height: 6),
      Text('서비스를 나아지게 하는 데만 쓰고, 건너뛰어도 괜찮아요.', style: V2Text.cap),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in _reasons)
            V2Chip(
              label: r,
              selected: _reason == r,
              onTap: () => setState(() => _reason = _reason == r ? null : r),
            ),
        ],
      ),
      const SizedBox(height: 24),
      V2Button(label: '그만두기', onPressed: _cancel),
      const SizedBox(height: 8),
      V2Button(
        label: '다음 단계로',
        variant: V2ButtonVariant.text,
        onPressed: () => setState(() => _step = 2),
      ),
    ];
  }

  List<Widget> _stepThree() {
    final ready =
        _phrase.text.trim() == '탈퇴' &&
        (!_needsPassword || _password.text.trim().isNotEmpty);
    return [
      Text('마지막 확인이에요', style: V2Text.title),
      const SizedBox(height: 6),
      Text(
        _needsPassword
            ? '본인 확인을 위해 비밀번호를 입력해 주세요.'
            : 'Google 계정으로 로그인 중이에요. 확인 문구만 입력하면 바로 탈퇴해요.',
        style: V2Text.cap,
      ),
      const SizedBox(height: 16),
      if (_failure != null) ...[
        V2Banner(
          tone: V2BannerTone.err,
          title: '탈퇴를 마치지 못했어요',
          message: _failure!,
        ),
        const SizedBox(height: 16),
      ],
      if (_needsPassword) ...[
        V2TextField(
          label: '비밀번호',
          password: true,
          controller: _password,
          error: _passwordError,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
      ],
      V2TextField(
        label: '아래에 ‘탈퇴’라고 입력해 주세요',
        controller: _phrase,
        hint: '탈퇴',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      V2Button(
        label: _failure != null ? '다시 시도' : '탈퇴하기',
        variant: V2ButtonVariant.danger,
        loading: _deleting,
        onPressed: ready ? _delete : null,
      ),
      const SizedBox(height: 8),
      V2Button(
        label: '그만두기',
        variant: V2ButtonVariant.text,
        onPressed: _deleting ? null : _cancel,
      ),
    ];
  }
}
