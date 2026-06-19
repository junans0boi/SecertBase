import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';

class GameScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double maxContentWidth;
  final bool fullBleed;

  const GameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.maxContentWidth = 540,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.notoSans(
            color: kText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorder),
        ),
      ),
      body: SafeArea(
        child: fullBleed
            ? child
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: child,
                ),
              ),
      ),
    );
  }
}

class ConnectionRequired extends StatelessWidget {
  const ConnectionRequired({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: kTextMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            '연결이 필요합니다',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '설정 탭에서 서버에 연결해주세요',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class NeedTwoPlayers extends StatelessWidget {
  const NeedTwoPlayers({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👫', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            '2명이 필요한 게임이에요',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '상대방이 접속할 때까지 기다려주세요',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
