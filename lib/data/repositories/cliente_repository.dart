import '../datasources/cliente_remote_datasource.dart';
import '../models/catalogo/catalogo_dtos.dart';
import '../models/checkout/checkout_dtos.dart';
import '../models/pagos/finanzas_dtos.dart';
import '../models/perfil/perfil_dtos.dart';

class ClienteRepository {
  ClienteRepository(this._remote);
  final ClienteRemoteDataSource _remote;

  Future<PerfilResponseDto> obtenerPerfil() => _remote.getPerfil();
  Future<PerfilResponseDto> actualizarPerfil(UpdatePerfilRequestDto dto) => _remote.updatePerfil(dto);
  Future<void> cambiarPassword(ChangePasswordRequestDto dto) => _remote.changePassword(dto);
  Future<CheckoutDto> consultarCheckout() => _remote.getCheckout();
  Future<CheckoutDto> crearCheckout(CheckoutDto dto) => _remote.createCheckout(dto);
  Future<CheckoutDto> actualizarCheckout(CheckoutDto dto) => _remote.updateCheckout(dto);
  Future<List<PaqueteDto>> obtenerPaquetes() => _remote.getPaquetes();
  Future<SuscripcionDto?> obtenerSuscripcionActiva() => _remote.getSuscripcionActiva();
  Future<List<SuscripcionDto>> obtenerMisSuscripciones() => _remote.getMisSuscripciones();
  Future<List<RegistroDto>> obtenerMisFacturas() => _remote.getMisFacturas();
  Future<List<RegistroDto>> obtenerMisPagos() => _remote.getMisPagos();
  Future<List<RegistroDto>> obtenerMisNotas() => _remote.getMisNotas();
}
