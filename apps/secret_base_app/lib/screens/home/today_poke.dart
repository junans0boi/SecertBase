import 'package:shared_preferences/shared_preferences.dart';

import '../../core/socket_service.dart';
import 'home_format.dart';

enum PokeOutcome { sent, alreadyToday, unavailable }

/// 콕 찌르기: a once-a-day nudge to the partner.
///
/// There is no dedicated server API yet, so this rides the existing realtime
/// `heart:send` event (delivered only while the partner is connected) and
/// keeps the once-a-day limit on this device. A server poke API with push and
/// a server-side daily limit is a follow-up.
class TodayPoke {
  TodayPoke({Future<bool> Function()? send}) : _send = send ?? _socketSend;

  static const prefsKey = 'home_poke_day';
  final Future<bool> Function() _send;

  static Future<bool> _socketSend() async {
    final socket = SocketService();
    if (!socket.isConnected) return false;
    socket.sendHeart();
    return true;
  }

  Future<bool> sentToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefsKey) == isoDay(today());
    } catch (_) {
      return false;
    }
  }

  Future<PokeOutcome> send() async {
    if (await sentToday()) return PokeOutcome.alreadyToday;
    final ok = await _send();
    if (!ok) return PokeOutcome.unavailable;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, isoDay(today()));
    } catch (_) {
      // The nudge went out; losing the local limit is harmless.
    }
    return PokeOutcome.sent;
  }
}
