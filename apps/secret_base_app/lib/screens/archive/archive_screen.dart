import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  static const _items = [
    _ArchiveItem('📸', '셋로그', 'OOTD & 데이트 사진', Color(0xFFD63384), Color(0xFFFFE4F0)),
    _ArchiveItem('🗺️', '비밀 지도', '우리가 간 곳 모음', Color(0xFF00897B), Color(0xFFE0F2F1)),
    _ArchiveItem('❓', '10시의 질문', '매일 밤 10시 Q&A', Color(0xFFFF8F00), Color(0xFFFFF8E1)),
    _ArchiveItem('🏆', '목표 챌린지', '함께하는 도전', Color(0xFF1976D2), Color(0xFFE3F2FD)),
    _ArchiveItem('🎵', '주크박스', '우리의 플레이리스트', Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _ArchiveCard(
                item: _items[i],
                onTap: () => _openDetail(ctx, _items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE4F0), Color(0xFFFFF5F8)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📦 우리의 기록',
            style: GoogleFonts.notoSans(fontSize: 22, fontWeight: FontWeight.w800, color: kText),
          ),
          const SizedBox(height: 2),
          Text(
            '모든 순간을 기억해요 💕',
            style: GoogleFonts.notoSans(fontSize: 13, color: kTextSub),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext ctx, _ArchiveItem item) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => _ArchiveDetailPage(item: item)));
  }
}

class _ArchiveItem {
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final Color bgColor;
  const _ArchiveItem(this.emoji, this.name, this.desc, this.color, this.bgColor);
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: item.color.withAlpha(20), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: item.bgColor, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: GoogleFonts.notoSans(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(item.desc, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: kBorder, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ArchiveDetailPage extends StatelessWidget {
  final _ArchiveItem item;
  const _ArchiveDetailPage({super.key, required this.item});

  String get _endpoint {
    switch (item.name) {
      case '셋로그': return 'GET/POST /api/setlog';
      case '비밀 지도': return 'GET/POST /api/map';
      case '10시의 질문': return 'GET /api/qa/today';
      case '목표 챌린지': return 'GET/POST /api/challenges';
      default: return 'GET/POST /api/jukebox';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${item.emoji} ${item.name}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: item.color.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 60)),
                    const SizedBox(height: 10),
                    Text(item.name, style: GoogleFonts.notoSans(color: kText, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item.desc, style: GoogleFonts.notoSans(color: kTextSub, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.construction_rounded, color: kGold, size: 36),
                    const SizedBox(height: 10),
                    Text('개발 중 🛠️', style: GoogleFonts.notoSans(color: kGold, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Phase 4에서 완성 예정\n백엔드 API는 이미 준비됐어요!', style: GoogleFonts.notoSans(color: kTextSub, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: kSuccess.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kSuccess.withAlpha(80)),
                      ),
                      child: Text(_endpoint, style: GoogleFonts.notoSans(color: kSuccess, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
