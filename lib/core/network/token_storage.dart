import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'jwt_token';
  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) => _storage.write(key: _key, value: token);
  Future<String?> getToken() => _storage.read(key: _key);
  Future<void> deleteToken() => _storage.delete(key: _key);
}
