import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import '../../core/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _socket = SocketService();
  final _auth = AuthService();
  final _fullNameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  DateTime? _birthDate;
  Map<String, dynamic>? _coupleInfo;
  DateTime? _anniversaryDate;
  bool _profileSaving = false;
  bool _passwordSaving = false;
  bool _anniversarySaving = false;
  bool _partnerDisconnecting = false;
  String? _profileMessage;
  String? _passwordMessage;
  String? _anniversaryMessage;
  bool _profileSeeded = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _auth.addListener(_rebuild);
    _seedProfileFields();
    _loadCoupleInfo();
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    _auth.removeListener(_rebuild);
    _fullNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    _seedProfileFields();
    setState(() {});
  }

  void _seedProfileFields() {
    if (_profileSeeded || _auth.user == null) return;
    final user = _auth.user!;
    _fullNameCtrl.text =
        '${user['FullName'] ?? user['fullName'] ?? user['UserName'] ?? ''}';
    _nicknameCtrl.text =
        '${user['Nickname'] ?? user['nickname'] ?? user['UserName'] ?? ''}';
    final rawBirthDate = user['BirthDate'] ?? user['birthDate'];
    if (rawBirthDate != null) {
      _birthDate = DateTime.tryParse(rawBirthDate.toString().split('T')[0]);
    }
    _profileSeeded = true;
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('로그아웃', style: mainTitle(size: 24)),
        content: Text('비밀기지에서 로그아웃할까요?', style: mainBody(size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: mainBody(size: 14, color: kMainMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socket.disconnect();
              _auth.logout();
            },
            child: Text(
              '로그아웃',
              style: mainBody(size: 14, color: kError, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisconnectPartner() async {
    final continueDisconnect = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('애인 연결 해제', style: mainTitle(size: 24)),
        content: Text(
          '연결을 해제하면 함께 쓰던 공간이 닫히고 상대방의 기록을 볼 수 없어요. '
          '내가 작성한 기록은 개인 보관함에 남고, 같은 두 사람이 다시 연결하면 이전 기록이 복원돼요.',
          style: mainBody(size: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: mainBody(size: 14, color: kMainMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '계속',
              style: mainBody(size: 14, color: kError, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (continueDisconnect != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('정말 연결을 해제할까요?', style: mainTitle(size: 24)),
        content: Text(
          '상대방의 동의 없이 바로 연결이 해제됩니다.',
          style: mainBody(size: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('돌아가기', style: mainBody(size: 14, color: kMainMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '연결 해제',
              style: mainBody(size: 14, color: kError, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _disconnectPartner();
  }

  Future<void> _disconnectPartner() async {
    if (_partnerDisconnecting) return;
    setState(() => _partnerDisconnecting = true);
    final ok = await _auth.disconnectPartner();
    if (ok) _socket.disconnect();
    if (!mounted) return;
    setState(() {
      _partnerDisconnecting = false;
      if (ok) {
        _coupleInfo = null;
        _anniversaryDate = null;
      }
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('애인 연결을 해제했어요', style: mainBody(color: Colors.white)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연결 해제에 실패했어요', style: mainBody(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    return CozyPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            _accountCard(),
            const SizedBox(height: 12),
            _anniversaryCard(),
            const SizedBox(height: 12),
            _socialCard(),
            const SizedBox(height: 12),
            _profileCard(sock),
            const SizedBox(height: 12),
            _connectionCard(sock),
            const SizedBox(height: 12),
            _presenceCard(sock),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('로그아웃'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kError,
                  side: BorderSide(color: kError.withAlpha(120)),
                  backgroundColor: kMainPaper.withAlpha(210),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '비밀기지 Secret Base',
                style: mainBody(size: 12, color: kMainMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard() => _Card(
    title: '계정 및 연결',
    child: Column(
      children: [
        _InfoRow(
          Icons.badge_outlined,
          kMainSage,
          '닉네임',
          _displayName,
          kMainInk,
        ),
        const SizedBox(height: 10),
        _InfoRow(
          Icons.qr_code_scanner_outlined,
          kMainInk,
          '내 회원코드',
          _auth.user?['UserCode'] ?? '-',
          kMainInk,
        ),
        const SizedBox(height: 12),
        const Divider(color: kMainLine),
        const SizedBox(height: 10),
        _InfoRow(
          Icons.favorite_outline,
          kMainRose,
          '연결된 애인',
          _auth.user?['PartnerCode'] ?? '없음',
          _auth.user?['PartnerCode'] != null ? kMainRose : kMainMuted,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showProfileSheet,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('프로필 수정'),
                style: _compactButtonStyle(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showPasswordSheet,
                icon: const Icon(Icons.password_outlined, size: 17),
                label: const Text('비밀번호'),
                style: _compactButtonStyle(),
              ),
            ),
          ],
        ),
        if (_auth.user?['PartnerCode'] != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _partnerDisconnecting
                  ? null
                  : _confirmDisconnectPartner,
              icon: const Icon(Icons.heart_broken_outlined, size: 17),
              label: Text(_partnerDisconnecting ? '해제 중...' : '애인 연결 해제'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kError,
                backgroundColor: kMainPaperSoft,
                side: BorderSide(color: kError.withAlpha(120)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _anniversaryCard() => _Card(
    title: '기념일',
    child: Column(
      children: [
        _InfoRow(
          Icons.favorite_border,
          kMainRose,
          '시작일',
          _anniversaryDate == null ? '미설정' : _dateOnly(_anniversaryDate!),
          _anniversaryDate == null ? kMainMuted : kMainRose,
        ),
        if (_coupleInfo?['dDay'] != null) ...[
          const SizedBox(height: 10),
          _InfoRow(
            Icons.favorite,
            kMainRose,
            'D-Day',
            'D+${_coupleInfo!['dDay']}',
            kMainRose,
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAnniversarySheet,
            icon: const Icon(Icons.edit_calendar_outlined, size: 17),
            label: Text(_anniversaryDate == null ? '기념일 추가' : '기념일 수정'),
            style: _compactButtonStyle(),
          ),
        ),
      ],
    ),
  );

  Widget _socialCard() {
    final provider = '${_auth.user?['AuthProvider'] ?? 'password'}';
    final hasGoogle =
        _auth.user?['GoogleLinked'] == true ||
        (_auth.user?['GooglePictureUrl'] != null) ||
        provider == 'google';
    return _Card(
      title: '소셜 로그인 연동 정보',
      child: Column(
        children: [
          _InfoRow(
            Icons.login_outlined,
            hasGoogle ? kSuccess : kMainMuted,
            'Google',
            hasGoogle ? '연동됨' : '미연동',
            hasGoogle ? kSuccess : kMainMuted,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            Icons.account_circle_outlined,
            kMainSky,
            '로그인 방식',
            provider,
            null,
          ),
        ],
      ),
    );
  }

  Widget _header() => MainCard(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    child: Row(
      children: [
        DoodleBadge(
          color: kMainSage,
          backgroundColor: kMainSageSoft,
          size: 54,
          child: const Icon(Icons.tune_rounded, color: kMainInk, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('설정', style: mainTitle(size: 28)),
              const SizedBox(height: 2),
              Text('연결 상태를 조용히 확인해요', style: mainBody(size: 13)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _profileCard(SocketService sock) => _Card(
    title: '프로필 이모지',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DoodleBadge(
              color: kMainHoney,
              backgroundColor: kMainHoneySoft,
              size: 48,
              child: Text(
                sock.profileEmoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '대기방에서 보이는 내 프로필이에요',
                style: mainBody(size: 13, color: kMainSub),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SocketService.profileEmojiOptions.map((emoji) {
            final selected = emoji == sock.profileEmoji;
            return InkWell(
              onTap: () => sock.setProfileEmoji(emoji),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? kMainSageSoft : kMainPaperSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? kMainSage : kMainLine,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _connectionCard(SocketService sock) => _Card(
    title: '연결 상태',
    child: Column(
      children: [
        _InfoRow(
          Icons.wifi,
          sock.isConnected ? kSuccess : kError,
          '상태',
          sock.status,
          sock.isConnected ? kSuccess : kError,
        ),
        const SizedBox(height: 10),
        if (sock.userId != null)
          _InfoRow(Icons.person_outline, kMainSage, '사용자', sock.userId!, null),
        if (sock.userId != null) const SizedBox(height: 10),
        if (sock.roomCode != null)
          _InfoRow(
            Icons.meeting_room_outlined,
            kMainSage,
            '방 코드',
            sock.roomCode!,
            null,
          ),
        if (sock.roomCode != null) const SizedBox(height: 10),
        if (sock.lastPingMs != null)
          _InfoRow(
            Icons.speed,
            kMainSky,
            'Ping',
            '${sock.lastPingMs}ms',
            _pingColor(sock.lastPingMs!),
          ),
        if (sock.lastPingMs != null) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _socket.ping,
            icon: const Icon(Icons.speed, size: 16),
            label: const Text('Ping 테스트'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kMainInk,
              backgroundColor: kMainPaperSoft,
              side: const BorderSide(color: kMainLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _presenceCard(SocketService sock) => _Card(
    title: '접속자',
    child: sock.presenceUsers.isEmpty
        ? Row(
            children: [
              const Icon(
                Icons.person_off_outlined,
                color: kMainMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('아직 혼자에요', style: mainBody(size: 14, color: kMainMuted)),
            ],
          )
        : Column(
            children: sock.presenceUsers
                .map(
                  (u) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: kSuccess,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _presenceName(sock, u),
                          style: mainBody(
                            color: u == sock.userId ? kMainInk : kMainSub,
                            size: 15,
                            weight: u == sock.userId
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
  );

  static Color _pingColor(int ms) {
    if (ms < 50) return kSuccess;
    if (ms < 150) return kGold;
    return kError;
  }

  String get _displayName =>
      '${_auth.user?['Nickname'] ?? _auth.user?['nickname'] ?? _auth.user?['UserName'] ?? _auth.user?['userName'] ?? '-'}';

  String _presenceName(SocketService sock, String userCode) {
    final name = sock.presenceNicknames[userCode] ?? userCode;
    return userCode == sock.userId ? '$name (나)' : name;
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: mainBody(size: 14, color: kMainInk),
      decoration: _inputDecoration(hint, icon),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: kMainMuted, size: 20),
      filled: true,
      fillColor: kMainPaperSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  ButtonStyle _compactButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: kMainInk,
      backgroundColor: kMainPaperSoft,
      side: const BorderSide(color: kMainLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Future<void> _loadCoupleInfo() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/couple/info?user_id=$uid'),
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] != true) return;
      final rawDate = data['startDate'];
      if (!mounted) return;
      setState(() {
        _coupleInfo = data;
        _anniversaryDate = rawDate == null
            ? null
            : DateTime.tryParse(rawDate.toString().split('T')[0]);
      });
    } catch (_) {}
  }

  Future<void> _showProfileSheet() async {
    _seedProfileFields();
    _profileMessage = null;
    await _showEditSheet(
      title: '프로필 수정',
      builder: (setSheetState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(_fullNameCtrl, '이름', Icons.person_outline),
          const SizedBox(height: 10),
          _field(_nicknameCtrl, '닉네임', Icons.badge_outlined),
          const SizedBox(height: 10),
          _dateTile(
            label: '생년월일',
            value: _birthDate,
            onTap: () async {
              final picked = await _pickFastDate(
                initialDate: _birthDate,
                firstYear: 1900,
                lastYear: DateTime.now().year,
                title: '생년월일 선택',
              );
              if (picked != null) {
                setSheetState(() => _birthDate = picked);
                setState(() {});
              }
            },
          ),
          if (_profileMessage != null) _message(_profileMessage!),
          const SizedBox(height: 14),
          _primarySheetButton(
            label: '저장',
            loading: _profileSaving,
            onPressed: () async {
              setSheetState(() {
                _profileSaving = true;
                _profileMessage = null;
              });
              final ok = await _saveProfile();
              if (!mounted) return;
              setSheetState(() {
                _profileSaving = false;
                _profileMessage = ok ? '저장되었습니다.' : '프로필 저장에 실패했습니다.';
              });
              if (ok && mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPasswordSheet() async {
    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _passwordMessage = null;
    await _showEditSheet(
      title: '비밀번호 변경',
      builder: (setSheetState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            _currentPasswordCtrl,
            '현재 비밀번호',
            Icons.lock_outline,
            obscure: true,
          ),
          const SizedBox(height: 10),
          _field(
            _newPasswordCtrl,
            '새 비밀번호',
            Icons.lock_reset_outlined,
            obscure: true,
          ),
          if (_passwordMessage != null) _message(_passwordMessage!),
          const SizedBox(height: 14),
          _primarySheetButton(
            label: '변경',
            loading: _passwordSaving,
            onPressed: () async {
              setSheetState(() {
                _passwordSaving = true;
                _passwordMessage = null;
              });
              final error = await _savePassword();
              if (!mounted) return;
              setSheetState(() {
                _passwordSaving = false;
                _passwordMessage = error ?? '변경되었습니다.';
              });
              if (error == null && mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAnniversarySheet() async {
    _anniversaryMessage = null;
    await _showEditSheet(
      title: '기념일 설정',
      builder: (setSheetState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateTile(
            label: '시작일',
            value: _anniversaryDate,
            onTap: () async {
              final picked = await _pickFastDate(
                initialDate: _anniversaryDate ?? DateTime.now(),
                firstYear: 2000,
                lastYear: DateTime.now().year,
                title: '기념일 선택',
              );
              if (picked != null) {
                setSheetState(() => _anniversaryDate = picked);
                setState(() {});
              }
            },
          ),
          if (_anniversaryMessage != null) _message(_anniversaryMessage!),
          const SizedBox(height: 14),
          _primarySheetButton(
            label: '저장',
            loading: _anniversarySaving,
            onPressed: () async {
              setSheetState(() {
                _anniversarySaving = true;
                _anniversaryMessage = null;
              });
              final ok = await _saveAnniversary();
              if (!mounted) return;
              setSheetState(() {
                _anniversarySaving = false;
                _anniversaryMessage = ok ? '저장되었습니다.' : '기념일 저장에 실패했습니다.';
              });
              if (ok && mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet({
    required String title,
    required Widget Function(StateSetter setSheetState) builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kMainPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: mainTitle(size: 24)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                builder(setSheetState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDecoration(label, Icons.calendar_month_outlined),
        child: Text(
          value == null ? '날짜 선택' : _dateOnly(value),
          style: mainBody(
            size: 14,
            color: value == null ? kMainMuted : kMainInk,
          ),
        ),
      ),
    );
  }

  Widget _message(String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        value,
        style: mainBody(
          size: 13,
          color: value == '저장되었습니다.' || value == '변경되었습니다.' ? kSuccess : kError,
        ),
      ),
    );
  }

  Widget _primarySheetButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: kMainInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickFastDate({
    required DateTime? initialDate,
    required int firstYear,
    required int lastYear,
    required String title,
  }) async {
    final now = DateTime.now();
    var year = (initialDate ?? DateTime(now.year, now.month, now.day)).year;
    var month = (initialDate ?? DateTime(now.year, now.month, now.day)).month;
    var day = (initialDate ?? DateTime(now.year, now.month, now.day)).day;
    year = year.clamp(firstYear, lastYear);
    day = day.clamp(1, _daysInMonth(year, month));

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: kMainPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setPickerState) {
          final maxDay = _daysInMonth(year, month);
          if (day > maxDay) day = maxDay;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: mainTitle(size: 24)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          final today = DateTime.now();
                          setPickerState(() {
                            year = today.year.clamp(firstYear, lastYear);
                            month = today.month;
                            day = today.day.clamp(1, _daysInMonth(year, month));
                          });
                        },
                        child: const Text('오늘'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _dateDropdown(
                          value: year,
                          values: [
                            for (var i = lastYear; i >= firstYear; i--) i,
                          ],
                          suffix: '년',
                          onChanged: (value) => setPickerState(() {
                            year = value;
                            day = day.clamp(1, _daysInMonth(year, month));
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dateDropdown(
                          value: month,
                          values: [for (var i = 1; i <= 12; i++) i],
                          suffix: '월',
                          onChanged: (value) => setPickerState(() {
                            month = value;
                            day = day.clamp(1, _daysInMonth(year, month));
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dateDropdown(
                          value: day,
                          values: [for (var i = 1; i <= maxDay; i++) i],
                          suffix: '일',
                          onChanged: (value) =>
                              setPickerState(() => day = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, DateTime(year, month, day)),
                      style: FilledButton.styleFrom(
                        backgroundColor: kMainInk,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('선택'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateDropdown({
    required int value,
    required List<int> values,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: kMainPaperSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
      items: values
          .map(
            (item) =>
                DropdownMenuItem(value: item, child: Text('$item$suffix')),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  String _dateOnly(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<bool> _saveProfile() async {
    final fullName = _fullNameCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    if (fullName.isEmpty || nickname.isEmpty || _birthDate == null) {
      setState(() => _profileMessage = '이름, 닉네임, 생년월일을 모두 입력해주세요.');
      return false;
    }

    final ok = await _auth.updateProfile(
      fullName: fullName,
      nickname: nickname,
      birthDate: _dateOnly(_birthDate!),
    );
    if (ok) _profileSeeded = false;
    return ok;
  }

  Future<String?> _savePassword() async {
    final current = _currentPasswordCtrl.text.trim();
    final next = _newPasswordCtrl.text.trim();
    if (current.isEmpty || next.isEmpty) {
      setState(() => _passwordMessage = '현재 비밀번호와 새 비밀번호를 입력해주세요.');
      return _passwordMessage;
    }

    final error = await _auth.updatePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (error == null) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
    }
    return error;
  }

  Future<bool> _saveAnniversary() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null || _anniversaryDate == null) {
      setState(() => _anniversaryMessage = '기념일을 선택해주세요.');
      return false;
    }
    try {
      final res = await http.patch(
        Uri.parse('${_auth.baseUrl}/api/couple/info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': uid,
          'start_date': _dateOnly(_anniversaryDate!),
        }),
      );
      final ok = res.statusCode == 200;
      if (ok) await _loadCoupleInfo();
      return ok;
    } catch (_) {
      return false;
    }
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: mainBody(
              size: 12,
              color: kMainSub,
              weight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(
    this.icon,
    this.iconColor,
    this.label,
    this.value,
    this.valueColor,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text(label, style: mainBody(size: 13, color: kMainMuted, height: 1)),
        const Spacer(),
        Text(
          value,
          style: mainBody(
            color: valueColor ?? kMainInk,
            size: 13,
            weight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}
