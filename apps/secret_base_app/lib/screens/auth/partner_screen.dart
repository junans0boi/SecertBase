import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import '../archive/personal_history_screen.dart';
import 'account_menu.dart';
import 'auth_parts.dart';

/// 상대와 연결하기: 공유(내 코드) → 입력(받은 코드) → 축하(main.dart가 보여 줌).
/// 연결 전에도 개인 보관함과 계정 메뉴(고객센터·약관·로그아웃·탈퇴)에 닿는다.
class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  final _codeCtrl = TextEditingController();
  final _auth = AuthService();

  bool _busy = false;
  bool _requestsLoading = true;
  bool _inputMode = false;
  String? _codeError;
  String? _requestsError;
  String? _clipboardCode;
  List<Map<String, dynamic>> _sent = [];
  List<Map<String, dynamic>> _received = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    _loadRequests(showLoading: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_requestsLoading && !_busy) {
        _loadRequests();
        _auth.getProfile();
      }
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _codeCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRequests({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _requestsLoading = true;
        _requestsError = null;
      });
    }
    final data = await _auth.getPairingRequests();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _requestsLoading = false;
        _requestsError = '연결 요청을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.';
      });
      return;
    }
    setState(() {
      _sent = ((data['sent'] as List?) ?? []).cast<Map<String, dynamic>>();
      _received = ((data['received'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
      _requestsLoading = false;
      _requestsError = null;
    });
  }

  Future<void> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (data?.text ?? '').trim().toUpperCase();
      final mine = _myCode?.toUpperCase();
      if (mounted &&
          RegExp(r'^[A-Z0-9]{6}$').hasMatch(text) &&
          text != mine) {
        setState(() => _clipboardCode = text);
      }
    } catch (_) {}
  }

  void _setInputMode(bool on) {
    setState(() {
      _inputMode = on;
      _codeError = null;
    });
    if (on) _readClipboard();
  }

  Future<void> _sendRequest() async {
    if (_busy) return;
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _codeError = '영문 대문자와 숫자 6자리를 입력해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _codeError = null;
    });
    final err = await _auth.requestPairing(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _codeCtrl.clear();
      setState(() => _inputMode = false);
      await _loadRequests();
      return;
    }
    switch (err) {
      case 'active_couple_exists':
        final again = await showV2Dialog<bool>(
          context,
          title: '이미 연결된 코드예요',
          message: '이 코드의 주인은 지금 다른 상대와 연결되어 있어요. 코드를 다시 확인해 주세요.',
          actions: const [
            V2DialogAction(label: '코드 다시 입력하기', value: true),
            V2DialogAction(
              label: '내 코드 보내기',
              value: false,
              variant: V2ButtonVariant.text,
            ),
          ],
        );
        if (mounted && again == false) _setInputMode(false);
      case 'recipient_not_found':
        setState(() => _codeError = '없는 코드예요. 상대의 코드를 다시 확인해 주세요.');
      case 'cannot_pair_with_self':
        setState(() => _codeError = '내 코드예요. 상대에게 받은 코드를 입력해 주세요.');
      case 'request_already_pending':
        setState(() => _codeError = '이미 대기 중인 요청이 있어요.');
        await _loadRequests();
      default:
        setState(() => _codeError = authErrorMessage(err));
    }
  }

  Future<void> _respond(int id, String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await _auth.respondToPairingRequest(id, action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await _loadRequests();
    } else {
      showV2Snack(
        context,
        '요청을 처리하지 못했어요. 다시 시도해 주세요.',
        tone: V2Tone.err,
      );
    }
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showV2Snack(context, done);
  }

  String? get _myCode {
    final v = _auth.user?['UserCode']?.toString();
    return v == null || v.isEmpty ? null : v;
  }

  String get _myName {
    final v = '${_auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? ''}'
        .trim();
    return v.isEmpty ? '내' : v;
  }

  String? get _partnerName {
    final value = _auth.user?['PartnerName'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String _inviteText(String code) =>
      '$_myName님이 비밀기지에 초대했어요 💌\n비밀기지 앱에서 코드 $code 를 입력해 주세요.';

  List<Map<String, dynamic>> get _pendingReceived =>
      _received.where((e) => e['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _pendingSent =>
      _sent.where((e) => e['status'] == 'pending').toList();

  String _nameOf(Map<String, dynamic> item, {required bool received}) {
    final v = received ? item['senderNickname'] : item['recipientNickname'];
    return v is String && v.trim().isNotEmpty ? v.trim() : '상대';
  }

  @override
  Widget build(BuildContext context) {
    final paired = _auth.user?['PartnerCode']?.toString().isNotEmpty == true;
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(
          title: paired ? '연결 상태' : '상대와 연결하기',
          actions: [
            V2IconButton(
              icon: V2Icons.menu,
              tooltip: '계정 메뉴',
              onPressed: () => showAccountSheet(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  V2Space.page,
                  V2Space.x2,
                  V2Space.page,
                  V2Space.x8,
                ),
                children: paired ? _pairedBody() : _unpairedBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _pairedBody() => [
    PartnerConnectionSummary(paired: true, partnerName: _partnerName),
    const SizedBox(height: V2Space.x5),
    V2Button(label: '돌아가기', onPressed: () => Navigator.maybePop(context)),
  ];

  List<Widget> _unpairedBody() {
    final receivedPending = _pendingReceived;
    final sentPending = _pendingSent;
    final waiting = receivedPending.isEmpty && sentPending.isNotEmpty;
    final step = receivedPending.isNotEmpty
        ? 1
        : (waiting || _inputMode ? 2 : 1);
    final hasExpired = [
      ..._sent,
      ..._received,
    ].any((e) => e['status'] == 'expired');

    return [
      _StepIndicator(step: step),
      const SizedBox(height: V2Space.x5),
      if (_requestsError != null) ...[
        V2Banner(
          tone: V2BannerTone.warn,
          message: _requestsError!,
          actionLabel: '다시 불러오기',
          onAction: () => _loadRequests(showLoading: true),
        ),
        const SizedBox(height: V2Space.x4),
      ],
      if (hasExpired && sentPending.isEmpty && receivedPending.isEmpty) ...[
        const V2Banner(
          tone: V2BannerTone.info,
          message: '지난 요청의 기간이 끝났어요. 새로 요청해 주세요.',
        ),
        const SizedBox(height: V2Space.x4),
      ],
      if (_requestsLoading)
        const V2SkeletonCard()
      else if (receivedPending.isNotEmpty) ...[
        for (final item in receivedPending) _receivedCard(item),
        const SizedBox(height: V2Space.x5),
        Text('직접 코드를 보내려면', style: V2Text.cap),
        const SizedBox(height: V2Space.x2),
        _codeCard(compact: true),
      ] else if (waiting) ...[
        _waitingCard(sentPending.first),
        const SizedBox(height: V2Space.x5),
        _archiveCard(),
      ] else if (_inputMode)
        ..._inputView()
      else ...[
        ..._shareView(),
        const SizedBox(height: V2Space.x5),
        _archiveCard(),
      ],
    ];
  }

  Widget _codeCard({bool compact = false}) {
    final code = _myCode;
    if (code == null) {
      return const V2SkeletonCard();
    }
    return V2Card(
      gradient: V2Gradients.hero,
      padding: EdgeInsets.all(compact ? V2Space.x4 : V2Space.x5),
      child: Column(
        children: [
          Text(
            '내 초대 코드',
            style: V2Text.label.copyWith(color: Colors.white),
          ),
          const SizedBox(height: V2Space.x2),
          Semantics(
            label: '내 초대 코드 ${code.split('').join(' ')}',
            child: ExcludeSemantics(
              child: Text(
                code,
                style: V2Text.serif(
                  size: compact ? 32 : 44,
                  color: Colors.white,
                ).copyWith(letterSpacing: 6),
              ),
            ),
          ),
          const SizedBox(height: V2Space.x3),
          V2Button(
            label: '코드 복사',
            icon: V2Icons.copy,
            variant: V2ButtonVariant.soft,
            size: V2ButtonSize.sm,
            onPressed: () => _copy(code, '코드를 복사했어요. 상대에게 보내 주세요.'),
          ),
        ],
      ),
    );
  }

  List<Widget> _shareView() {
    final code = _myCode;
    return [
      Text('내 코드를 상대에게 보내 주세요', style: V2Text.title),
      const SizedBox(height: V2Space.x1),
      Text('상대가 코드를 입력하면 연결 요청이 와요. 수락하면 연결돼요.', style: V2Text.cap),
      const SizedBox(height: V2Space.x5),
      _codeCard(),
      if (code != null) ...[
        const SizedBox(height: V2Space.x4),
        V2Card(
          variant: V2CardVariant.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('보낼 문구 미리보기', style: V2Text.label),
              const SizedBox(height: V2Space.x2),
              Text(_inviteText(code), style: V2Text.body),
            ],
          ),
        ),
        const SizedBox(height: V2Space.x4),
        V2Button(
          label: '초대 문구 복사',
          icon: V2Icons.share,
          onPressed: () => _copy(_inviteText(code), '초대 문구를 복사했어요. 메시지에 붙여넣어 보내 주세요.'),
        ),
      ],
      const SizedBox(height: V2Space.x1),
      V2Button(
        label: '상대에게 코드를 받았어요',
        variant: V2ButtonVariant.text,
        onPressed: () => _setInputMode(true),
      ),
    ];
  }

  List<Widget> _inputView() => [
    Text('받은 코드를 입력해 주세요', style: V2Text.title),
    const SizedBox(height: V2Space.x1),
    Text('영문 대문자와 숫자 6자리예요.', style: V2Text.cap),
    const SizedBox(height: V2Space.x5),
    V2TextField(
      label: '상대의 초대 코드',
      hint: 'ABC123',
      controller: _codeCtrl,
      enabled: !_busy,
      autofocus: true,
      maxLength: 6,
      error: _codeError,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        TextInputFormatter.withFunction(
          (old, v) => v.copyWith(text: v.text.toUpperCase()),
        ),
      ],
      onChanged: (_) => setState(() => _codeError = null),
      onSubmitted: (_) => _sendRequest(),
    ),
    if (_clipboardCode != null) ...[
      const SizedBox(height: V2Space.x3),
      V2Card(
        variant: V2CardVariant.soft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('복사한 코드가 있어요', style: V2Text.cap),
                  Text(_clipboardCode!, style: V2Text.bodyStrong),
                ],
              ),
            ),
            V2Button(
              label: '붙여넣기',
              variant: V2ButtonVariant.soft,
              size: V2ButtonSize.sm,
              onPressed: () => setState(() {
                _codeCtrl.text = _clipboardCode!;
                _codeError = null;
              }),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: V2Space.x5),
    V2Button(
      label: '연결 요청 보내기',
      loading: _busy,
      onPressed: _busy || _codeCtrl.text.trim().length != 6
          ? null
          : _sendRequest,
    ),
    V2Button(
      label: '내 코드 보내기',
      variant: V2ButtonVariant.text,
      onPressed: _busy ? null : () => _setInputMode(false),
    ),
  ];

  Widget _receivedCard(Map<String, dynamic> item) {
    final name = _nameOf(item, received: true);
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              V2Avatar(name: name, color: V2Avatar.partnerColor),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Text('$name님이 연결을 요청했어요', style: V2Text.bodyStrong),
              ),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          Text('수락하면 둘만의 공간이 만들어져요. 연결은 설정에서 언제든 끊을 수 있어요.', style: V2Text.cap),
          const SizedBox(height: V2Space.x4),
          V2Button(
            label: '수락하기',
            loading: _busy,
            onPressed: _busy ? null : () => _respond(item['id'] as int, 'accept'),
          ),
          V2Button(
            label: '거절',
            variant: V2ButtonVariant.text,
            onPressed: _busy ? null : () => _respond(item['id'] as int, 'reject'),
          ),
        ],
      ),
    );
  }

  Widget _waitingCard(Map<String, dynamic> item) {
    final name = _nameOf(item, received: false);
    return V2Card(
      child: Column(
        children: [
          V2AvatarPair(me: _myName, partner: name),
          const SizedBox(height: V2Space.x4),
          Text('$name님의 수락을\n기다리고 있어요', textAlign: TextAlign.center, style: V2Text.head),
          const SizedBox(height: V2Space.x2),
          Text(
            V2Text.keepAll('수락하면 바로 연결돼요. 이 화면을 열어 두지 않아도 돼요.'),
            textAlign: TextAlign.center,
            style: V2Text.cap,
          ),
          const SizedBox(height: V2Space.x4),
          V2Button(
            label: '요청 취소',
            variant: V2ButtonVariant.soft,
            onPressed: _busy ? null : () => _respond(item['id'] as int, 'cancel'),
          ),
        ],
      ),
    );
  }

  Widget _archiveCard() => V2Card(
    variant: V2CardVariant.soft,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalHistoryScreen()),
    ),
    child: Row(
      children: [
        const V2Art(icon: V2Icons.lock),
        const SizedBox(width: V2Space.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('개인 보관함', style: V2Text.bodyStrong),
              Text('연결하기 전에도 나만의 기록을 남길 수 있어요.', style: V2Text.cap),
            ],
          ),
        ),
        const Icon(V2Icons.chevron),
      ],
    ),
  );
}

/// 공유 → 입력 → 축하 3단계 표시.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    const labels = ['공유', '입력', '축하'];
    return Semantics(
      label: '3단계 중 $step단계: ${labels[step - 1]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i + 1 <= step ? p.primary : p.soft2,
                ),
                child: i + 1 < step
                    ? Icon(V2Icons.check, size: 14, color: p.onPrimary)
                    : Text(
                        '${i + 1}',
                        style: V2Text.label.copyWith(
                          color: i + 1 == step ? p.onPrimary : p.sub,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              Text(
                labels[i],
                style: V2Text.label.copyWith(
                  color: i + 1 == step ? p.ink : p.sub,
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: i + 1 < step ? p.primary : p.line,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 연결 상태 요약 카드(연결됨/요청 대기/받은 요청/끝난 요청/불러오기 실패).
class PartnerConnectionSummary extends StatelessWidget {
  const PartnerConnectionSummary({
    super.key,
    required this.paired,
    this.partnerName,
    this.hasReceivedRequest = false,
    this.hasSentRequest = false,
    this.hasExpiredRequest = false,
    this.hasRequestError = false,
  });

  final bool paired;
  final String? partnerName;
  final bool hasReceivedRequest;
  final bool hasSentRequest;
  final bool hasExpiredRequest;
  final bool hasRequestError;

  @override
  Widget build(BuildContext context) {
    final name = partnerName ?? '상대';
    final (title, description, icon, tone) = switch (true) {
      _ when paired => (
        '연결됨',
        '$name님과 연결되어 있어요.',
        V2Icons.heart,
        V2Tone.rose,
      ),
      _ when hasRequestError => (
        '상태를 확인할 수 없어요',
        '연결 요청을 다시 불러오면 최신 상태를 확인할 수 있어요.',
        V2Icons.offline,
        V2Tone.neutral,
      ),
      _ when hasReceivedRequest => (
        '받은 요청이 있어요',
        '아래 요청을 확인하고 연결 여부를 선택해 주세요.',
        V2Icons.send,
        V2Tone.rose,
      ),
      _ when hasSentRequest => (
        '수락을 기다리는 중이에요',
        '상대가 요청을 확인하면 연결돼요.',
        V2Icons.refresh,
        V2Tone.sage,
      ),
      _ when hasExpiredRequest => (
        '요청 기간이 끝났어요',
        '새로운 코드로 다시 요청해 주세요.',
        V2Icons.calendar,
        V2Tone.neutral,
      ),
      _ => (
        '아직 연결 전이에요',
        '내 코드를 보내거나 상대의 코드를 입력해 연결을 시작해요.',
        V2Icons.link,
        V2Tone.sage,
      ),
    };
    final colors = V2ToneColors.of(tone);
    return V2Card(
      variant: V2CardVariant.soft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: colors.soft, shape: BoxShape.circle),
            child: Icon(icon, color: colors.text),
          ),
          const SizedBox(width: V2Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: V2Text.bodyStrong),
                const SizedBox(height: 2),
                Text(description, style: V2Text.cap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
