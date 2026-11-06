import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/app_info.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';

/// 로그인·연결이 끝난 사용자가 비밀기지로 들어가는 동안의 화면.
/// 입장 중 / 연결 실패 / 오프라인을 구분해 보여 주고, 실패해도 다시 시도와 로그아웃이 보인다.
class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({
    super.key,
    required this.failed,
    required this.onRetry,
    required this.onLogout,
    this.probe,
  });

  /// 소켓 연결이 실패했거나 끊겼는지.
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  /// 서버에 닿는지 확인한다(테스트에서 바꿀 수 있다). true면 서버에 닿는다.
  final Future<bool> Function()? probe;

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  bool _offline = false;
  Timer? _autoRetry;

  @override
  void initState() {
    super.initState();
    if (widget.failed) _onFailed();
  }

  @override
  void didUpdateWidget(ConnectingScreen old) {
    super.didUpdateWidget(old);
    if (widget.failed && !old.failed) _onFailed();
    if (!widget.failed) {
      _autoRetry?.cancel();
      _offline = false;
    }
  }

  @override
  void dispose() {
    _autoRetry?.cancel();
    super.dispose();
  }

  Future<bool> _reachable() async {
    if (widget.probe != null) return widget.probe!();
    try {
      await http
          .get(Uri.parse(AuthService().baseUrl))
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onFailed() async {
    final ok = await _reachable();
    if (!mounted || !widget.failed) return;
    setState(() => _offline = !ok);
    _autoRetry?.cancel();
    if (!ok) {
      // 연결이 돌아오면 알아서 다시 시도한다.
      _autoRetry = Timer.periodic(const Duration(seconds: 8), (_) async {
        if (await _reachable() && mounted) widget.onRetry();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.failed) {
      final version = AppInfo.current?.displayVersion ?? '';
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
              Text('잠시만 기다려 주세요', style: V2Text.cap),
              const SizedBox(height: V2Space.x6),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              if (version.isNotEmpty) ...[
                const SizedBox(height: V2Space.x8),
                Text(version, style: V2Text.cap),
              ],
            ],
          ),
        ),
      );
    }
    return AuthFrame(
      body: Padding(
        padding: const EdgeInsets.only(top: V2Space.x12),
        child: _offline
            ? V2ErrorState.offline(
                title: '인터넷에 연결되어 있지 않아요',
                body: 'Wi-Fi나 모바일 데이터를 확인해 주세요. 연결되면 자동으로 다시 시도해요.',
                onRetry: widget.onRetry,
              )
            : V2ErrorState(
                title: '연결하지 못했어요',
                body: '서버와의 연결이 불안정해요. 잠시 후 다시 시도해 주세요.',
                onRetry: widget.onRetry,
              ),
      ),
      footer: V2Button(
        label: '로그아웃',
        variant: V2ButtonVariant.text,
        onPressed: widget.onLogout,
      ),
    );
  }
}
