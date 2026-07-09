import 'package:flutter/foundation.dart';

const configuredServerUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://localhost:4100',
);

String get serverBaseUrl {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    final host = Uri.base.host;
    // Local/LAN/Tailscale Flutter dev servers use SOCKET_URL.
    // Production web uses the same origin because the web server proxies /api and /socket.io.
    if ((origin.startsWith('http://') || origin.startsWith('https://')) &&
        !_isDevHost(host)) {
      return origin;
    }
  }

  return configuredServerUrl;
}

bool _isDevHost(String host) {
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return true;
  }
  if (host.startsWith('192.168.') || host.startsWith('10.')) {
    return true;
  }

  final parts = host.split('.');
  if (parts.length != 4) return false;

  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  if (first == null || second == null) return false;

  final isPrivate172 = first == 172 && second >= 16 && second <= 31;
  final isTailscale = first == 100 && second >= 64 && second <= 127;
  return isPrivate172 || isTailscale;
}
