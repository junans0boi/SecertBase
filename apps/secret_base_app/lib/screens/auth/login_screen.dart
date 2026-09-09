import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/main_design.dart';
import '../../core/auth_service.dart';
import '../../widgets/google_sign_in_button.dart';
import 'auth_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openLogin({String? email}) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _EmailLoginSheet(initialEmail: email),
  );

  Future<void> _openRegister() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (mounted && email != null) await _openLogin(email: email);
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    header: Row(
      children: [
        const BrandLogo(size: 34),
        const SizedBox(width: 9),
        Text('비밀기지', style: authText(size: 17, weight: FontWeight.w700)),
      ],
    ),
    content: const _LoginHero(),
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthButton(
          label: '이메일로 로그인',
          onPressed: _auth.googleLoading ? null : _openLogin,
        ),
        if (_auth.isGoogleLoginConfigured) ...[
          const SizedBox(height: 12),
          buildGoogleSignInButton(
            onPressed: () => _auth.loginWithGoogle(),
            loading: _auth.googleLoading,
          ),
          if (_auth.googleError != null) AuthError(_auth.googleError!),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: _auth.googleLoading ? null : _openRegister,
          child: Text.rich(
            TextSpan(
              text: '아직 계정이 없나요?  ',
              style: authText(size: 14, color: authSecondary),
              children: [
                TextSpan(
                  text: '회원가입',
                  style: authText(
                    size: 14,
                    weight: FontWeight.w700,
                    color: authInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'OUR PRIVATE SPACE',
        style: authText(
          size: 11,
          color: authPrimary,
          weight: FontWeight.w700,
        ).copyWith(letterSpacing: 2.1),
      ),
      const SizedBox(height: 18),
      Text(
        '둘만의 시간을\n기록해보세요.',
        style: authText(
          size: 35,
          weight: FontWeight.w800,
          height: 1.2,
        ).copyWith(letterSpacing: -1.4),
      ),
      const SizedBox(height: 15),
      Text(
        '함께 기록하고, 놀고, 마음을 나누는\n우리만의 작은 공간이에요.',
        style: authText(size: 15, color: authSecondary, height: 1.55),
      ),
      const SizedBox(height: 38),
      Center(
        child: Container(
          width: 222,
          height: 222,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEEF4F8), Color(0xFFFAFBFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(70),
            border: Border.all(color: authPrimarySoft),
            boxShadow: [
              BoxShadow(
                color: authPrimary.withAlpha(20),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: const Center(child: BrandLogo(size: 148)),
        ),
      ),
      const SizedBox(height: 26),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_dot(active: true), _dot(), _dot()],
      ),
      const SizedBox(height: 13),
      Text(
        '기록  ·  놀이  ·  우리만의 공간',
        textAlign: TextAlign.center,
        style: authText(size: 12, color: authMuted, weight: FontWeight.w600),
      ),
    ],
  );

  static Widget _dot({bool active = false}) {
    return Container(
      width: active ? 22 : 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: active ? authPrimary : authLine,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _EmailLoginSheet extends StatefulWidget {
  const _EmailLoginSheet({this.initialEmail});
  final String? initialEmail;
  @override
  State<_EmailLoginSheet> createState() => _EmailLoginSheetState();
}

class _EmailLoginSheetState extends State<_EmailLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await AuthService().login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      TextInput.finishAutofillContext();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() => _error = '로그인하지 못했어요. 이메일, 비밀번호와 네트워크 연결을 확인해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) => AuthTheme(
    child: PopScope(
      canPop: !_loading,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              24,
        ),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: '닫기',
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                AuthHeading(
                  title: widget.initialEmail == null
                      ? '다시 만나 반가워요'
                      : '가입을 축하해요!',
                  description: widget.initialEmail == null
                      ? '우리의 이야기를 이어가 볼까요?'
                      : '만든 계정으로 로그인해 비밀기지를 시작하세요.',
                ),
                const SizedBox(height: 28),
                AuthField(
                  label: '이메일',
                  child: TextFormField(
                    controller: _emailCtrl,
                    enabled: !_loading,
                    style: authText(),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: '이메일 주소를 입력해주세요',
                    ),
                    validator: validateAuthEmail,
                  ),
                ),
                const SizedBox(height: 20),
                AuthField(
                  label: '비밀번호',
                  child: TextFormField(
                    controller: _passwordCtrl,
                    enabled: !_loading,
                    style: authText(),
                    obscureText: !_showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: '비밀번호를 입력해주세요',
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 21,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '비밀번호를 입력해주세요.'
                        : null,
                  ),
                ),
                if (_error != null) AuthError(_error!),
                const SizedBox(height: 28),
                AuthButton(label: '로그인', loading: _loading, onPressed: _login),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
