import 'package:flips_app/models/mis_facturas.model.dart';
import 'package:flutter/material.dart';

class MisFacturasProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  List<FacturaModel> _facturas = [];

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  List<FacturaModel> get facturas => _facturas;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setFacturas(List<FacturaModel> value) {
    _facturas = value;
    notifyListeners();
  }
}
