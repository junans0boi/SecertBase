import 'package:flutter/material.dart';

import '../../v2/v2.dart';

String inviteErrorMessage(String code) => switch (code) {
  'recipient_not_found' => '없는 코드예요. 초대장을 보낸 분께 다시 확인해 주세요.',
  'cannot_pair_with_self' => '내가 보낸 초대장이에요. 상대에게 전해 주세요.',
  'active_couple_exists' => '이 분은 지금 다른 상대와 연결되어 있어요.',
  'request_already_pending' => '이미 대기 중인 요청이 있어요.',
  'network_error' => '인터넷 연결을 확인하고 다시 시도해 주세요.',
  _ => '요청을 보내지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 초대장 링크로 들어온 사용자에게 "보낼까요?"를 묻는다.
/// 버튼을 누르기 전에는 어떤 요청도 서버로 나가지 않는다.
class InviteConfirmScreen extends StatefulWidget {
  const InviteConfirmScreen({
    super.key,
    required this.code,
    required this.onSend,
    required this.onDone,
  });

  final String code;

  /// 연결 요청을 보낸다. 성공하면 null, 실패하면 서버 오류 코드를 돌려준다.
  final Future<String?> Function(String code) onSend;

  /// 요청을 보냈거나 사용자가 그만두었을 때.
  final VoidCallback onDone;

  @override
  State<InviteConfirmScreen> createState() => _InviteConfirmScreenState();
}

class _InviteConfirmScreenState extends State<InviteConfirmScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSend(widget.code);
    if (!mounted) return;
    if (err == null || err == 'request_already_pending') {
      widget.onDone();
      return;
    }
    setState(() {
      _busy = false;
      _error = inviteErrorMessage(err);
    });
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '기지 초대장'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(V2Space.page),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '이 분에게 연결 요청을 보낼까요?',
                      textAlign: TextAlign.center,
                      style: V2Text.title,
                    ),
                    const SizedBox(height: V2Space.x3),
                    Text(
                      '초대 코드 ${widget.code}\n'
                      '보내면 상대에게 연결 요청이 가고, 상대가 수락해야 둘이 연결돼요.',
                      textAlign: TextAlign.center,
                      style: V2Text.cap,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: V2Space.x4),
                      V2Banner(tone: V2BannerTone.warn, message: _error!),
                    ],
                    const SizedBox(height: V2Space.x6),
                    V2Button(
                      label: '연결 요청 보내기',
                      onPressed: _busy ? null : _send,
                    ),
                    V2Button(
                      label: '보내지 않을래요',
                      variant: V2ButtonVariant.text,
                      onPressed: _busy ? null : widget.onDone,
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
}
