import 'package:flutter/material.dart';

import '../core/main_design.dart';

Widget buildPlatformGoogleSignInButton({
  required VoidCallback onPressed,
  required bool loading,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: const Icon(Icons.login, size: 20),
      label: Text(
        loading ? 'Google 로그인 중...' : 'Google로 계속하기',
        style: mainBody(size: 15, weight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: kMainInk,
        side: const BorderSide(color: kMainLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
