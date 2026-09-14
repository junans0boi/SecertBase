import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
import '../../core/auth_service.dart';
import '../archive/personal_history_screen.dart';

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _requestsLoading = true;
  String? _error;
  String? _requestsError;
  List<Map<String, dynamic>> _sent = [];
  List<Map<String, dynamic>> _received = [];
  Timer? _pollTimer;

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadRequests(showLoading: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_requestsLoading) {
        _loadRequests();
        _auth.getProfile();
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
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
        _requestsError = '연결 요청을 불러오지 못했어요.';
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

  Future<void> _linkPartner() async {
    if (_loading) return;
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = '상대방 코드를 입력해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await _auth.sendPairingRequest(code);

    if (!mounted) return;
    if (error == null) {
      _codeCtrl.clear();
      setState(() => _loading = false);
      await _loadRequests();
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _respond(int id, String action) async {
    if (_loading) return;
    setState(() => _loading = true);
    final success = await _auth.respondToPairingRequest(id, action);
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      await _loadRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청 상태를 바꾸지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  void _copyMyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원코드가 복사되었습니다. 상대방에게 전달해 주세요.')),
    );
  }

  Future<void> _editProfile() async {
    final controller = TextEditingController(
      text: '${_auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? ''}',
    );
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 이름 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nickname == null || nickname.isEmpty) return;
    await _auth.updateProfile(
      fullName:
          '${_auth.user?['FullName'] ?? _auth.user?['fullName'] ?? nickname}',
      nickname: nickname,
      birthDate:
          '${_auth.user?['BirthDate'] ?? _auth.user?['birthDate'] ?? '2000-01-01'}'
              .split('T')
              .first,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final myCode = _auth.user?['UserCode']?.toString();
    final isPaired = _auth.user?['PartnerCode']?.toString().isNotEmpty == true;
    final partnerName = _partnerName;
    final hasReceivedRequest = _received.any(
      (item) => item['status'] == 'pending',
    );
    final hasSentRequest = _sent.any((item) => item['status'] == 'pending');
    final hasExpiredRequest = [
      ..._sent,
      ..._received,
    ].any((item) => item['status'] == 'expired');

    return Scaffold(
      backgroundColor: kMainBg,
      body: CozyPage(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const BrandLogo(size: 80),
                    const SizedBox(height: 20),
                    Text(
                      isPaired ? '연결된 우리 공간' : '연결 대기 공간',
                      style: mainTitle(size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPaired
                          ? '${partnerName ?? '상대방'}와 연결되어 있어요.\n이제 둘만의 공간을 시작해 보세요.'
                          : '상대방에게 요청을 보내고\n수락을 기다려 주세요.',
                      style: mainBody(size: 14, color: kMainSub),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '개인 검사는 연결이 끊겨도 유지돼요.\n궁합과 커플 검사는 현재 연결된 두 사람에게만 보여요.',
                      style: mainBody(size: 12, color: kMainMuted, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    TextButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(_myName),
                    ),
                    const SizedBox(height: 32),
                    if (!isPaired && myCode != null) _myCodeCard(myCode),
                    if (!isPaired && myCode != null) const SizedBox(height: 24),
                    PartnerConnectionSummary(
                      paired: isPaired,
                      partnerName: partnerName,
                      hasReceivedRequest: hasReceivedRequest,
                      hasSentRequest: hasSentRequest,
                      hasExpiredRequest: hasExpiredRequest,
                      hasRequestError: _requestsError != null,
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: kMainLine),
                    const SizedBox(height: 24),
                    if (!isPaired) _partnerForm(),
                    const SizedBox(height: 24),
                    _requestSection(),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PersonalHistoryScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('개인 보관함 열기'),
                    ),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => _auth.logout(),
                      child: Text(
                        '다른 계정으로 로그인',
                        style: mainBody(size: 13, color: kMainMuted),
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

  Widget _myCodeCard(String code) {
    return MainCard(
      padding: const EdgeInsets.all(20),
      color: kMainSageSoft,
      child: Column(
        children: [
          Text(
            '내 회원코드',
            style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            code,
            style: mainTitle(
              size: 40,
              color: kMainInk,
              weight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _copyMyCode(code),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('내 코드 복사하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kMainInk,
                side: const BorderSide(color: kMainSage),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerForm() {
    return MainCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상대방에게 연결 요청',
            style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            enabled: !_loading,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            onSubmitted: (_) => _linkPartner(),
            style: mainTitle(size: 26, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'ABC123',
              counterText: '',
              filled: true,
              fillColor: kMainPaperSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(_error!, style: mainBody(size: 13, color: kError)),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _linkPartner,
              style: FilledButton.styleFrom(
                backgroundColor: kMainInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '요청 보내기',
                      style: mainBody(
                        size: 16,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestSection() {
    if (_requestsLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: kMainRose),
      );
    }
    if (_requestsError != null) {
      return MainCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _requestsError!,
              textAlign: TextAlign.center,
              style: mainBody(size: 13, color: kMainSub),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => _loadRequests(showLoading: true),
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      );
    }
    final received = _received
        .where((item) => item['status'] == 'pending')
        .toList();
    final sent = _sent.where((item) => item['status'] == 'pending').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (received.isNotEmpty) ...[
          Text('받은 요청', style: mainTitle(size: 20)),
          const SizedBox(height: 10),
          ...received.map((item) => _requestTile(item, receivedRequest: true)),
          const SizedBox(height: 20),
        ],
        if (sent.isNotEmpty) ...[
          Text('보낸 요청', style: mainTitle(size: 20)),
          const SizedBox(height: 10),
          ...sent.map((item) => _requestTile(item, receivedRequest: false)),
        ] else if (received.isEmpty)
          Text(
            '아직 대기 중인 연결 요청이 없어요.',
            style: mainBody(size: 13, color: kMainMuted),
          ),
      ],
    );
  }

  Widget _requestTile(
    Map<String, dynamic> item, {
    required bool receivedRequest,
  }) {
    final candidate = receivedRequest
        ? item['senderNickname']
        : item['recipientNickname'];
    final name = candidate is String && candidate.trim().isNotEmpty
        ? candidate.trim()
        : '상대방';
    return MainCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: mainBody(weight: FontWeight.w700)),
          ),
          if (receivedRequest) ...[
            TextButton(
              onPressed: _loading
                  ? null
                  : () => _respond(item['id'] as int, 'reject'),
              child: const Text('거절'),
            ),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () => _respond(item['id'] as int, 'accept'),
              child: const Text('수락'),
            ),
          ] else
            TextButton(
              onPressed: _loading
                  ? null
                  : () => _respond(item['id'] as int, 'cancel'),
              child: const Text('취소'),
            ),
        ],
      ),
    );
  }

  String get _myName =>
      '${_auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? '프로필'}';

  String? get _partnerName {
    final value = _auth.user?['PartnerName'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}

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
    final (title, description, icon, color) = switch (true) {
      _ when paired => (
        '연결됨',
        '${partnerName ?? '상대방'}와 연결되어 있어요.',
        Icons.favorite_rounded,
        kMainRose,
      ),
      _ when hasRequestError => (
        '상태를 확인할 수 없어요',
        '연결 요청을 다시 불러오면 최신 상태를 확인할 수 있어요.',
        Icons.cloud_off_rounded,
        kMainMuted,
      ),
      _ when hasReceivedRequest => (
        '받은 요청이 있어요',
        '아래 요청을 확인하고 연결 여부를 선택해주세요.',
        Icons.mark_email_unread_outlined,
        kMainRose,
      ),
      _ when hasSentRequest => (
        '수락을 기다리는 중이에요',
        '상대방이 요청을 확인하면 연결돼요.',
        Icons.hourglass_top_rounded,
        kMainSage,
      ),
      _ when hasExpiredRequest => (
        '요청 기간이 끝났어요',
        '새로운 상대방 코드로 다시 요청해주세요.',
        Icons.schedule_rounded,
        kMainMuted,
      ),
      _ => (
        '아직 연결 전이에요',
        '내 코드를 공유하거나 상대방 코드를 입력해 연결을 시작하세요.',
        Icons.link_rounded,
        kMainSage,
      ),
    };

    return MainCard(
      color: kMainPaper,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            color: color,
            backgroundColor: color.withAlpha(28),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: mainBody(size: 13, color: kMainSub, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
