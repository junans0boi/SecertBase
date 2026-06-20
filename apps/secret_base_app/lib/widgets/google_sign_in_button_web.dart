import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildPlatformGoogleSignInButton({
  required VoidCallback onPressed,
  required bool loading,
}) {
  return IgnorePointer(
    ignoring: loading,
    child: SizedBox(
      width: double.infinity,
      height: 44,
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          size: web.GSIButtonSize.large,
          text: web.GSIButtonText.continueWith,
          shape: web.GSIButtonShape.rectangular,
          logoAlignment: web.GSIButtonLogoAlignment.left,
        ),
      ),
    ),
  );
}
