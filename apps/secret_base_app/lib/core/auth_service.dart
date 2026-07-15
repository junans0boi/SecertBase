import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart';

const googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '',
);
const kakaoReviewAutoLogin = bool.fromEnvironment(
  'KAKAO_REVIEW_AUTO_LOGIN',
  defaultValue: false,
);

bool get isKakaoReviewHost {
  if (!kIsWeb) return false;
  return Uri.base.host.toLowerCase() == 'secertbase.kro.kr';
}

bool get shouldUseKakaoReviewAutoLogin =>
    kakaoReviewAutoLogin && isKakaoReviewHost;

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
  bool _reviewAutoLoginLoading = false;
  String? _reviewAutoLoginError;

  String get baseUrl => serverBaseUrl;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get googleLoading => _googleLoading;
  String? get googleError => _googleError;
  bool get isGoogleLoginConfigured => googleClientId.isNotEmpty;
  bool get isKakaoReviewAutoLoginEnabled => shouldUseKakaoReviewAutoLogin;
  bool get reviewAutoLoginLoading => _reviewAutoLoginLoading;
  String? get reviewAutoLoginError => _reviewAutoLoginError;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      _user = jsonDecode(userJson);
      // Refresh profile and await it to ensure we have latest room info
      await getProfile();
    }
    if (shouldUseKakaoReviewAutoLogin) {
      await loginForKakaoReview();
    }
    await initGoogleSignIn();
    notifyListeners();
  }

  Future<void> initGoogleSignIn() {
    if (!isGoogleLoginConfigured) {
      return Future.value();
    }

    _googleInitFuture ??= GoogleSignIn.instance
        .initialize(
          clientId: googleClientId,
          serverClientId: kIsWeb ? null : googleClientId,
        )
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

  Future<bool> register(
    String email,
    String password,
    String fullName,
    String nickname,
    String birthDate,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'user_name': nickname,
          'full_name': fullName,
          'nickname': nickname,
          'birth_date': birthDate,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Auth] Register error: $e');
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
        await _storeAuthData(data);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
      return false;
    }
  }

  Future<bool> loginForKakaoReview() async {
    if (!shouldUseKakaoReviewAutoLogin || _reviewAutoLoginLoading) {
      return _token != null;
    }

    _reviewAutoLoginLoading = true;
    _reviewAutoLoginError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/review-login'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storeAuthData(data);
        return true;
      }

      _reviewAutoLoginError = '심사용 자동 입장 준비가 필요합니다.';
      return false;
    } catch (e) {
      debugPrint('[Auth] Review login error: $e');
      _reviewAutoLoginError = '심사용 자동 입장 중 오류가 발생했습니다.';
      return false;
    } finally {
      _reviewAutoLoginLoading = false;
      notifyListeners();
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
        await _storeAuthData(data);
        _googleCompleting = false;
        _googleLoading = false;
        _googleError = null;
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
      debugPrint('[Auth] Google login error: $e');
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

  Future<void> _storeAuthData(Map<String, dynamic> data) async {
    _token = data['token'];
    _user = data['user'];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token!);
    await prefs.setString('user_data', jsonEncode(_user));

    await getProfile();
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
      debugPrint('[Auth] Set partner error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPairingRequests() async {
    if (_token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/pairing/requests'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Auth] Pairing requests error: $e');
      return null;
    }
  }

  Future<String?> sendPairingRequest(String recipientCode) async {
    if (_token == null) return '로그인이 필요합니다.';
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/pairing/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'recipientCode': recipientCode}),
      );
      if (response.statusCode == 201) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return switch (data['reason']) {
        'recipient_not_found' => '상대방 코드를 찾지 못했어요.',
        'request_already_pending' => '이미 두 분 사이에 대기 중인 요청이 있어요.',
        'active_couple_exists' => '이미 연결된 사용자는 새 요청을 받을 수 없어요.',
        'cannot_pair_with_self' => '내 코드로는 요청할 수 없어요.',
        _ => '요청을 보내지 못했어요.',
      };
    } catch (e) {
      debugPrint('[Auth] Send pairing request error: $e');
      return '요청을 보내지 못했어요.';
    }
  }

  Future<bool> respondToPairingRequest(int requestId, String action) async {
    if (_token == null || !{'accept', 'reject', 'cancel'}.contains(action)) {
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/pairing/requests/$requestId/$action'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode != 200) return false;
      if (action == 'accept') await getProfile();
      return true;
    } catch (e) {
      debugPrint('[Auth] Pairing response error: $e');
      return false;
    }
  }

  Future<bool> disconnectPartner() async {
    if (_token == null || _user == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/user/partner'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        await getProfile();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Auth] Disconnect partner error: $e');
      return false;
    }
  }

  /// 회원 탈퇴: 이메일 사용자는 현재 비밀번호 필수.
  /// 성공 시 null 반환, 실패 시 오류 코드 문자열 반환.
  Future<String?> deleteAccount({String? password}) async {
    if (_token == null || _user == null) return 'unauthorized';
    try {
      final body = <String, dynamic>{};
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }
      final response = await http.delete(
        Uri.parse('$baseUrl/api/user'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        await logout();
        return null;
      }
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['reason'] as String? ?? 'unknown_error';
      } catch (_) {
        return 'unknown_error';
      }
    } catch (e) {
      debugPrint('[Auth] Delete account error: $e');
      return 'network_error';
    }
  }

  Future<bool> markReunionNoticeSeen() async {
    if (_token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/couple/reunion-notice/seen'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode != 200) return false;
      await getProfile();
      return true;
    } catch (e) {
      debugPrint('[Auth] Reunion notice error: $e');
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
      debugPrint('[Auth] Get profile error: $e');
      return null;
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String nickname,
    required String birthDate,
  }) async {
    if (_token == null || _user == null) return false;
    final uid = _user!['UserId'] ?? _user!['id'];
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/user/profile/$uid'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'fullName': fullName,
          'nickname': nickname,
          'birthDate': birthDate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(_user));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Auth] Update profile error: $e');
      return false;
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null || _user == null) return '로그인이 필요합니다.';
    final uid = _user!['UserId'] ?? _user!['id'];
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/user/password/$uid'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return switch (data['reason']) {
        'invalid_current_password' => '현재 비밀번호가 맞지 않습니다.',
        'weak_password' => '새 비밀번호는 6자 이상이어야 합니다.',
        'password_login_not_enabled' => '소셜 로그인 계정에는 아직 비밀번호가 없습니다.',
        _ => '비밀번호 변경에 실패했습니다.',
      };
    } catch (e) {
      debugPrint('[Auth] Update password error: $e');
      return '비밀번호 변경 중 오류가 발생했습니다.';
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
