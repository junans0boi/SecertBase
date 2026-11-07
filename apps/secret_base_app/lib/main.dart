import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'core/app_info.dart';
import 'core/push/push_service.dart';
import 'core/push/local_notification_service.dart';
import 'features/moment_loop/application/upload_outbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'core/socket_service.dart';
import 'core/auth_service.dart';
import 'core/yut_audio.dart';
import 'screens/auth/auth_parts.dart';
import 'screens/auth/connecting_screen.dart';
import 'screens/auth/google_signup_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pairing_celebrate_screen.dart';
import 'screens/auth/partner_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'v2/v2.dart';
import 'screens/home_shell.dart';
import 'v2/gallery/v2_gallery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();

  // Initialize AuthService
  final auth = AuthService();
  await auth.init();
  try {
    await AppInfo.load();
  } catch (_) {
    // 버전 표시만 비고 앱은 그대로 시작한다.
  }
  await V2ThemeController.instance.load();
  await YutAudio.instance.loadSettings();
  await LocalNotificationService.instance.start();
  UploadOutbox.instance.failureNotifier =
      LocalNotificationService.instance.showUploadFailure;
  // Guarded: without Firebase config push is silently disabled.
  auth.beforeLogout = PushService.instance.revoke;
  unawaited(PushService.instance.start());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFAF4EA),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final onboardingSeen = auth.token != null || await hasSeenOnboarding();
  runApp(SecretBaseApp(onboardingSeen: onboardingSeen));
}

class SecretBaseApp extends StatefulWidget {
  const SecretBaseApp({super.key, this.onboardingSeen = true});

  /// false면 로그인 전에 온보딩 3장을 먼저 보여 준다(첫 실행).
  final bool onboardingSeen;

  @override
  State<SecretBaseApp> createState() => _SecretBaseAppState();
}

class _SecretBaseAppState extends State<SecretBaseApp> {
  final _socket = SocketService();
  final _auth = AuthService();
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _autoConnecting = false;
  bool _reunionNoticeScheduled = false;
  String? _outboxIdentity;
  late bool _onboardingSeen = widget.onboardingSeen;
  bool? _wasPaired;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    V2ThemeController.instance.addListener(_onThemeChanged);
    _auth.addListener(_onAuthChanged);
    // 알림 권한은 연결 축하 화면의 안내 시트를 거쳐서만 묻는다.
    PushService.instance.deferPermissionPrompt = true;

    // Initial check for auto-connect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAuthChanged();
    });
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    V2ThemeController.instance.removeListener(_onThemeChanged);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final paired =
        _auth.token != null &&
        _auth.user?['PartnerCode']?.toString().isNotEmpty == true;
    if (_auth.token == null) {
      _wasPaired = null;
      _showCelebration = false;
    } else {
      // 이번 실행 중 연결 전 → 연결로 바뀐 순간에만 축하 화면을 보여 준다.
      if (_wasPaired == false && paired) _showCelebration = true;
      _wasPaired = paired;
      if (!_onboardingSeen) {
        _onboardingSeen = true;
        unawaited(markOnboardingSeen());
      }
    }
    _rebuild();
    if (_auth.user?['ReunionNoticePending'] == true &&
        !_reunionNoticeScheduled) {
      _reunionNoticeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReunionNotice();
      });
    }
    unawaited(
      PushService.instance.sync(
        api: _auth.apiClient,
        loggedIn: _auth.token != null,
        paired: _auth.user?['PartnerCode'] != null,
        identity: _auth.user?['UserId'] ?? _auth.user?['id'],
        authToken: _auth.token,
      ),
    );
    final userId = _auth.user?['UserId'] ?? _auth.user?['id'];
    final roomCode = _auth.user?['RoomCode'];
    final outboxIdentity =
        _auth.token == null || userId == null || roomCode == null
        ? null
        : '$userId:$roomCode';
    if (outboxIdentity != _outboxIdentity) {
      _outboxIdentity = outboxIdentity;
      if (outboxIdentity != null) {
        unawaited(UploadOutbox.instance.resume());
      }
    }
    // If logged in and paired, but not connected to socket, try auto-connect
    if (_auth.token != null &&
        _auth.user?['PartnerCode'] != null &&
        !_socket.isConnected &&
        !_autoConnecting) {
      _autoConnect();
    }
  }

  Future<void> _showReunionNotice() async {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || _auth.user?['ReunionNoticePending'] != true) {
      _reunionNoticeScheduled = false;
      return;
    }
    await showV2Dialog<void>(
      dialogContext,
      title: '다시 만난 두 분을 응원해요',
      message: '다시 이어진 두 분의 시간을 응원해요. 이전 기록도 다시 열렸어요.',
      barrierDismissible: false,
      actions: const [V2DialogAction(label: '우리의 시간 이어가기')],
    );
    await _auth.markReunionNoticeSeen();
    _reunionNoticeScheduled = false;
  }

  void _autoConnect() async {
    setState(() => _autoConnecting = true);

    final token = _auth.token;
    if (token != null) {
      _socket.connect(_auth.baseUrl, token);
    }

    // The socket service will update isConnected, which triggers rebuild
    setState(() => _autoConnecting = false);
  }

  void _rebuild() => setState(() {});

  /// A color theme switch: rebuild every element so widgets that read
  /// [V2Colors] / [V2Text] directly (not through `Theme.of`) pick up the new
  /// palette too. Navigation and screen state are kept.
  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '비밀기지',
      debugShowCheckedModeBanner: false,
      // 2.0 is the whole app's theme (games included). Game screens keep
      // their own explicit per-game styling on top of it.
      theme: buildV2Theme(palette: V2ThemeController.instance.palette),
      builder: (context, child) => V2AppFrame(child: child),
      // Dev-only 2.0 component gallery (/#/v2-gallery); absent in release.
      routes: kDebugMode
          ? {V2GalleryScreen.routeName: (_) => const V2GalleryScreen()}
          : const {},
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _buildCurrentScreen(),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    // 1. Check Login
    if (_auth.token == null) {
      if (_auth.isKakaoReviewAutoLoginEnabled) {
        return _ReviewAutoLoginScreen(
          loading: _auth.reviewAutoLoginLoading,
          error: _auth.reviewAutoLoginError,
          onRetry: _auth.loginForKakaoReview,
        );
      }
      if (!_onboardingSeen) {
        return OnboardingScreen(
          key: const ValueKey('onboarding'),
          onDone: () => setState(() => _onboardingSeen = true),
        );
      }
      return const LoginScreen(key: ValueKey('login'));
    }

    // 2. Google 첫 로그인: 닉네임·생일·동의를 마쳐야 들어올 수 있다.
    if (_auth.signupRequired) {
      return const GoogleSignupScreen(key: ValueKey('google-signup'));
    }

    // 3. Check Partner Pairing
    if (_auth.user?['PartnerCode'] == null) {
      return const PartnerScreen(key: ValueKey('partner'));
    }

    // 4. 연결 직후 축하
    if (_showCelebration) {
      return PairingCelebrateScreen(
        key: const ValueKey('celebrate'),
        onDone: () => setState(() => _showCelebration = false),
      );
    }

    // 5. Check Socket Connection
    if (_socket.isConnected) {
      return const HomeShell(key: ValueKey('home'));
    }

    // 6. Paired but not connected -> 입장 중 / 실패 / 오프라인
    final failed =
        _socket.status == '연결 실패' ||
        _socket.status == '연결 끊김' ||
        _socket.status.startsWith('입장 실패');
    return ConnectingScreen(
      key: const ValueKey('connecting'),
      failed: failed,
      onRetry: _autoConnect,
      onLogout: () => _auth.logout(),
    );
  }
}

class _ReviewAutoLoginScreen extends StatelessWidget {
  final bool loading;
  final String? error;
  final Future<bool> Function() onRetry;

  const _ReviewAutoLoginScreen({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      hero: true,
      body: Padding(
        padding: const EdgeInsets.only(top: V2Space.x12 * 2),
        child: Column(
          children: [
            const AuthEmblem(size: 96),
            const SizedBox(height: V2Space.x6),
            Text('비밀기지에 들어가는 중이에요', style: V2Text.title),
            const SizedBox(height: V2Space.x2),
            Text(
              error ?? '자동으로 입장하고 있어요',
              textAlign: TextAlign.center,
              style: V2Text.cap,
            ),
            const SizedBox(height: V2Space.x6),
            if (loading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else if (error != null)
              V2Button(
                label: '다시 입장',
                fullWidth: false,
                onPressed: () => onRetry(),
              ),
          ],
        ),
      ),
    );
  }
}
