import 'package:flutter/widgets.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.html) 'google_sign_in_button_web.dart';

Widget buildGoogleSignInButton({
  required VoidCallback onPressed,
  required bool loading,
}) {
  return buildPlatformGoogleSignInButton(
    onPressed: onPressed,
    loading: loading,
  );
}
