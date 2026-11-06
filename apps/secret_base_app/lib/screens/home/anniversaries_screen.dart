import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../secret_base/secret_base_screen.dart';

/// 기념일 now lives in the 비밀기지 hub; this keeps the old entry point (더보기,
/// 홈 바로가기) and opens the hub on its 기념일 tab.
class AnniversariesScreen extends StatelessWidget {
  const AnniversariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return SecretBaseScreen(
      baseUrl: auth.baseUrl,
      authHeaders: {
        if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
      },
      initialTab: 1,
    );
  }
}
