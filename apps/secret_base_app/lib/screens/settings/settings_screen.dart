import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import '../../core/auth_service.dart';
import '../auth/auth_layout.dart';
import '../relationship/relationship_understanding_screen.dart';
import '../secret_base/secret_base_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const SettingsScreen({super.key, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) =>
            _MoreOverview(auth: _auth, onNavigate: widget.onNavigate),
      ),
    );
  }
}

class _MoreOverview extends StatelessWidget {
  final AuthService auth;
  final ValueChanged<int>? onNavigate;

  const _MoreOverview({required this.auth, required this.onNavigate});

  void _goToTab(int index) => onNavigate?.call(index);

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('전체', style: mainTitle(size: 32)),
                      const SizedBox(height: 4),
                      Text(
                        '우리의 공간과 기능을 한 곳에서 관리해요',
                        style: mainBody(size: 13, color: kMainSub),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '고객센터',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('고객센터 준비 중이에요.')),
                  ),
                  icon: const Icon(Icons.headset_mic_outlined, color: kMainSky),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MoreProfileEntry(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const MySpaceScreen()),
              ),
            ),
            const SizedBox(height: 28),
            _MoreSection(
              title: '우리의 공간',
              children: [
                _MoreRow(
                  icon: Icons.auto_stories_outlined,
                  iconColor: kMainRose,
                  iconBackground: kMainRoseSoft,
                  title: 'MomentLoop',
                  subtitle: '우리의 순간을 기록하고 돌아봐요',
                  onTap: () => _goToTab(1),
                ),
                _MoreRow(
                  icon: Icons.map_outlined,
                  iconColor: kMainSage,
                  iconBackground: kMainSageSoft,
                  title: '비밀 지도',
                  subtitle: '함께 다녀온 장소와 가고 싶은 곳',
                  onTap: () => _goToTab(2),
                ),
                _MoreRow(
                  icon: Icons.sports_esports_outlined,
                  iconColor: kMainSky,
                  iconBackground: kMainSkySoft,
                  title: '함께 놀기',
                  subtitle: '둘이서 즐기는 게임',
                  onTap: () => _goToTab(3),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _MoreSection(
              title: '기록과 이해',
              children: [
                _MoreRow(
                  icon: Icons.cottage_outlined,
                  iconColor: kMainLilac,
                  iconBackground: kMainLilacSoft,
                  title: '우리의 비밀기지',
                  subtitle: '우리의 기록과 기념일을 돌아봐요',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SecretBaseScreen(
                        baseUrl: auth.baseUrl,
                        authHeaders: {
                          if (auth.token != null)
                            'Authorization': 'Bearer ${auth.token}',
                        },
                      ),
                    ),
                  ),
                ),
                _MoreRow(
                  icon: Icons.psychology_outlined,
                  iconColor: kMainHoney,
                  iconBackground: kMainHoneySoft,
                  title: '관계 이해',
                  subtitle: '우리의 대화와 관계를 살펴봐요',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const RelationshipUnderstandingScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MySpaceScreen extends StatefulWidget {
  const MySpaceScreen({super.key});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> {
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
  bool _deleteAccountDeleting = false;
  final _deletePasswordCtrl = TextEditingController();
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
    _deletePasswordCtrl.dispose();
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

  Future<void> _confirmDeleteAccount() async {
    // 1단계: 탈퇴 결과 안내
    final continueDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('회원 탈퇴', style: mainTitle(size: 24)),
        content: Text(
          '탈퇴하면 내가 작성한 MomentLoop와 미디어가 영구 삭제되고, '
          '연결된 커플 공간이 닫혀요. 이 작업은 되돌릴 수 없어요.',
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
    if (continueDelete != true || !mounted) return;

    // 2단계: 비밀번호 입력 확인 (이메일 사용자)
    final authProvider =
        '${_auth.user?['AuthProvider'] ?? _auth.user?['authProvider'] ?? 'password'}';
    final isPasswordUser = authProvider == 'password' || authProvider == 'null';

    _deletePasswordCtrl.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('정말 탈퇴할까요?', style: mainTitle(size: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '탈퇴 후에는 로그인이 불가능하며, 내 기록이 모두 삭제돼요.',
              style: mainBody(size: 13, color: kMainSub, height: 1.5),
            ),
            if (isPasswordUser) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _deletePasswordCtrl,
                obscureText: true,
                style: mainBody(size: 14, color: kMainInk),
                decoration: InputDecoration(
                  hintText: '현재 비밀번호 입력',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: kMainMuted,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: kMainPaperSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('돌아가기', style: mainBody(size: 14, color: kMainMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '탈퇴',
              style: mainBody(size: 14, color: kError, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _doDeleteAccount(
      password: isPasswordUser ? _deletePasswordCtrl.text.trim() : null,
    );
  }

  Future<void> _doDeleteAccount({String? password}) async {
    if (_deleteAccountDeleting) return;
    setState(() => _deleteAccountDeleting = true);
    final error = await _auth.deleteAccount(password: password);
    if (!mounted) return;
    setState(() => _deleteAccountDeleting = false);
    if (error != null) {
      String msg;
      if (error == 'invalid_password') {
        msg = '비밀번호가 맞지 않아요.';
      } else if (error == 'password_required') {
        msg = '비밀번호를 입력해주세요.';
      } else {
        msg = '탈퇴에 실패했어요. ($error)';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: mainBody(color: Colors.white)),
        ),
      );
    }
    // 성공 시 _auth.deleteAccount 내부에서 logout() 호출 → 앱이 로그인 화면으로 전환됨
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
          content: Text(
            '애인 연결을 해제했어요. 개인 검사는 유지되고 궁합 결과는 숨겨져요.',
            style: mainBody(color: Colors.white),
          ),
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
            const SizedBox(height: 14),
            _profileSummary(sock),
            const SizedBox(height: 14),
            _accountCard(),
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
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _deleteAccountDeleting
                    ? null
                    : _confirmDeleteAccount,
                child: Text(
                  _deleteAccountDeleting ? '탈퇴 처리 중...' : '회원 탈퇴',
                  style: mainBody(
                    size: 13,
                    color: kMainMuted,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _developerCard(),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    '스테디투비비드 | 2026년 7월 설립',
                    style: mainBody(size: 11, color: kMainMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('mailto:admin@steady2vivid.kro.kr'),
                    ),
                    child: Text(
                      '고객센터: admin@steady2vivid.kro.kr',
                      style: mainBody(
                        size: 11,
                        color: kMainMuted,
                      ).copyWith(decoration: TextDecoration.underline),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 STEADY TO VIVID STUDIO. All Rights Reserved.',
                    style: mainBody(size: 10, color: kMainMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _developerCard() => _Card(
    title: '개발자 정보',
    child: Column(
      children: [
        _InfoRow(
          Icons.person_outline_rounded,
          kMainSky,
          '개발자',
          'Lee JunHwan',
          null,
        ),
        const SizedBox(height: 10),
        _InfoRow(
          Icons.business_outlined,
          kMainSage,
          '팀',
          'STEADY TO VIVID STUDIO',
          null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://steady2vivid.kro.kr/'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('팀 홈페이지 방문'),
            style: _compactButtonStyle(),
          ),
        ),
      ],
    ),
  );

  Widget _accountCard() => _Card(
    title: '계정 및 연결',
    child: Row(
      children: [
        Expanded(
          child: _spaceActionButton(
            icon: Icons.favorite_outline_rounded,
            color: kMainRose,
            backgroundColor: kMainRoseSoft,
            title: '연결된 애인',
            subtitle:
                _auth.user?['PartnerName']?.toString() ??
                _auth.user?['PartnerCode']?.toString() ??
                '아직 연결 전',
            onTap: _showPartnerSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _spaceActionButton(
            icon: _anniversaryDate == null
                ? Icons.add_rounded
                : Icons.edit_calendar_outlined,
            color: kMainHoney,
            backgroundColor: kMainHoneySoft,
            title: _anniversaryDate == null ? '기념일 추가' : '기념일 수정',
            subtitle: _anniversaryDate == null
                ? '우리의 시작일'
                : _dateOnly(_anniversaryDate!),
            onTap: _showAnniversarySheet,
          ),
        ),
      ],
    ),
  );

  Widget _spaceActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => MainCard(
    padding: EdgeInsets.zero,
    radius: 16,
    child: Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoodleBadge(
                color: color,
                backgroundColor: Colors.white,
                size: 38,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 11),
              Text(title, style: mainBody(size: 14, weight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mainBody(size: 11, color: kMainSub),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _showPartnerSheet() {
    final partner =
        _auth.user?['PartnerName']?.toString() ??
        _auth.user?['PartnerCode']?.toString();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MainCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('연결된 애인', style: mainTitle(size: 22)),
                const SizedBox(height: 8),
                Text(
                  partner == null ? '아직 연결된 애인이 없어요.' : '$partner와 연결되어 있어요.',
                  style: mainBody(size: 14, color: kMainSub),
                ),
                if (partner != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _partnerDisconnecting
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _confirmDisconnectPartner();
                            },
                      icon: const Icon(Icons.heart_broken_outlined, size: 17),
                      label: Text(
                        _partnerDisconnecting ? '해제 중...' : '애인 연결 해제',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kError,
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
          ),
        ),
      ),
    );
  }

  Widget _header() => MainCard(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
    color: Colors.transparent,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내 공간', style: mainTitle(size: 30)),
              Text('우리의 계정과 연결을 관리해요', style: mainBody(size: 13)),
            ],
          ),
        ),
        IconButton(
          tooltip: '뒤로가기',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: kMainInk),
        ),
      ],
    ),
  );

  Widget _profileSummary(SocketService sock) {
    final partner =
        _auth.user?['PartnerName']?.toString() ??
        _auth.user?['PartnerCode']?.toString() ??
        '아직 연결 전';
    final dDay = _coupleInfo?['dDay'];
    return MainCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          DoodleBadge(
            color: kMainInk,
            backgroundColor: kMainPaperSoft,
            size: 66,
            child: Text(
              sock.profileEmoji,
              style: const TextStyle(fontSize: 31),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName, style: mainTitle(size: 23)),
                const SizedBox(height: 3),
                Text(
                  partner == '아직 연결 전' ? partner : '$partner와 함께',
                  style: mainBody(size: 13, color: kMainSub),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _SummaryChip(
                      icon: Icons.qr_code_rounded,
                      label: '${_auth.user?['UserCode'] ?? '-'}',
                    ),
                    if (dDay != null)
                      _SummaryChip(
                        icon: Icons.favorite_border_rounded,
                        label: 'D+$dDay',
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '프로필 수정',
            onPressed: _showProfileSheet,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

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
    return AuthField(
      label: hint,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: authText(),
        decoration: InputDecoration(
          hintText: '$hint을 입력해주세요',
          suffixIcon: Icon(icon, color: authSecondary, size: 20),
        ),
      ),
    );
  }

  ButtonStyle _compactButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: authPrimary,
      backgroundColor: authSurface,
      side: const BorderSide(color: authLine),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Future<void> _loadCoupleInfo() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/couple/info'),
        headers: {
          if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
        },
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
      title: '프로필을\n다듬어볼까요?',
      description: '우리의 공간에서 보여질 정보를 정리해요.',
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).maybePop();
              if (!mounted) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const RelationshipUnderstandingScreen(
                    editBirthProfileOnly: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('운세용 출생 정보 수정'),
            style: _compactButtonStyle(),
          ),
          const SizedBox(height: 14),
          Text(
            '소셜 로그인 연동 정보',
            style: mainBody(size: 12, color: kMainSub, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _profileLoginInfo(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).maybePop();
                if (!mounted) return;
                await _showPasswordSheet();
              },
              icon: const Icon(Icons.password_outlined, size: 16),
              label: const Text('비밀번호 변경'),
            ),
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

  Widget _profileLoginInfo() {
    final provider =
        '${_auth.user?['AuthProvider'] ?? _auth.user?['authProvider'] ?? 'password'}';
    final hasGoogle =
        _auth.user?['GoogleLinked'] == true ||
        (_auth.user?['GooglePictureUrl'] != null) ||
        provider == 'google';
    return Column(
      children: [
        _InfoRow(
          Icons.login_outlined,
          hasGoogle ? kSuccess : kMainMuted,
          'Google',
          hasGoogle ? '연동됨' : '미연동',
          hasGoogle ? kSuccess : kMainMuted,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          Icons.account_circle_outlined,
          kMainSky,
          '로그인 방식',
          provider,
          null,
        ),
      ],
    );
  }

  Future<void> _showPasswordSheet() async {
    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _passwordMessage = null;
    await _showEditSheet(
      title: '비밀번호 변경',
      description: '안전한 비밀번호로 계정을 지켜주세요.',
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
      description: '두 분의 시작일을 저장해두면\n우리의 기록에 함께 표시돼요.',
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
    String? description,
    required Widget Function(StateSetter setSheetState) builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => AuthTheme(
        child: StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.viewInsetsOf(context).bottom +
                    MediaQuery.paddingOf(context).bottom +
                    24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  if (description != null)
                    AuthHeading(title: title, description: description)
                  else
                    Text(
                      title,
                      style: authText(
                        size: 31,
                        weight: FontWeight.w800,
                        height: 1.28,
                      ).copyWith(letterSpacing: -1.1),
                    ),
                  const SizedBox(height: 28),
                  builder(setSheetState),
                ],
              ),
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
    return AuthField(
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: '$label을 선택해주세요',
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          ),
          child: Text(
            value == null ? '' : _dateOnly(value),
            style: authText(color: value == null ? authMuted : authInk),
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
        style: authText(
          size: 13,
          color: value == '저장되었습니다.' || value == '변경되었습니다.'
              ? kSuccess
              : authError,
        ),
      ),
    );
  }

  Widget _primarySheetButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return AuthButton(label: label, loading: loading, onPressed: onPressed);
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
    if (_auth.token == null) {
      setState(() => _anniversaryMessage = '로그인이 필요해요.');
      return false;
    }
    if (_anniversaryDate == null) {
      setState(() => _anniversaryMessage = '기념일을 선택해주세요.');
      return false;
    }
    try {
      final res = await http.patch(
        Uri.parse('${_auth.baseUrl}/api/couple/info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_auth.token}',
        },
        body: jsonEncode({'start_date': _dateOnly(_anniversaryDate!)}),
      );
      if (res.statusCode != 200) {
        debugPrint(
          '[Settings] anniversary save failed: '
          '${res.statusCode} ${res.body}',
        );
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = data['ok'] == true;
      if (ok) await _loadCoupleInfo();
      return ok;
    } catch (error) {
      debugPrint('[Settings] anniversary save error: $error');
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

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: kMainSub),
            const SizedBox(width: 4),
            Text(
              label,
              style: mainBody(
                size: 11,
                color: kMainSub,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreProfileEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreProfileEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              DoodleBadge(
                color: kMainLilac,
                backgroundColor: kMainLilacSoft,
                size: 54,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: kMainLilac,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 공간',
                      style: mainBody(size: 17, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '프로필, 연결, 기념일을 관리해요',
                      style: mainBody(size: 12, color: kMainSub),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kMainMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MoreSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: mainBody(size: 14, color: kMainSub, weight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        MainCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            DoodleBadge(
              color: iconColor,
              backgroundColor: iconBackground,
              size: 40,
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: mainBody(size: 15, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: mainBody(size: 11, color: kMainMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kMainMuted),
          ],
        ),
      ),
    );
  }
}
