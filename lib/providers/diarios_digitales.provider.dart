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
}
