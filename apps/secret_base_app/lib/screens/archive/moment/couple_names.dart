import '../../../core/auth_service.dart';
import '../../../core/http/api_client.dart';

/// Display names for the two people in the couple. The partner's nickname is
/// fetched once per app session from `/api/couple/info`; user codes are never
/// shown in the UI.
class CoupleNames {
  final String me;
  final String? partner;

  const CoupleNames({required this.me, this.partner});

  /// Last-resort label when the nickname is not known yet.
  String get partnerOrDefault => partner ?? '상대';

  static String? _cachedPartner;
  static String? _cachedForUser;

  static String myNickname([AuthService? auth]) {
    final u = (auth ?? AuthService()).user;
    final name =
        '${u?['Nickname'] ?? u?['nickname'] ?? u?['UserName'] ?? u?['userName'] ?? ''}'
            .trim();
    return name.isEmpty ? '나' : name;
  }

  static String? get cachedPartner => _cachedPartner;

  /// Best-effort lookup; returns null when unpaired or offline.
  static Future<String?> loadPartner(ApiClient api, {String? userKey}) async {
    if (_cachedPartner != null && _cachedForUser == userKey) {
      return _cachedPartner;
    }
    try {
      final body = await api.getJson('/api/couple/info');
      if (body is Map && body['ok'] == true) {
        final name = '${body['partnerName'] ?? ''}'.trim();
        if (name.isNotEmpty) {
          _cachedPartner = name;
          _cachedForUser = userKey;
          return name;
        }
      }
    } catch (_) {
      // Names are decoration; screens fall back to posts' nicknames.
    }
    return null;
  }

  static void resetCache() {
    _cachedPartner = null;
    _cachedForUser = null;
  }
}
