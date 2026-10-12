import 'package:flutter/material.dart';

import '../core/main_design.dart';
import '../core/push/push_service.dart';
import '../core/push/push_game_route.dart';
import '../core/push/push_today_route.dart';
import '../core/auth_service.dart';
import '../core/socket_service.dart';
import '../core/today_api.dart';
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

  @override
  void initState() {
    super.initState();
    pendingPushTarget.addListener(_schedulePush);
    _schedulePush();
  }

  @override
  void dispose() {
    pendingPushTarget.removeListener(_schedulePush);
    super.dispose();
  }

  void _schedulePush() {
    if (!mounted || pendingPushTarget.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePushTarget());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _consumePushTarget() {
    if (!mounted) return;
    final target = pendingPushTarget.value;
    if (target == null) return;
    final auth = AuthService();
    if (auth.token == null || auth.user?['PartnerCode'] == null) return;
    pendingPushTarget.value = null;
    Widget? page;
    switch (target.screen) {
      case 'moment_detail':
        if (target.postId != null && target.postId! > 0) {
          page = MomentLoopScreen(initialPostId: target.postId);
        }
      case 'moment_draft':
        if (target.draftId != null) {
          page = MomentLoopScreen(initialDraftId: target.draftId);
        }
      case 'today_loop':
        if (auth.token != null) {
          page = PushTodayRoute(
            api: TodayApi(baseUrl: auth.baseUrl, token: auth.token!),
          );
        }
      case 'game_invite':
        if (target.roomCode == null ||
            target.roomCode == SocketService().roomCode) {
          page = pushGameLobby(target.gameType);
        }
    }
    if (page == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림의 대상을 열 수 없어요.')));
      return;
    }
    final destination = page;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }

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
      body: SafeArea(top: false, bottom: false, child: _pages[_index]),
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
