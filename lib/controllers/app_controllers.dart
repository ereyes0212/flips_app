import '../data/models/auth/auth_dtos.dart';
import '../data/models/checkout/checkout_dtos.dart';
import '../data/models/perfil/perfil_dtos.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cliente_repository.dart';

class AuthController {
  AuthController(this._repo);
  final AuthRepository _repo;
  Future<void> login(String email, String password) => _repo.login(LoginRequestDto(email: email, password: password));
  Future<void> register(String nombre, String email, String password) =>
      _repo.register(RegisterRequestDto(nombre: nombre, email: email, password: password));
  Future<void> logout() => _repo.logout();
}

class PerfilController {
  PerfilController(this._repo);
  final ClienteRepository _repo;
  Future getPerfil() => _repo.obtenerPerfil();
  Future updatePerfil(UpdatePerfilRequestDto dto) => _repo.actualizarPerfil(dto);
}

class CheckoutController {
  CheckoutController(this._repo);
  final ClienteRepository _repo;
  Future getCheckout() => _repo.consultarCheckout();
  Future saveCheckout(CheckoutDto dto) => _repo.actualizarCheckout(dto);
}
