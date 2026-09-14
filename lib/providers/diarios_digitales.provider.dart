import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flutter/material.dart';

class DiariosDigitalesProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  List<DiarioDigitalModel> _diarios = [];
  bool _subscriptionRequired = false;

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  List<DiarioDigitalModel> get diarios => _diarios;
  bool get subscriptionRequired => _subscriptionRequired;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setDiarios(List<DiarioDigitalModel> value) {
    _diarios = value;
    notifyListeners();
  }

  void setSubscriptionRequired(bool value) {
    _subscriptionRequired = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Última edición pública
  // ---------------------------------------------------------------------------
  //
  // Va en campos aparte y no en [_diarios] a propósito: se pide a otro endpoint,
  // se muestra en otro sitio y sobre todo se abre con otras cabeceras (URL
  // firmada de S3 en vez de la ruta privada). Mezclarlas haría fácil abrir una
  // con el mecanismo de la otra, que es exactamente lo que rompe.

  DiarioDigitalModel? _ultimoPublico;
  bool _cargandoUltimoPublico = false;
  bool _sinEdicionPublica = false;

  DiarioDigitalModel? get ultimoPublico => _ultimoPublico;
  bool get cargandoUltimoPublico => _cargandoUltimoPublico;

  /// La API respondió que todavía no hay ninguna edición publicada.
  bool get sinEdicionPublica => _sinEdicionPublica;

  void setCargandoUltimoPublico(bool value) {
    _cargandoUltimoPublico = value;
    notifyListeners();
  }

  void setUltimoPublico(DiarioDigitalModel? value, {bool sinEdicion = false}) {
    _ultimoPublico = value;
    _sinEdicionPublica = sinEdicion;
    notifyListeners();
  }
}
