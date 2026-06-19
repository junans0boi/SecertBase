import 'package:flutter/foundation.dart';

const configuredServerUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://localhost:4100',
);

String get serverBaseUrl {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('http://') || origin.startsWith('https://')) {
      return origin;
    }
  }

  return configuredServerUrl;
}
