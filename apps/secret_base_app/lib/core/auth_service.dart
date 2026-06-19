import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  Map<String, dynamic>? _user;

  String get baseUrl => serverBaseUrl;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      _user = jsonDecode(userJson);
      // Refresh profile and await it to ensure we have latest room info
      await getProfile();
    }
    notifyListeners();
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
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
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

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
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
        headers: {
          'Authorization': 'Bearer $_token',
        },
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
}
