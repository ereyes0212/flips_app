import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  bool _loading = false;
  bool _error = false;
  String _nombreUsuario = '';
  String _password = '';

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
  String get password => _password;

  set password(String value) {
    _password = value;
    notifyListeners();
  }

  resetProvider() {
    _loading = false;
    _error = false;
    _nombreUsuario = '';
    notifyListeners();
  }
}
