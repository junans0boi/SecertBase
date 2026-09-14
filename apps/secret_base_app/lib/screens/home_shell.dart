import 'package:flutter/material.dart';

import '../core/main_design.dart';
import 'arcade/arcade_screen.dart';
import 'archive/map_screen.dart';
import 'archive/moment_loop_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    HomeScreen(onNavigate: _handleHomeNavigation),
    const MomentLoopScreen(),
    const MapScreen(),
    const ArcadeScreen(),
    SettingsScreen(onNavigate: _handleHomeNavigation),
  ];

  void _handleHomeNavigation(int target) {
    switch (target) {
      case 1:
        setState(() => _index = 1);
      case 2:
        setState(() => _index = 2);
      case 3:
        setState(() => _index = 3);
      case 4:
        setState(() => _index = 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      body: SafeArea(bottom: false, child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'MomentLoop',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports_rounded),
            label: '놀이',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '더보기',
          ),
        ],
      ),
    );
  }
}
