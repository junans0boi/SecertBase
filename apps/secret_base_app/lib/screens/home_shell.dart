import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/push/push_service.dart';
import '../core/push/push_game_route.dart';
import '../core/push/push_today_route.dart';
import '../core/auth_service.dart';
import '../core/socket_service.dart';
import '../core/today_api.dart';
import '../core/server_config.dart';
import 'arcade/arcade_screen.dart';
import 'archive/map_screen.dart';
import 'archive/moment_loop_screen.dart';
import 'auth/partner_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';
import '../v2/v2.dart';

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
  final ValueNotifier<bool> _offlineNotifier = ValueNotifier(false);
  Timer? _probeTimer;

  @override
  void initState() {
    super.initState();
    _probe();
    _probeTimer = Timer.periodic(widget.probeInterval, (_) => _probe());
    pendingPushTarget.addListener(_schedulePush);
    _schedulePush();
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _offlineNotifier.dispose();
    pendingPushTarget.removeListener(_schedulePush);
    super.dispose();
  }

  Future<void> _probe() async {
    final online = await widget.connectivityProbe();
    if (mounted && _offline == online) {
      setState(() => _offline = !online);
      _offlineNotifier.value = _offline;
    }
  }

  // Tabs are built the first time they are opened and then kept alive
  // (IndexedStack), so scroll position, drafts and loaded data survive switches.
  final Set<int> _visited = {0};

  Widget _buildPage(int i) => switch (i) {
    0 => HomeScreen(
      onNavigate: _handleHomeNavigation,
      offline: _offlineNotifier,
    ),
    1 => MomentLoopScreen(
      onGoPairing: () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const PartnerScreen())),
    ),
    2 => const MapScreen(),
    3 => const ArcadeScreen(),
    _ => SettingsScreen(onNavigate: _handleHomeNavigation),
  };

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
      showV2Snack(context, '알림이 가리키는 화면을 열 수 없어요.', tone: V2Tone.err);
      return;
    }
    final destination = page;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }

  void _select(int index) {
    if (index < 0 || index > 4) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  void _handleHomeNavigation(int target) => _select(target);

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        body: Column(
          children: [
            if (_offline)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.x3,
                    V2Space.x2,
                    V2Space.x3,
                    0,
                  ),
                  child: const V2Banner.offline(),
                ),
              ),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < 5; i++)
                      _visited.contains(i)
                          ? TickerMode(
                              enabled: i == _index,
                              child: _buildPage(i),
                            )
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: V2BottomTabBar(
          currentIndex: _index,
          onTap: _select,
        ),
      ),
    );
  }
}
