import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'core/socket_service.dart';
import 'screens/entry_screen.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SecretBaseApp());
}

class SecretBaseApp extends StatefulWidget {
  const SecretBaseApp({super.key});

  @override
  State<SecretBaseApp> createState() => _SecretBaseAppState();
}

class _SecretBaseAppState extends State<SecretBaseApp> {
  final _socket = SocketService();

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

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비밀기지',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: _socket.isConnected
            ? const HomeShell(key: ValueKey('home'))
            : const EntryScreen(key: ValueKey('entry')),
      ),
    );
  }
}
