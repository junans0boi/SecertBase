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

  void _ping() => _socket.ping();

  void _disconnect() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('연결 해제', style: GoogleFonts.notoSans(color: kText, fontWeight: FontWeight.w700)),
        content: Text('방에서 나가고 메인 화면으로 돌아갑니다.', style: GoogleFonts.notoSans(color: kTextMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: GoogleFonts.notoSans(color: kTextMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socket.disconnect();
            },
            child: Text('나가기', style: GoogleFonts.notoSans(color: kError, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚙️ 설정',
                  style: GoogleFonts.notoSans(fontSize: 26, fontWeight: FontWeight.w800, color: kText),
                ),
                const SizedBox(height: 24),
                _buildConnectionCard(sock),
                const SizedBox(height: 16),
                _buildPresenceCard(sock),
                const SizedBox(height: 16),
                _buildLogsCard(sock),
                const SizedBox(height: 24),
                _buildDangerZone(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(SocketService sock) {
    return _Card(
      title: '연결 상태',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.wifi,
            iconColor: sock.isConnected ? kSuccess : kError,
            label: '상태',
            value: sock.status,
            valueColor: sock.isConnected ? kSuccess : kError,
          ),
          const SizedBox(height: 12),
          if (sock.userId != null)
            _InfoRow(
              icon: Icons.person_outline,
              iconColor: kPrimary,
              label: '사용자',
              value: sock.userId!,
            ),
          const SizedBox(height: 12),
          if (sock.roomCode != null)
            _InfoRow(
              icon: Icons.meeting_room_outlined,
              iconColor: kPrimary,
              label: '방 코드',
              value: sock.roomCode!,
            ),
          const SizedBox(height: 12),
          if (sock.serverUrl != null)
            _InfoRow(
              icon: Icons.dns_outlined,
              iconColor: kPrimary,
              label: '서버',
              value: sock.serverUrl!,
            ),
          const SizedBox(height: 12),
          if (sock.lastPingMs != null)
            _InfoRow(
              icon: Icons.speed_outlined,
              iconColor: kTeal,
              label: 'Ping',
              value: '${sock.lastPingMs}ms',
              valueColor: _pingColor(sock.lastPingMs!),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'Ping 테스트',
                  icon: Icons.speed,
                  onTap: _ping,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceCard(SocketService sock) {
    return _Card(
      title: '접속자',
      child: sock.presenceUsers.isEmpty
          ? Row(
              children: [
                const Icon(Icons.person_off_outlined, color: kTextMuted, size: 18),
                const SizedBox(width: 8),
                Text('아직 아무도 없어요', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
              ],
            )
          : Column(
              children: sock.presenceUsers.map((user) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: kSuccess),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      user,
                      style: GoogleFonts.notoSans(
                        color: user == sock.userId ? kPrimary : kText,
                        fontSize: 15,
                        fontWeight: user == sock.userId ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    if (user == sock.userId) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('나', style: GoogleFonts.notoSans(color: kPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              )).toList(),
            ),
    );
  }

  Widget _buildLogsCard(SocketService sock) {
    return _Card(
      title: '이벤트 로그',
      action: Text('최근 ${sock.logs.length}건', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
      child: SizedBox(
        height: 180,
        child: sock.logs.isEmpty
            ? Center(child: Text('로그가 없습니다', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)))
            : ListView.builder(
                itemCount: sock.logs.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    sock.logs[i],
                    style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '연결 관리',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 40),
        Center(
          child: Text(
            '비밀기지 · Secret Base',
            style: GoogleFonts.notoSans(color: kBorder, fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Phase 3 · 2026',
            style: GoogleFonts.notoSans(color: kBorder, fontSize: 11),
          ),
        ),
      ],
    );
  }

  static Color _pingColor(int ms) {
    if (ms < 50) return kSuccess;
    if (ms < 150) return kGold;
    return kError;
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Card({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              if (action != null) ...[const Spacer(), action!],
            ],
          ),
          const SizedBox(height: 14),
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
  const _InfoRow({required this.icon, required this.iconColor, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.notoSans(
            color: valueColor ?? kText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
