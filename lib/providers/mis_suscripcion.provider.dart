import 'package:flips_app/models/mis_suscripcion.model.dart';
import 'package:flutter/material.dart';

class MisSuscripcionProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  List<SuscripcionModel> _suscripciones = [];

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  List<SuscripcionModel> get suscripciones => _suscripciones;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setSuscripciones(List<SuscripcionModel> value) {
    _suscripciones = value;
    notifyListeners();
  }
}
