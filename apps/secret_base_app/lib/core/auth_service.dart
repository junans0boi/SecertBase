import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart';

const googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '',
);

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  Map<String, dynamic>? _user;
  Future<void>? _googleInitFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;
  bool _googleLoading = false;
  bool _googleCompleting = false;
  String? _googleError;

  String get baseUrl => serverBaseUrl;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get googleLoading => _googleLoading;
  String? get googleError => _googleError;
  bool get isGoogleLoginConfigured => googleClientId.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      _user = jsonDecode(userJson);
      // Refresh profile and await it to ensure we have latest room info
      await getProfile();
    }
    await initGoogleSignIn();
    notifyListeners();
  }

  Future<void> initGoogleSignIn() {
    if (!isGoogleLoginConfigured) {
      return Future.value();
    }

    _googleInitFuture ??= GoogleSignIn.instance
        .initialize(clientId: googleClientId, serverClientId: googleClientId)
        .then((_) {
          _googleSub ??= GoogleSignIn.instance.authenticationEvents.listen(
            (event) {
              if (event is GoogleSignInAuthenticationEventSignIn) {
                unawaited(_completeGoogleLogin(event.user));
              }
            },
            onError: (Object error) {
              _googleLoading = false;
              _googleError = _googleErrorMessage(error);
              notifyListeners();
            },
          );
        });

    return _googleInitFuture!;
  }

  Future<bool> register(String email, String password, String userName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'user_name': userName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[Auth] Register error: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user));

        // Final verification of profile to ensure all fields like UserCode are mapped correctly
        await getProfile();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('[Auth] Login error: $e');
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    if (!isGoogleLoginConfigured || _googleLoading) return false;

    _googleLoading = true;
    _googleError = null;
    notifyListeners();

    try {
      await initGoogleSignIn();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _googleLoading = false;
        notifyListeners();
        return false;
      }

      final account = await GoogleSignIn.instance.authenticate();
      return _completeGoogleLogin(account);
    } catch (e) {
      _googleLoading = false;
      _googleError = _googleErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> _completeGoogleLogin(GoogleSignInAccount account) async {
    if (_googleCompleting) return false;
    _googleCompleting = true;

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _googleCompleting = false;
      _googleLoading = false;
      _googleError = 'Google 인증 토큰을 받지 못했습니다.';
      notifyListeners();
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user));

        await getProfile();

        _googleCompleting = false;
        _googleLoading = false;
        _googleError = null;
        notifyListeners();
        return true;
      }

      _googleCompleting = false;
      _googleLoading = false;
      _googleError = 'Google 로그인에 실패했습니다.';
      notifyListeners();
      return false;
    } catch (e) {
      _googleCompleting = false;
      _googleLoading = false;
      _googleError = 'Google 로그인 중 오류가 발생했습니다.';
      print('[Auth] Google login error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _googleError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    if (isGoogleLoginConfigured) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<bool> setPartner(String partnerCode) async {
    if (_token == null || _user == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/partner'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'userId': _user!['UserId'] ?? _user!['id'],
          'partnerCode': partnerCode,
        }),
      );

      if (response.statusCode == 200) {
        await getProfile();
        return true;
      }
      return false;
    } catch (e) {
      print('[Auth] Set partner error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    if (_token == null || _user == null) return null;
    final uid = _user!['UserId'] ?? _user!['id'];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile/$uid'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(_user));
        notifyListeners();
        return _user;
      }
      return null;
    } catch (e) {
      print('[Auth] Get profile error: $e');
      return null;
    }
  }

  String _googleErrorMessage(Object error) {
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Google 로그인이 취소되었습니다.',
        GoogleSignInExceptionCode.interrupted => 'Google 로그인이 중단되었습니다.',
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google 로그인 설정이 필요합니다.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google OAuth 설정을 확인해주세요.',
        GoogleSignInExceptionCode.uiUnavailable =>
          '현재 환경에서 Google 로그인 UI를 열 수 없습니다.',
        _ => 'Google 로그인에 실패했습니다.',
      };
    }
    return 'Google 로그인에 실패했습니다.';
  }
}
