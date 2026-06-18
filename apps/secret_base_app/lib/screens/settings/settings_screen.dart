import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
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

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _disconnect() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('방 나가기', style: mainTitle(size: 24)),
        content: Text('정말 방에서 나갈까요?', style: mainBody(size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: mainBody(size: 14, color: kMainMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socket.disconnect();
            },
            child: Text(
              '나가기',
              style: mainBody(size: 14, color: kError, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
                          u == sock.userId ? '$u (나)' : u,
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

  Widget _logCard(SocketService sock) => _Card(
    title: '이벤트 로그',
    child: SizedBox(
      height: 160,
      child: sock.logs.isEmpty
          ? Center(
              child: Text(
                '로그 없음',
                style: mainBody(size: 13, color: kMainMuted),
              ),
            )
          : ListView.builder(
              itemCount: sock.logs.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  sock.logs[i],
                  style: mainBody(size: 12, color: kMainSub, height: 1.3),
                ),
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
