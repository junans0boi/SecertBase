import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/socket_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _disconnect() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('방 나가기', style: GoogleFonts.notoSans(color: kText, fontWeight: FontWeight.w700)),
        content: Text('정말 방에서 나갈까요?', style: GoogleFonts.notoSans(color: kTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('취소', style: GoogleFonts.notoSans(color: kTextMuted))),
          TextButton(
            onPressed: () { Navigator.pop(context); _socket.disconnect(); },
            child: Text('나가기', style: GoogleFonts.notoSans(color: kError, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            _connectionCard(sock),
            const SizedBox(height: 12),
            _presenceCard(sock),
            const SizedBox(height: 12),
            _logCard(sock),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('방 나가기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kError,
                  side: const BorderSide(color: kError),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text('비밀기지 💕 Secret Base', style: GoogleFonts.notoSans(color: kBorder, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('⚙️ 설정', style: GoogleFonts.notoSans(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
        const SizedBox(height: 2),
        Text('연결 상태와 설정을 확인해요', style: GoogleFonts.notoSans(fontSize: 13, color: kTextSub)),
      ],
    ),
  );

  Widget _connectionCard(SocketService sock) => _Card(
    title: '연결 상태',
    child: Column(
      children: [
        _InfoRow(Icons.wifi, sock.isConnected ? kSuccess : kError, '상태', sock.status, sock.isConnected ? kSuccess : kError),
        const SizedBox(height: 10),
        if (sock.userId != null) _InfoRow(Icons.person_outline, kPrimary, '사용자', sock.userId!, null),
        if (sock.userId != null) const SizedBox(height: 10),
        if (sock.roomCode != null) _InfoRow(Icons.meeting_room_outlined, kPrimary, '방 코드', sock.roomCode!, null),
        if (sock.roomCode != null) const SizedBox(height: 10),
        if (sock.lastPingMs != null) _InfoRow(Icons.speed, kTeal, 'Ping', '${sock.lastPingMs}ms', _pingColor(sock.lastPingMs!)),
        if (sock.lastPingMs != null) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _socket.ping,
            icon: const Icon(Icons.speed, size: 16),
            label: const Text('Ping 테스트'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              side: const BorderSide(color: kBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _presenceCard(SocketService sock) => _Card(
    title: '접속자',
    child: sock.presenceUsers.isEmpty
      ? Row(children: [
          const Icon(Icons.person_off_outlined, color: kTextMuted, size: 18),
          const SizedBox(width: 8),
          Text('아직 혼자에요', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
        ])
      : Column(
          children: sock.presenceUsers.map((u) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: kSuccess)),
              const SizedBox(width: 10),
              Text(
                u == sock.userId ? '$u (나)' : u,
                style: GoogleFonts.notoSans(
                  color: u == sock.userId ? kPrimary : kText,
                  fontSize: 15,
                  fontWeight: u == sock.userId ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ]),
          )).toList(),
        ),
  );

  Widget _logCard(SocketService sock) => _Card(
    title: '이벤트 로그',
    child: SizedBox(
      height: 160,
      child: sock.logs.isEmpty
        ? Center(child: Text('로그 없음', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)))
        : ListView.builder(
            itemCount: sock.logs.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(sock.logs[i], style: GoogleFonts.notoSans(color: kTextSub, fontSize: 12)),
            ),
          ),
    ),
  );

  static Color _pingColor(int ms) {
    if (ms < 50) return kSuccess;
    if (ms < 150) return kGold;
    return kError;
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: kPrimary.withAlpha(12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
  const _InfoRow(this.icon, this.iconColor, this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: iconColor, size: 16),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
      const Spacer(),
      Text(value, style: GoogleFonts.notoSans(color: valueColor ?? kText, fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}
