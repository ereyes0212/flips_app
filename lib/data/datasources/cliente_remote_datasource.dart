import '../../core/network/api_client.dart';
import '../models/auth/auth_dtos.dart';
import '../models/catalogo/catalogo_dtos.dart';
import '../models/checkout/checkout_dtos.dart';
import '../models/pagos/finanzas_dtos.dart';
import '../models/perfil/perfil_dtos.dart';

class ClienteRemoteDataSource {
  ClienteRemoteDataSource(this._apiClient);
  final ApiClient _apiClient;

  /// POST /api/auth/register
  Future<AuthResponseDto> register(RegisterRequestDto dto) async {
    final r = await _apiClient.post<Map<String, dynamic>>('/api/auth/register', data: dto.toJson());
    return AuthResponseDto.fromJson(r.data ?? {});
  }

  /// POST /api/auth/login
  Future<AuthResponseDto> login(LoginRequestDto dto) async {
    final r = await _apiClient.post<Map<String, dynamic>>('/api/auth/login', data: dto.toJson());
    return AuthResponseDto.fromJson(r.data ?? {});
  }

  /// GET /api/mi-perfil
  Future<PerfilResponseDto> getPerfil() async {
    final r = await _apiClient.get<Map<String, dynamic>>('/api/mi-perfil');
    return PerfilResponseDto.fromJson(r.data ?? {});
  }

  /// PATCH /api/mi-perfil
  Future<PerfilResponseDto> updatePerfil(UpdatePerfilRequestDto dto) async {
    final r = await _apiClient.patch<Map<String, dynamic>>('/api/mi-perfil', data: dto.toJson());
    return PerfilResponseDto.fromJson(r.data ?? {});
  }

  /// POST /api/mi-perfil/password
  Future<void> changePassword(ChangePasswordRequestDto dto) =>
      _apiClient.post('/api/mi-perfil/password', data: dto.toJson());

  Future<CheckoutDto> getCheckout() async => CheckoutDto.fromJson((await _apiClient.get<Map<String, dynamic>>('/api/checkout')).data ?? {});
  Future<CheckoutDto> createCheckout(CheckoutDto dto) async => CheckoutDto.fromJson((await _apiClient.post<Map<String, dynamic>>('/api/checkout', data: dto.toJson())).data ?? {});
  Future<CheckoutDto> updateCheckout(CheckoutDto dto) async => CheckoutDto.fromJson((await _apiClient.put<Map<String, dynamic>>('/api/checkout', data: dto.toJson())).data ?? {});

  Future<List<PaqueteDto>> getPaquetes() async => ((await _apiClient.get<List<dynamic>>('/api/paquetes')).data ?? [])
      .map((e) => PaqueteDto.fromJson(e as Map<String, dynamic>))
      .toList();
  Future<SuscripcionDto?> getSuscripcionActiva() async {
    final data = (await _apiClient.get<Map<String, dynamic>>('/api/suscripcion-activa')).data;
    return data == null ? null : SuscripcionDto.fromJson(data);
  }
  Future<List<SuscripcionDto>> getMisSuscripciones() async => ((await _apiClient.get<List<dynamic>>('/api/mis-suscripciones')).data ?? [])
      .map((e) => SuscripcionDto.fromJson(e as Map<String, dynamic>)).toList();
  Future<List<RegistroDto>> getMisFacturas() async => ((await _apiClient.get<List<dynamic>>('/api/mis-facturas')).data ?? [])
      .map((e) => RegistroDto.fromJson(e as Map<String, dynamic>)).toList();
  Future<List<RegistroDto>> getMisPagos() async => ((await _apiClient.get<List<dynamic>>('/api/mis-pagos')).data ?? [])
      .map((e) => RegistroDto.fromJson(e as Map<String, dynamic>)).toList();
  Future<List<RegistroDto>> getMisNotas() async => ((await _apiClient.get<List<dynamic>>('/api/mis-notas')).data ?? [])
      .map((e) => RegistroDto.fromJson(e as Map<String, dynamic>)).toList();
}
