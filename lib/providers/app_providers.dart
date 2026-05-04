import '../controllers/app_controllers.dart';
import '../data/models/catalogo/catalogo_dtos.dart';
import '../data/models/checkout/checkout_dtos.dart';
import '../data/models/pagos/finanzas_dtos.dart';
import '../data/models/perfil/perfil_dtos.dart';
import 'base_provider.dart';

class AuthProvider extends BaseProvider {
  AuthProvider(this._controller);
  final AuthController _controller;
  Future<void> login(String email, String password) async {
    try { setLoading(true); setError(null); await _controller.login(email, password); } catch (e) { setError('$e'); } finally { setLoading(false); }
  }
}

class PerfilProvider extends BaseProvider {
  PerfilProvider(this._controller);
  final PerfilController _controller;
  PerfilResponseDto? perfil;
  Future<void> cargarPerfil() async { try { setLoading(true); perfil = await _controller.getPerfil(); notifyListeners(); } catch (e) { setError('$e'); } finally { setLoading(false);} }
}

class CheckoutProvider extends BaseProvider { CheckoutProvider(this._controller); final CheckoutController _controller; CheckoutDto? checkout; Future<void> cargarCheckout() async { try { setLoading(true); checkout = await _controller.getCheckout(); notifyListeners(); } catch(e){setError('$e');} finally {setLoading(false);} }}
class SuscripcionesProvider extends BaseProvider { List<dynamic> suscripciones = []; }
class PagosProvider extends BaseProvider { List<RegistroDto> pagos = []; List<RegistroDto> facturas = []; }
class NotasProvider extends BaseProvider { List<RegistroDto> notas = []; }
class PaquetesProvider extends BaseProvider { List<PaqueteDto> paquetes = []; }
