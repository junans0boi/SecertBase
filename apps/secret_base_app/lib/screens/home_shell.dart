import 'package:flutter/material.dart';
import '../core/main_design.dart';
import '../core/socket_service.dart';
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
  final _socket = SocketService();

  final _pages = const [ArcadeScreen(), ArchiveScreen(), SettingsScreen()];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      body: SafeArea(bottom: false, child: _pages[_index]),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kMainBg,
        border: const Border(top: BorderSide(color: kMainLine, width: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A7F70).withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: kMainPaper,
          indicatorColor: kMainSageSoft,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? kMainInk : kMainMuted,
              size: 23,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return mainBody(
              size: 11,
              color: selected ? kMainInk : kMainMuted,
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
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: '놀이',
            ),
            NavigationDestination(
              icon: Icon(Icons.collections_bookmark_outlined),
              selectedIcon: Icon(Icons.collections_bookmark),
              label: '기록',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
