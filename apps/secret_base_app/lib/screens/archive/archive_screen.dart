import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/socket_service.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _socket = SocketService();

  static const _items = [
    _ArchiveItem('📸', '셋로그', 'OOTD & 데이트 사진', [Color(0xFFFF6B9D), Color(0xFFD94F7E)]),
    _ArchiveItem('🗺️', '비밀 지도', '우리가 간 곳 모음', [Color(0xFF06D6A0), Color(0xFF049E77)]),
    _ArchiveItem('❓', '10시의 질문', '매일 밤 10시 Q&A', [Color(0xFFFFD166), Color(0xFFE0A800)]),
    _ArchiveItem('🏆', '목표 챌린지', '함께하는 도전', [Color(0xFF5DADE2), Color(0xFF2E86C1)]),
    _ArchiveItem('🎵', '주크박스', '우리의 플레이리스트', [Color(0xFF7C5CFC), Color(0xFF5B3FD4)]),
  ];

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

  void _openItem(_ArchiveItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ArchiveDetailPage(item: item, serverUrl: _socket.serverUrl ?? 'http://localhost:4100')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📦 아카이브',
                    style: GoogleFonts.notoSans(fontSize: 26, fontWeight: FontWeight.w800, color: kText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '우리의 모든 순간을 기록해요',
                    style: GoogleFonts.notoSans(fontSize: 14, color: kTextMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => _ArchiveCard(
                  item: _items[i],
                  onTap: () => _openItem(_items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveItem {
  final String emoji;
  final String name;
  final String desc;
  final List<Color> gradient;
  const _ArchiveItem(this.emoji, this.name, this.desc, this.gradient);
}

class _ArchiveCard extends StatelessWidget {
  final _ArchiveItem item;
  final VoidCallback onTap;
  const _ArchiveCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: item.gradient.map((c) => c.withOpacity(0.25)).toList(),
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.gradient.first.withOpacity(0.3)),
              ),
              child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: GoogleFonts.notoSans(color: kText, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(item.desc, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: kTextMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Detail page ───────────────────────────────────────────────────

class _ArchiveDetailPage extends StatelessWidget {
  final _ArchiveItem item;
  final String serverUrl;
  const _ArchiveDetailPage({required this.item, required this.serverUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${item.emoji} ${item.name}',
          style: GoogleFonts.notoSans(color: kText, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorder),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradient.map((c) => c.withOpacity(0.12)).toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: item.gradient.first.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text(item.name, style: GoogleFonts.notoSans(color: kText, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(item.desc, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.construction, color: kGold, size: 36),
                const SizedBox(height: 12),
                Text(
                  '개발 중',
                  style: GoogleFonts.notoSans(color: kGold, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phase 4 폴리싱 단계에서 완성됩니다.\n백엔드 API는 이미 준비되어 있어요!',
                  style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kSuccess.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kSuccess.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: kSuccess, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'API 엔드포인트 준비 완료',
                        style: GoogleFonts.notoSans(color: kSuccess, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ApiEndpointCard(item: item),
        ],
      ),
    );
  }
}

class _ApiEndpointCard extends StatelessWidget {
  final _ArchiveItem item;
  const _ApiEndpointCard({required this.item});

  String get _endpoint {
    switch (item.name) {
      case '셋로그': return '/api/setlog';
      case '비밀 지도': return '/api/map';
      case '10시의 질문': return '/api/qa/today';
      case '목표 챌린지': return '/api/challenges';
      case '주크박스': return '/api/jukebox';
      default: return '/api/...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REST API', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _endpoint,
            style: GoogleFonts.notoSans(color: kPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
