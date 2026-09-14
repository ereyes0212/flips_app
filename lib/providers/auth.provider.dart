import 'package:flips_app/services/session.service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de sesión que la UI observa.
///
/// Con la lectura abierta a invitados dejó de bastar con leer la sesión una vez
/// al arrancar: ahora se entra y se sale sin reiniciar la app, así que la
/// pantalla tiene que enterarse. Este provider se hidrata al crearse y se
/// resuscribe a [SessionService.sesionRevision], que es lo que avisa cuando se
/// guardan o se borran credenciales — venga de un login, de un logout o de un
/// refresh rechazado a media navegación.
class AuthProvider with ChangeNotifier {
  AuthProvider() {
    SessionService.sesionRevision.addListener(hidratar);
    hidratar();
  }

  bool _loading = false;
  bool _error = false;
  String _nombreUsuario = '';
  String _user = '';
  String _idUser = '';
  String _token = '';
  String _password = '';
  bool _sesionIniciada = false;
  bool _sesionResuelta = false;

  /// La hidratación es asíncrona y arranca en el constructor: si el provider se
  /// desecha mientras la lectura del disco sigue en vuelo, notificar después
  /// revienta. Pasa en cada hot reload y al cerrar la app.
  bool _desechado = false;

  void _notificarSiVive() {
    if (_desechado) return;
    notifyListeners();
  }

  /// Hay credenciales guardadas en el dispositivo.
  ///
  /// No garantiza que el token siga vigente: eso lo resuelve cada petición.
  /// Para decidir qué se le muestra a alguien alcanza con saber si tiene cuenta.
  bool get sesionIniciada => _sesionIniciada;

  /// Navega sin cuenta. Lee noticias; no llega a perfil, pagos ni suscripción.
  bool get esInvitado => !_sesionIniciada;

  /// Falso solo durante el primer arranque, mientras se lee el disco.
  ///
  /// Sirve para no parpadear "Crea tu cuenta" a un usuario que sí tiene sesión.
  bool get sesionResuelta => _sesionResuelta;

  bool get loading => _loading;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  bool get error => _error;

  set error(bool value) {
    _error = value;
    notifyListeners();
  }

  String get nombreUsuario => _nombreUsuario;

  set nombreUsuario(String value) {
    _nombreUsuario = value;
    notifyListeners();
  }

  String get user => _user;

  set user(String value) {
    _user = value;
    notifyListeners();
  }

  String get idUser => _idUser;

  set idUser(String value) {
    _idUser = value;
    notifyListeners();
  }

  String get token => _token;

  set token(String value) {
    _token = value;
    notifyListeners();
  }

  String get password => _password;

  set password(String value) {
    _password = value;
    notifyListeners();
  }

  /// Relee la sesión del disco y avisa a quien escuche.
  ///
  /// Tolera fallos de `SharedPreferences` a propósito: si no se puede leer el
  /// almacenamiento, se navega como invitado en vez de dejar la app colgada en
  /// un estado indeterminado.
  Future<void> hidratar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = SessionService.normalizeToken(prefs.getString('token'));
      final hayToken = token != null && token.isNotEmpty;

      _sesionIniciada = hayToken;
      _token = hayToken ? token : '';
      _nombreUsuario = hayToken ? prefs.getString('nombre') ?? '' : '';
      _user = hayToken ? prefs.getString('user') ?? '' : '';
      _idUser = hayToken ? prefs.getString('idUser') ?? '' : '';
    } catch (_) {
      _sesionIniciada = false;
      _token = '';
      _nombreUsuario = '';
      _user = '';
      _idUser = '';
    } finally {
      _sesionResuelta = true;
      _notificarSiVive();
    }
  }

  resetProvider() {
    _loading = false;
    _error = false;
    _nombreUsuario = '';
    _user = '';
    _idUser = '';
    _token = '';
    _password = '';
    _sesionIniciada = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    SessionService.sesionRevision.removeListener(hidratar);
    super.dispose();
  }
}
