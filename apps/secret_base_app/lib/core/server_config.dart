import 'package:flutter/foundation.dart';

const configuredServerUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://localhost:4100',
);

String get serverBaseUrl {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    final host = Uri.base.host;
    // localhost/127.0.0.1 은 Flutter dev 서버 — SOCKET_URL dart-define 사용
    // 실제 도메인이면 같은 오리진에 백엔드가 있는 프로덕션 배포
    if ((origin.startsWith('http://') || origin.startsWith('https://')) &&
        host != 'localhost' &&
        host != '127.0.0.1') {
      return origin;
    }
  }

  return configuredServerUrl;
}
