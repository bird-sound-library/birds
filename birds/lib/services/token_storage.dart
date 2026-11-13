
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
      key: _accessKey,
      value: accessToken,
    );

    await _storage.write(
      key: _refreshKey,
      value: refreshToken,
    );
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: _accessKey);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
