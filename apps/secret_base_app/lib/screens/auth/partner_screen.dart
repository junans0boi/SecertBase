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
      if (mounted && RegExp(r'^[A-Z0-9]{6}$').hasMatch(text) && text != mine) {
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
      showV2Snack(context, '요청을 처리하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
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

  String _ago(Object? iso) {
    final t = iso is String ? DateTime.tryParse(iso) : null;
    if (t == null) return '방금 전';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금 전';
    if (d.inHours < 1) return '${d.inMinutes}분 전';
    if (d.inDays < 1) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final paired = _auth.user?['PartnerCode']?.toString().isNotEmpty == true;
    final (children, footer) = paired ? (_pairedBody(), null) : _unpairedBody();
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        V2Space.page,
                        V2Space.x2,
                        V2Space.page,
                        V2Space.x4,
                      ),
                      children: children,
                    ),
                  ),
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        V2Space.page,
                        V2Space.x2,
                        V2Space.page,
                        V2Space.x4,
                      ),
                      child: footer,
                    ),
                ],
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

  (List<Widget>, Widget?) _unpairedBody() {
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
    final showShare =
        !_requestsLoading && receivedPending.isEmpty && !waiting && !_inputMode;
    final showInput =
        !_requestsLoading && receivedPending.isEmpty && !waiting && _inputMode;

    final children = <Widget>[
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
        Text('직접 코드를 보내려면', style: V2Text.bodyStrong.copyWith(fontSize: 14)),
        const SizedBox(height: V2Space.x2),
        _codeCard(),
      ] else if (waiting)
        ..._waitingView(sentPending.first)
      else if (_inputMode)
        ..._inputView()
      else
        ..._shareView(),
    ];

    final Widget? footer;
    if (waiting) {
      footer = _archiveCard();
    } else if (showShare && _myCode != null) {
      footer = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2Button(
            label: '초대 보내기',
            icon: V2Icons.share,
            onPressed: () => _openInviteSheet(_myCode!),
          ),
          V2Button(
            label: '상대에게 코드를 받았어요',
            variant: V2ButtonVariant.text,
            onPressed: () => _setInputMode(true),
          ),
        ],
      );
    } else if (showShare) {
      footer = V2Button(
        label: '상대에게 코드를 받았어요',
        variant: V2ButtonVariant.text,
        onPressed: () => _setInputMode(true),
      );
    } else if (showInput) {
      footer = V2Button(
        label: '연결 요청 보내기',
        loading: _busy,
        onPressed: _busy || _codeCtrl.text.trim().length != 6
            ? null
            : _sendRequest,
      );
    } else {
      footer = null;
    }
    return (children, footer);
  }

  Widget _codeCard() {
    final code = _myCode;
    if (code == null) {
      return V2Card(
        variant: V2CardVariant.soft,
        child: Column(
          children: [
            Text('내 코드를 불러오지 못했어요', style: V2Text.bodyStrong),
            const SizedBox(height: V2Space.x2),
            Text('인터넷 연결을 확인하고 다시 불러와 주세요.', style: V2Text.cap),
            const SizedBox(height: V2Space.x3),
            V2Button(
              label: '다시 불러오기',
              variant: V2ButtonVariant.soft,
              size: V2ButtonSize.sm,
              onPressed: () => _auth.getProfile(),
            ),
          ],
        ),
      );
    }
    final p = V2Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        V2Space.x5,
        V2Space.x4,
        V2Space.x5,
        V2Space.x4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.soft, p.primarySoft],
        ),
        borderRadius: V2Radius.cardAll,
        border: Border.all(color: p.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 초대 코드', style: V2Text.label.copyWith(color: p.onPrimarySoft)),
          const SizedBox(height: V2Space.x1),
          Semantics(
            label: '내 초대 코드 ${code.split('').join(' ')}',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  code,
                  style: V2Text.sans(
                    size: 44,
                    weight: FontWeight.w800,
                    color: p.ink,
                    height: 1.3,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: V2Space.x2),
          Row(
            children: [
              Expanded(child: Text('상대에게만 알려 주세요', style: V2Text.cap)),
              _WhitePillButton(
                label: '복사',
                icon: V2Icons.copy,
                semanticLabel: '내 코드 복사',
                onPressed: () => _copy(code, '코드를 복사했어요. 상대에게 보내 주세요.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inviteBubble(String code) {
    final p = V2Palette.of(context);
    final text = _inviteText(code);
    final i = text.indexOf(code);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Space.x4),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: V2Radius.cardAll,
        border: Border.all(color: p.line),
      ),
      child: Text.rich(
        TextSpan(
          style: V2Text.body.copyWith(color: p.ink),
          children: [
            TextSpan(text: text.substring(0, i)),
            TextSpan(
              text: code,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: text.substring(i + code.length)),
          ],
        ),
      ),
    );
  }

  Future<void> _openInviteSheet(String code) {
    return showV2Sheet<void>(
      context,
      title: '초대 문구 보내기',
      subtitle: '이 문구를 복사해서 메시지나 메일에 붙여넣어 보내 주세요.',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inviteBubble(code),
          const SizedBox(height: V2Space.x3),
          Row(
            children: [
              Expanded(
                child: V2Button(
                  label: '문구 복사',
                  icon: V2Icons.copy,
                  variant: V2ButtonVariant.soft,
                  size: V2ButtonSize.sm,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _copy(_inviteText(code), '초대 문구를 복사했어요. 메시지에 붙여넣어 보내 주세요.');
                  },
                ),
              ),
              const SizedBox(width: V2Space.x2),
              Expanded(
                child: V2Button(
                  label: '코드만 복사',
                  icon: V2Icons.link,
                  variant: V2ButtonVariant.soft,
                  size: V2ButtonSize.sm,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _copy(code, '코드를 복사했어요. 상대에게 보내 주세요.');
                  },
                ),
              ),
            ],
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
      Text('상대가 코드를 입력하고 수락하면 바로 연결돼요.', style: V2Text.cap),
      const SizedBox(height: V2Space.x5),
      _codeCard(),
      if (code != null) ...[
        const SizedBox(height: V2Space.x4),
        Text('보낼 문구 미리보기', style: V2Text.bodyStrong.copyWith(fontSize: 14)),
        const SizedBox(height: V2Space.x2),
        _inviteBubble(code),
      ],
    ];
  }

  List<Widget> _inputView() {
    final p = V2Palette.of(context);
    return [
      Text('받은 코드를 입력해 주세요', style: V2Text.title),
      const SizedBox(height: V2Space.x1),
      Text('영문 대문자와 숫자 6자리예요.', style: V2Text.cap),
      const SizedBox(height: V2Space.x5),
      _CodeCells(
        controller: _codeCtrl,
        enabled: !_busy,
        error: _codeError,
        onChanged: (_) => setState(() => _codeError = null),
        onSubmitted: (_) => _sendRequest(),
      ),
      if (_clipboardCode != null) ...[
        const SizedBox(height: V2Space.x4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: V2Space.x4,
            vertical: V2Space.x3,
          ),
          decoration: BoxDecoration(
            color: p.soft,
            borderRadius: V2Radius.cardAll,
          ),
          child: Row(
            children: [
              Icon(V2Icons.copy, size: 20, color: p.primary),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('복사한 코드가 있어요', style: V2Text.cap),
                    Text(
                      _clipboardCode!,
                      style: V2Text.bodyStrong.copyWith(letterSpacing: 2),
                    ),
                  ],
                ),
              ),
              V2Button(
                label: '붙여넣기',
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
      const SizedBox(height: V2Space.x2),
      V2Button(
        label: '내 코드 보내기',
        variant: V2ButtonVariant.text,
        onPressed: _busy ? null : () => _setInputMode(false),
      ),
    ];
  }

  Widget _receivedCard(Map<String, dynamic> item) {
    final p = V2Palette.of(context);
    final name = _nameOf(item, received: true);
    return Container(
      padding: const EdgeInsets.all(V2Space.x4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: V2Radius.cardAll,
        border: Border.all(color: p.primary, width: 2),
        boxShadow: V2Shadow.level2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              V2Avatar(name: name, color: V2Avatar.partnerColor),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name님이 연결을 요청했어요', style: V2Text.head),
                    Text(_ago(item['createdAt']), style: V2Text.cap),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          Text('수락하면 둘만의 공간이 만들어져요. 연결은 설정에서 언제든 끊을 수 있어요.', style: V2Text.cap),
          const SizedBox(height: V2Space.x4),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: V2Button(
                  label: '거절',
                  variant: V2ButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: _busy
                      ? null
                      : () => _respond(item['id'] as int, 'reject'),
                ),
              ),
              const SizedBox(width: V2Space.x3),
              Expanded(
                flex: 5,
                child: V2Button(
                  label: '수락하기',
                  loading: _busy,
                  fullWidth: true,
                  onPressed: _busy
                      ? null
                      : () => _respond(item['id'] as int, 'accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _waitingView(Map<String, dynamic> item) {
    final p = V2Palette.of(context);
    final name = _nameOf(item, received: false);
    return [
      const SizedBox(height: V2Space.x10),
      Center(
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              V2Avatar(name: _myName, size: V2AvatarSize.lg),
              const SizedBox(width: V2Space.x3),
              for (var i = 0; i < 4; i++) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.primary.withValues(alpha: 0.25 + 0.25 * i),
                  ),
                ),
                if (i < 3) const SizedBox(width: 6),
              ],
              const SizedBox(width: V2Space.x3),
              V2Avatar(
                name: name,
                color: V2Avatar.partnerColor,
                size: V2AvatarSize.lg,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: V2Space.x5),
      Semantics(
        liveRegion: true,
        child: Text(
          '$name님의 수락을\n기다리고 있어요',
          textAlign: TextAlign.center,
          style: V2Text.title,
        ),
      ),
      const SizedBox(height: V2Space.x2),
      Text(
        '수락하면 바로 연결돼요.\n이 화면을 열어 두지 않아도 돼요.',
        textAlign: TextAlign.center,
        style: V2Text.body.copyWith(color: p.sub),
      ),
      const SizedBox(height: V2Space.x5),
      Center(
        child: V2Button(
          label: '요청 취소',
          variant: V2ButtonVariant.ghost,
          size: V2ButtonSize.sm,
          onPressed: _busy ? null : () => _respond(item['id'] as int, 'cancel'),
        ),
      ),
    ];
  }

  Widget _archiveCard() => V2Card(
    padding: const EdgeInsets.all(V2Space.x3),
    child: Row(
      children: [
        const V2Art(icon: V2Icons.record, tone: V2Tone.ok, size: 44),
        const SizedBox(width: V2Space.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('개인 보관함', style: V2Text.bodyStrong),
              Text('기다리는 동안 먼저 기록해 보세요.', style: V2Text.cap),
            ],
          ),
        ),
        const SizedBox(width: V2Space.x2),
        V2Button(
          label: '기록하기',
          variant: V2ButtonVariant.soft,
          size: V2ButtonSize.sm,
          onPressed: openPersonalArchive,
        ),
      ],
    ),
  );

  void openPersonalArchive() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PersonalHistoryScreen()),
  );
}

/// 흰 알약 보조 버튼(코드 카드 위의 '복사').
class _WhitePillButton extends StatelessWidget {
  const _WhitePillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        borderRadius: V2Radius.buttonAll,
        child: InkWell(
          borderRadius: V2Radius.buttonAll,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: V2Space.tap,
              minWidth: V2Space.tap,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: V2Space.x4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: p.onPrimarySoft),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: V2Text.buttonSm.copyWith(color: p.onPrimarySoft),
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

/// 6칸 코드 입력. 보이지 않는 TextField 하나가 입력을 받고 칸은 그 값을 그린다.
class _CodeCells extends StatefulWidget {
  const _CodeCells({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.error,
    this.enabled = true,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final String? error;
  final bool enabled;

  @override
  State<_CodeCells> createState() => _CodeCellsState();
}

class _CodeCellsState extends State<_CodeCells> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final hasError = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([widget.controller, _focus]),
          builder: (context, _) {
            final text = widget.controller.text;
            final active = _focus.hasFocus ? text.length.clamp(0, 5) : -1;
            return Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < 6; i++) ...[
                        Expanded(
                          child: _cell(
                            p,
                            i < text.length ? text[i] : '',
                            focused: i == active,
                            error: hasError,
                          ),
                        ),
                        if (i < 5) const SizedBox(width: V2Space.x2),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Semantics(
                    label: '상대의 초대 코드',
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      autofocus: true,
                      maxLength: 6,
                      maxLines: null,
                      expands: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                      cursorColor: Colors.transparent,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        counterText: '',
                        filled: false,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]'),
                        ),
                        TextInputFormatter.withFunction(
                          (old, v) => v.copyWith(text: v.text.toUpperCase()),
                        ),
                      ],
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: V2Space.x2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: hasError
              ? Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(V2Icons.warn, size: 16, color: p.err),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: V2Text.cap.copyWith(color: V2Colors.errText),
                        ),
                      ),
                    ],
                  ),
                )
              : Text('상대의 초대 코드를 입력해 주세요.', style: V2Text.cap),
        ),
      ],
    );
  }

  Widget _cell(
    V2Palette p,
    String ch, {
    required bool focused,
    required bool error,
  }) {
    final border = error ? p.err : (focused ? p.primary : V2Colors.fieldBorder);
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: V2Radius.cardAll,
        border: Border.all(color: border, width: focused || error ? 1.5 : 1),
        boxShadow: focused || error
            ? [
                BoxShadow(
                  color: (error ? p.errSoft : p.primarySoft),
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Text(
        ch,
        textScaler: TextScaler.noScaling,
        style: V2Text.sans(
          size: 24,
          weight: FontWeight.w800,
          color: error ? V2Colors.errText : p.ink,
          height: 1,
        ),
      ),
    );
  }
}

/// 공유 → 입력 → 축하 3단계 표시: 동그라미 아래에 이름, 사이를 선이 잇는다.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    const labels = ['공유', '입력', '축하'];
    const dot = 28.0;
    Widget stepCol(int i) {
      final n = i + 1;
      final reached = n <= step;
      return SizedBox(
        width: 44,
        child: Column(
          children: [
            Container(
              width: dot,
              height: dot,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? p.primary : p.soft2,
              ),
              child: n < step
                  ? Icon(V2Icons.check, size: 16, color: p.onPrimary)
                  : Text(
                      '$n',
                      textScaler: TextScaler.noScaling,
                      style: V2Text.label.copyWith(
                        fontSize: 13,
                        color: reached ? p.onPrimary : p.sub,
                      ),
                    ),
            ),
            const SizedBox(height: V2Space.x1),
            Text(
              labels[i],
              textScaler: TextScaler.noScaling,
              style: V2Text.label.copyWith(color: reached ? p.primary : p.sub),
            ),
          ],
        ),
      );
    }

    Widget line(bool on) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: dot / 2 - 1),
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: V2Space.x2),
          decoration: BoxDecoration(
            color: on ? p.primary : p.line2,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );

    return Semantics(
      label: '3단계 중 $step단계: ${labels[step - 1]}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stepCol(0),
            line(step > 1),
            stepCol(1),
            line(step > 2),
            stepCol(2),
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
      _ when paired => ('연결됨', '$name님과 연결되어 있어요.', V2Icons.heart, V2Tone.rose),
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
            decoration: BoxDecoration(
              color: colors.soft,
              shape: BoxShape.circle,
            ),
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
