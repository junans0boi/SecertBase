import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'invite_link.dart';

/// 링크로 받은 초대 코드를 가입·로그인 이후까지 보존한다.
class PendingInvite extends ChangeNotifier {
  PendingInvite();
  static final PendingInvite instance = PendingInvite();
  static const _key = 'pending_invite_code';

  String? _code;
  StreamSubscription<Uri>? _sub;
  String? get code => _code;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      _code = stored == null ? null : parseInviteCode(inviteWebLink(stored));
    } catch (_) {
      _code = null;
    }
    notifyListeners();
  }

  /// 앱 링크 수신을 시작한다. 테스트에서는 [initial]/[stream]을 주입한다.
  Future<void> start({Uri? initial, Stream<Uri>? stream}) async {
    await load();
    Uri? first = initial;
    if (initial == null && stream == null) {
      try {
        first = await AppLinks().getInitialLink();
      } catch (_) {}
    }
    if (first != null) await handleUri(first);
    final source = stream ?? _defaultStream();
    await _sub?.cancel();
    _sub = source?.listen((uri) => unawaited(handleUri(uri)));
  }

  Stream<Uri>? _defaultStream() {
    try {
      return AppLinks().uriLinkStream;
    } catch (_) {
      return null;
    }
  }

  Future<void> handleUri(Uri uri) async {
    final parsed = parseInviteCode(uri);
    if (parsed == null) return;
    _code = parsed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, parsed);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clear() async {
    _code = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
