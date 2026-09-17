import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'secure_token_storage.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  String? _username;
  bool _loading = true;

  String? get token => _token;
  String? get username => _username;
  bool get isAuthenticated => _token != null;
  bool get loading => _loading;

  AuthService() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    // Load token from secure storage (Android Keystore / iOS Keychain)
    _token = await SecureTokenStorage.getToken();
    if (_token != null) {
      _parseToken();
    }
    _loading = false;
    notifyListeners();
  }

  void _parseToken() {
    try {
      final parts = _token!.split('.');
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'] as int;
      if (exp * 1000 < DateTime.now().millisecondsSinceEpoch) {
        _token = null;
        _username = null;
        return;
      }
      _username = payload['username'];
    } catch (_) {
      _token = null;
      _username = null;
    }
  }

  Future<void> login(String username, String password) async {
    final data = await ApiService.login(username, password);
    _token = data['token'];
    _parseToken();
    // Store token in secure storage (encrypted)
    await SecureTokenStorage.setToken(_token!);
    // Update ApiService cached token
    ApiService.setCachedToken(_token);
    notifyListeners();
  }

  Future<void> register(String username, String password) async {
    final data = await ApiService.register(username, password);
    _token = data['token'];
    _parseToken();
    // Store token in secure storage (encrypted)
    await SecureTokenStorage.setToken(_token!);
    // Update ApiService cached token
    ApiService.setCachedToken(_token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _username = null;
    // Remove token from secure storage
    await SecureTokenStorage.deleteToken();
    // Clear ApiService cached token
    ApiService.setCachedToken(null);
    notifyListeners();
  }
}
