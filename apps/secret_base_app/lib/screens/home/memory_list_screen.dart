import 'package:flutter/material.dart';

import '../secret_base/secret_base_screen.dart';

/// "n년 전 오늘" now lives in the 비밀기지 hub; this keeps the old entry point
/// and opens the hub on its 추억 tab.
class MemoryListScreen extends StatelessWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;

  const MemoryListScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return SecretBaseScreen(
      baseUrl: baseUrl,
      authHeaders: authHeaders,
      initialTab: 3,
    );
  }
}
