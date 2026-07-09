import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'core/main_design.dart';
import 'core/socket_service.dart';
import 'core/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/partner_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AuthService
  final auth = AuthService();
  await auth.init();

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
  runApp(const SecretBaseApp());
}

class SecretBaseApp extends StatefulWidget {
  const SecretBaseApp({super.key});

  @override
  State<SecretBaseApp> createState() => _SecretBaseAppState();
}

class _SecretBaseAppState extends State<SecretBaseApp> {
  final _socket = SocketService();
  final _auth = AuthService();
  bool _autoConnecting = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _auth.addListener(_onAuthChanged);

    // Initial check for auto-connect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAuthChanged();
    });
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _rebuild();
    // If logged in and paired, but not connected to socket, try auto-connect
    if (_auth.token != null &&
        _auth.user?['PartnerCode'] != null &&
        !_socket.isConnected &&
        !_autoConnecting) {
      _autoConnect();
    }
  }

  void _autoConnect() async {
    setState(() => _autoConnecting = true);

    final roomCode = _auth.user?['RoomCode'];
    final roomSecret = _auth.user?['RoomSecret'];
    final userId = _auth.user?['UserCode'];

    if (roomCode != null && roomSecret != null && userId != null) {
      _socket.connect(_auth.baseUrl, roomCode, roomSecret, userId);
    }

    // The socket service will update isConnected, which triggers rebuild
    setState(() => _autoConnecting = false);
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비밀기지',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
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
      return const LoginScreen(key: ValueKey('login'));
    }

    // 2. Check Partner Pairing
    if (_auth.user?['PartnerCode'] == null) {
      return const PartnerScreen(key: ValueKey('partner'));
    }

    // 3. Check Socket Connection
    if (_socket.isConnected) {
      return const HomeShell(key: ValueKey('home'));
    }

    // 4. Paired but not connected -> Stay in Loading/Connecting State
    // Never show EntryScreen for paired users
    return Scaffold(
      backgroundColor: kMainBg,
      body: CozyPage(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CozyMascot(size: 120),
              const SizedBox(height: 24),
              Text('비밀기지로 입장하는 중...', style: mainTitle(size: 24)),
              const SizedBox(height: 12),
              Text(
                'v1.0.4 - ${_socket.status}',
                style: mainBody(size: 14, color: kMainSub),
              ),
              if (_socket.status == '연결 실패' || _socket.status == '연결 끊김') ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: FilledButton(
                    onPressed: _autoConnect,
                    style: FilledButton.styleFrom(backgroundColor: kMainInk),
                    child: Text(
                      '다시 시도하기',
                      style: mainBody(
                        color: Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _auth.logout(),
                  child: Text(
                    '로그아웃',
                    style: mainBody(size: 13, color: kMainMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
    return Scaffold(
      backgroundColor: kMainBg,
      body: CozyPage(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CozyMascot(size: 116),
              const SizedBox(height: 24),
              Text('비밀기지로 입장하는 중...', style: mainTitle(size: 24)),
              const SizedBox(height: 10),
              Text(
                error ?? '심사용 계정으로 자동 로그인하고 있어요',
                style: mainBody(size: 14, color: kMainSub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (loading)
                const CircularProgressIndicator(color: kMainRose)
              else if (error != null)
                SizedBox(
                  width: 180,
                  height: 46,
                  child: FilledButton(
                    onPressed: () => onRetry(),
                    style: FilledButton.styleFrom(backgroundColor: kMainInk),
                    child: Text(
                      '다시 입장',
                      style: mainBody(
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
