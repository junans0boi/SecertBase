import 'package:flutter/material.dart';
import '../core/main_design.dart';
import '../core/socket_service.dart';
import '../widgets/heart_overlay.dart';
import 'home/home_screen.dart';
import 'arcade/arcade_screen.dart';
import 'archive/archive_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _showHeartOverlay = false;
  final _socket = SocketService();

  final _pages = const [HomeScreen(), ArcadeScreen(), ArchiveScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    if (_socket.heartReceived && !_showHeartOverlay) {
      _socket.clearHeart();
      if (mounted) setState(() => _showHeartOverlay = true);
    } else {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: kMainBg,
          body: SafeArea(bottom: false, child: _pages[_index]),
          bottomNavigationBar: _buildNav(),
        ),
        if (_showHeartOverlay)
          Positioned.fill(
            child: HeartOverlay(
              onComplete: () {
                if (mounted) setState(() => _showHeartOverlay = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNav() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kMainBg,
        border: const Border(top: BorderSide(color: kMainLine, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: kMainPaper,
          indicatorColor: kMainRoseSoft,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? kMainRose : kMainMuted,
              size: 23,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return mainBody(
              size: 11,
              color: selected ? kMainRose : kMainMuted,
              weight: selected ? FontWeight.w800 : FontWeight.w500,
              height: 1,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: kMainPaper,
          elevation: 0,
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports_rounded),
              label: '놀이',
            ),
            NavigationDestination(
              icon: Icon(Icons.collections_bookmark_outlined),
              selectedIcon: Icon(Icons.collections_bookmark_rounded),
              label: '기록',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
