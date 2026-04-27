import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? secureStorage, bool enabled = true})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _enabled = enabled;

  static const _tokenKey = 'pawplan_access_token';

  final FlutterSecureStorage _secureStorage;
  final bool _enabled;

  Future<String?> readToken() async {
    if (!_enabled) return null;
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    if (!_enabled) return;
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      return;
    }
  }

  Future<void> clear() async {
    if (!_enabled) return;
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      return;
    }
  }
}
