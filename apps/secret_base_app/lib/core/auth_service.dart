import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http/api_client.dart';
import 'http/api_exception.dart';
import 'server_config.dart';

const googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '',
);
const kakaoReviewAutoLogin = bool.fromEnvironment(
  'KAKAO_REVIEW_AUTO_LOGIN',
  defaultValue: false,
);
const _kakaoReviewHosts = {'secretbase.cloud', 'secertbase.kro.kr'};

Map<String, dynamic> _jsonObject(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a JSON object');
}

bool get isKakaoReviewHost {
  if (!kIsWeb) return false;
  return _kakaoReviewHosts.contains(Uri.base.host.toLowerCase());
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
  String? _googleError;
  bool _reviewAutoLoginLoading = false;
  String? _reviewAutoLoginError;
  late final ApiClient _apiClient = ApiClient(
    baseUrl: baseUrl,
    tokenProvider: () => _token,
    onUnauthorized: _handleUnauthorized,
  );

  bool _loggingOut = false;

  /// A 401 while a session token exists means the token is no longer valid.
  /// Login/register calls send no token (_token == null), so they never match.
  void _handleUnauthorized() {
    if (_token == null || _loggingOut) return;
    _loggingOut = true;
    unawaited(logout().whenComplete(() => _loggingOut = false));
  }

  String get baseUrl => serverBaseUrl;
  ApiClient get apiClient => _apiClient;

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

  /// 이메일 가입. 성공하면 null, 실패하면 서버 오류 코드(없으면 `network_error`).
  Future<String?> registerAccount({
    required String email,
    required String password,
    required String fullName,
    required String nickname,
    required String birthDate,
    required Map<String, bool> consents,
  }) async {
    try {
      await _apiClient.postJson(
        '/api/auth/register',
        body: {
          'email': email,
          // 비밀번호는 다듬지 않는다(공백도 비밀번호의 일부).
          'password': password,
          'user_name': nickname,
          'full_name': fullName,
          'nickname': nickname,
          'birth_date': birthDate,
          'consents': consents,
        },
      );
      return null;
    } on ApiException catch (e) {
      debugPrint('[Auth] Register error: ${e.code}');
      return e.code;
    } catch (e) {
      debugPrint('[Auth] Register error: $e');
      return 'network_error';
    }
  }

  /// 1.x 호환: 항목별 동의 없이 가입(서버가 약관·개인정보 동의만 기록).
  Future<bool> register(
    String email,
    String password,
    String fullName,
    String nickname,
    String birthDate,
  ) async => await registerAccount(
        email: email,
        password: password,
        fullName: fullName,
        nickname: nickname,
        birthDate: birthDate,
        consents: const {
          'terms': true,
          'privacy': true,
          'age14': true,
          'marketing': false,
        },
      ) ==
      null;

  /// 이메일 로그인. 성공하면 null, 실패하면 오류 코드
  /// (`invalid_credentials`, `network_error`, `timeout` …).
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      final data = _jsonObject(
        await _apiClient.postJson(
          '/api/auth/login',
          body: {'email': email, 'password': password},
        ),
      );
      await _storeAuthData(data);
      return null;
    } on ApiException catch (e) {
      debugPrint('[Auth] Login error: ${e.code}');
      return e.code;
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
      return 'network_error';
    }
  }

  Future<bool> login(String email, String password) async =>
      await loginWithEmail(email, password) == null;

  /// 가입이 끝나기 전(Google 첫 로그인: 닉네임·생일·동의 없음)인지.
  bool get signupRequired => _user?['SignupRequired'] == true;

  /// Google 첫 로그인 마무리. 성공하면 null, 실패하면 오류 코드.
  Future<String?> completeSignup({
    required String nickname,
    required String birthDate,
    required Map<String, bool> consents,
  }) async {
    if (_token == null) return 'unauthorized';
    try {
      await _apiClient.postJson(
        '/api/auth/complete-signup',
        body: {
          'nickname': nickname,
          'birth_date': birthDate,
          'consents': consents,
        },
      );
      await getProfile();
      return null;
    } on ApiException catch (e) {
      debugPrint('[Auth] Complete signup error: ${e.code}');
      if (e.code == 'signup_already_completed') {
        await getProfile();
        return null;
      }
      return e.code;
    } catch (e) {
      debugPrint('[Auth] Complete signup error: $e');
      return 'network_error';
    }
  }

  /// 비밀번호 재설정 메일(코드+링크) 요청. 성공하면 null, 실패하면 오류 코드
  /// (`mail_unavailable`, `invalid_email`, `rate_limited`, `network_error`).
  Future<String?> requestPasswordReset(String email) =>
      _resetCall('/api/auth/password-reset/request', {'email': email});

  /// 메일로 받은 6자리 코드가 맞는지 확인(비밀번호는 아직 바꾸지 않는다).
  Future<String?> verifyPasswordResetCode(String email, String code) =>
      _resetCall('/api/auth/password-reset/verify', {
        'email': email,
        'code': code,
      });

  /// 코드와 새 비밀번호로 재설정을 마친다.
  Future<String?> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) => _resetCall('/api/auth/password-reset/confirm', {
    'email': email,
    'code': code,
    'password': password,
  });

  Future<String?> _resetCall(String path, Map<String, dynamic> body) async {
    try {
      await _apiClient.postJson(path, body: body);
      return null;
    } on ApiException catch (e) {
      debugPrint('[Auth] Reset error: ${e.code}');
      if (e.statusCode == 429 && e.code != 'too_many_attempts') {
        return 'rate_limited';
      }
      return e.code;
    } catch (e) {
      debugPrint('[Auth] Reset error: $e');
      return 'network_error';
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
      final data = _jsonObject(
        await _apiClient.postJson('/api/auth/review-login'),
      );
      await _storeAuthData(data);
      return true;
    } catch (e) {
      debugPrint('[Auth] Review login error: $e');
      _reviewAutoLoginError = '자동으로 입장하지 못했어요. 다시 시도해 주세요.';
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
      return await _completeGoogleLogin(account);
    } catch (e) {
      _googleLoading = false;
      _googleError = _googleErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool>? _googleCompleteFuture;

  Future<bool> _completeGoogleLogin(GoogleSignInAccount account) {
    if (_googleCompleteFuture != null) return _googleCompleteFuture!;
    _googleCompleteFuture = _doCompleteGoogleLogin(account).whenComplete(() {
      _googleCompleteFuture = null;
    });
    return _googleCompleteFuture!;
  }

  Future<bool> _doCompleteGoogleLogin(GoogleSignInAccount account) async {
    try {
      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        _googleLoading = false;
        _googleError = 'Google 로그인을 마치지 못했어요. 다시 시도해 주세요.';
        notifyListeners();
        return false;
      }

      final data = _jsonObject(
        await _apiClient.postJson(
          '/api/auth/google',
          body: {'idToken': idToken},
        ),
      );
      await _storeAuthData(data);
      _googleLoading = false;
      _googleError = null;
      return true;
    } catch (e) {
      _googleLoading = false;
      _googleError = 'Google 로그인을 마치지 못했어요. 잠시 후 다시 시도해 주세요.';
      debugPrint('[Auth] Google login error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Runs before credentials are cleared (e.g. revoke the push token).
  Future<void> Function()? beforeLogout;

  Future<void> logout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {}
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
      await _apiClient.postJson(
        '/api/user/partner',
        body: {
          'userId': _user!['UserId'] ?? _user!['id'],
          'partnerCode': partnerCode,
        },
      );

      await getProfile();
      return true;
    } catch (e) {
      debugPrint('[Auth] Set partner error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPairingRequests() async {
    if (_token == null) return null;
    try {
      return _jsonObject(await _apiClient.getJson('/api/pairing/requests'));
    } catch (e) {
      debugPrint('[Auth] Pairing requests error: $e');
      return null;
    }
  }

  /// 연결 요청을 보내고 성공하면 null, 실패하면 서버 오류 코드를 돌려준다.
  Future<String?> requestPairing(String recipientCode) async {
    if (_token == null) return 'unauthorized';
    try {
      await _apiClient.postJson(
        '/api/pairing/requests',
        body: {'recipientCode': recipientCode},
      );
      return null;
    } on ApiException catch (error) {
      return error.code;
    } catch (e) {
      debugPrint('[Auth] Request pairing error: $e');
      return 'network_error';
    }
  }

  Future<String?> sendPairingRequest(String recipientCode) async {
    if (_token == null) return '로그인이 필요해요.';
    try {
      await _apiClient.postJson(
        '/api/pairing/requests',
        body: {'recipientCode': recipientCode},
      );
      return null;
    } on ApiException catch (error) {
      return switch (error.code) {
        'recipient_not_found' => '없는 코드예요. 상대의 코드를 다시 확인해 주세요.',
        'request_already_pending' => '이미 대기 중인 연결 요청이 있어요.',
        'active_couple_exists' => '이 코드의 주인은 지금 다른 상대와 연결되어 있어요.',
        'cannot_pair_with_self' => '내 코드로는 요청할 수 없어요. 상대의 코드를 입력해 주세요.',
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
      await _apiClient.postJson('/api/pairing/requests/$requestId/$action');
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
      await _apiClient.deleteJson('/api/user/partner');
      await getProfile();
      return true;
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
      await _apiClient.deleteJson('/api/user', body: body);
      await logout();
      return null;
    } on ApiException catch (error) {
      return error.code;
    } catch (e) {
      debugPrint('[Auth] Delete account error: $e');
      return 'network_error';
    }
  }

  Future<bool> markReunionNoticeSeen() async {
    if (_token == null) return false;
    try {
      await _apiClient.postJson('/api/couple/reunion-notice/seen');
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
      final data = _jsonObject(
        await _apiClient.getJson('/api/user/profile/$uid'),
      );
      _user = data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_user));
      notifyListeners();
      return _user;
    } on ApiException catch (error) {
      if (error.statusCode == 401 && !_loggingOut && _token != null) {
        await logout();
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
      final data = _jsonObject(
        await _apiClient.patchJson(
          '/api/user/profile/$uid',
          body: {
            'fullName': fullName,
            'nickname': nickname,
            'birthDate': birthDate,
          },
        ),
      );
      _user = data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_user));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Auth] Update profile error: $e');
      return false;
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null || _user == null) return '로그인이 필요해요.';
    final uid = _user!['UserId'] ?? _user!['id'];
    try {
      await _apiClient.patchJson(
        '/api/user/password/$uid',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      return null;
    } on ApiException catch (error) {
      return switch (error.code) {
        'invalid_current_password' => '현재 비밀번호가 맞지 않아요.',
        'weak_password' => '새 비밀번호는 8자 이상, 영문과 숫자를 함께 써 주세요.',
        'password_login_not_enabled' => 'Google로 가입한 계정에는 비밀번호가 없어요.',
        _ => '비밀번호를 바꾸지 못했어요. 다시 시도해 주세요.',
      };
    } catch (e) {
      debugPrint('[Auth] Update password error: $e');
      return '비밀번호를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요.';
    }
  }

  String _googleErrorMessage(Object error) {
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Google 로그인을 취소했어요.',
        GoogleSignInExceptionCode.interrupted => 'Google 로그인이 중단됐어요. 다시 시도해 주세요.',
        GoogleSignInExceptionCode.clientConfigurationError =>
          '지금은 Google 로그인을 쓸 수 없어요. 이메일로 로그인해 주세요.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          '지금은 Google 로그인을 쓸 수 없어요. 이메일로 로그인해 주세요.',
        GoogleSignInExceptionCode.uiUnavailable =>
          '이 기기에서는 Google 로그인 창을 열 수 없어요.',
        _ => 'Google 로그인을 하지 못했어요. 다시 시도해 주세요.',
      };
    }
    return 'Google 로그인을 하지 못했어요. 다시 시도해 주세요.';
  }
}
