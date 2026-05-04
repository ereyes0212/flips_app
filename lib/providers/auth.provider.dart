import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  bool _loading = false;
  bool _error = false;
  String _nombreUsuario = '';
  String _user = '';
  String _idUser = '';
  String _token = '';
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

  resetProvider() {
    _loading = false;
    _error = false;
    _nombreUsuario = '';
    _user = '';
    _idUser = '';
    _token = '';
    _password = '';
    notifyListeners();
  }
}
