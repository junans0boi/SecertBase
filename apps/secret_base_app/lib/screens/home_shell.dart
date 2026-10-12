import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/main_design.dart';
import '../core/server_config.dart';
import 'arcade/arcade_screen.dart';
import 'archive/map_screen.dart';
import 'archive/moment_loop_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';

// 새 네이티브 의존성 없이 서버에 가벼운 요청을 보내 연결 여부를 판단한다.
// ponytail: 서버 도달성 기준(인터넷은 되나 서버만 죽어도 오프라인으로 표시). 필요 시 connectivity_plus로 교체.
Future<bool> _probeServer() async {
  try {
    await http
        .head(Uri.parse(serverBaseUrl))
        .timeout(const Duration(seconds: 4));
    return true;
  } catch (_) {
    return false;
  }
}

class HomeShell extends StatefulWidget {
  final Future<bool> Function() connectivityProbe;
  final Duration probeInterval;

  const HomeShell({
    super.key,
    this.connectivityProbe = _probeServer,
    this.probeInterval = const Duration(seconds: 15),
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _offline = false;
  Timer? _probeTimer;

  @override
  void initState() {
    super.initState();
    _probe();
    _probeTimer = Timer.periodic(widget.probeInterval, (_) => _probe());
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    super.dispose();
  }

  Future<void> _probe() async {
    final online = await widget.connectivityProbe();
    if (mounted && _offline == online) setState(() => _offline = !online);
  }

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
      body: Column(
        children: [
          if (_offline)
            Material(
              color: kMainRose,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Text(
                      '인터넷 연결이 끊겼어요',
                      style: mainBody(
                        size: 12,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(top: false, bottom: false, child: _pages[_index]),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: kMainPaper,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: kMainRose.withAlpha(60),
          indicatorColor: kMainRoseSoft,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? kMainRose
                  : kMainMuted,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => mainBody(
              size: 11,
              color: states.contains(WidgetState.selected)
                  ? kMainRose
                  : kMainMuted,
              weight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
        child: _navigationBar(),
      ),
    );
  }

  NavigationBar _navigationBar() {
    return NavigationBar(
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    );
  }
}
