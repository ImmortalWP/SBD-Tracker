import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized secure token storage.
/// Uses Android Keystore / iOS Keychain for encrypted storage.
/// Only JWT tokens are stored here — non-sensitive cache data
/// remains in SharedPreferences.
class SecureTokenStorage {
  static const _tokenKey = 'sbd_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Read the stored JWT token (null if not set or deleted).
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  /// Store the JWT token securely.
  static Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Delete the stored JWT token.
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Delete all secure storage entries (for full logout/account deletion).
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
