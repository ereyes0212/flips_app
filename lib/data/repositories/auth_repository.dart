import '../../core/network/token_storage.dart';
import '../datasources/cliente_remote_datasource.dart';
import '../models/auth/auth_dtos.dart';

class AuthRepository {
  AuthRepository(this._remote, this._tokenStorage);
  final ClienteRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  Future<AuthResponseDto> login(LoginRequestDto dto) async {
    final res = await _remote.login(dto);
    await saveToken(res.token);
    return res;
  }

  Future<AuthResponseDto> register(RegisterRequestDto dto) async {
    final res = await _remote.register(dto);
    await saveToken(res.token);
    return res;
  }

  Future<void> logout() => deleteToken();
  Future<String?> getToken() => _tokenStorage.getToken();
  Future<void> saveToken(String token) => _tokenStorage.saveToken(token);
  Future<void> deleteToken() => _tokenStorage.deleteToken();
}
