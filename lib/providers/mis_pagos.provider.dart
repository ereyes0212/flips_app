import 'package:flips_app/models/mis_pagos.model.dart';
import 'package:flutter/material.dart';

class MisPagosProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  List<PagoModel> _pagos = [];

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  List<PagoModel> get pagos => _pagos;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setPagos(List<PagoModel> value) {
    _pagos = value;
    notifyListeners();
  }
}
