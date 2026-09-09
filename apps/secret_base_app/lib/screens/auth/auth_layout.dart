import 'package:flutter/material.dart';
import '../../core/main_design.dart';

// Authentication keeps the brand mark as the only warm accent. The UI uses
// a calm navy and cool neutral palette so it feels natural to both partners.
const authInk = Color(0xFF202832);
const authSecondary = Color(0xFF6C7784);
const authMuted = Color(0xFFAAB3BD);
const authLine = Color(0xFFE3E8ED);
const authSurface = Color(0xFFF6F8FA);
const authPrimary = Color(0xFF29445C);
const authPrimarySoft = Color(0xFFEAF1F6);
const authError = Color(0xFFC43D4D);

TextStyle authText({
  double size = 16,
  Color color = authInk,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
}) => mainBody(size: size, color: color, weight: weight, height: height);

class AuthTheme extends StatelessWidget {
  const AuthTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: authPrimary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: authInk,
        outline: authLine,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: authPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: authSurface,
        hintStyle: authText(color: authSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: _border(authLine),
        enabledBorder: _border(authLine),
        focusedBorder: _border(authPrimary),
        errorBorder: _border(authError),
        focusedErrorBorder: _border(authError),
        errorMaxLines: 2,
      ),
    ),
    child: child,
  );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color),
  );
}

/// Authentication content stays centered on wide screens and scrolls when
/// the keyboard or a short viewport reduces the available height.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.header,
    required this.content,
    required this.footer,
  });
  final Widget header;
  final Widget content;
  final Widget footer;

  @override
  Widget build(BuildContext context) => AuthTheme(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 32),
                    content,
                    const SizedBox(height: 32),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    required this.description,
  });
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: authText(
          size: 31,
          weight: FontWeight.w800,
          height: 1.28,
        ).copyWith(letterSpacing: -1.1),
      ),
      const SizedBox(height: 14),
      Text(
        description,
        style: authText(size: 15, color: authSecondary, height: 1.55),
      ),
    ],
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        backgroundColor: authPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: authLine,
        disabledForegroundColor: authSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: authSecondary,
                semanticsLabel: '처리 중',
              ),
            )
          : Text(
              label,
              style: authText(
                size: 16,
                weight: FontWeight.w700,
                color: onPressed == null ? authSecondary : Colors.white,
              ),
            ),
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: authText(size: 14, weight: FontWeight.w600)),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(message, style: authText(size: 14, color: authError)),
    ),
  );
}

String? validateAuthEmail(String? value) {
  if (value == null || value.trim().isEmpty) return '이메일을 입력해주세요.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
    return '이메일 주소를 확인해주세요.';
  }
  return null;
}

class AuthProgress extends StatelessWidget {
  const AuthProgress({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index < current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 5,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? authPrimary : authLine,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}
