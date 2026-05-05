import 'package:flips_app/models/paquetes.model.dart';
import 'package:flutter/material.dart';

class PaquetesProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  List<PaqueteModel> _paquetes = [];

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  List<PaqueteModel> get paquetes => _paquetes;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setPaquetes(List<PaqueteModel> value) {
    _paquetes = value;
    notifyListeners();
  }
}
