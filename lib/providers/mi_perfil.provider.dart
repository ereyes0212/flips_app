import 'package:flips_app/models/mi_perfil.model.dart';
import 'package:flutter/material.dart';

class MiPerfilProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  MiPerfilModel? _perfil;

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  MiPerfilModel? get perfil => _perfil;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setPerfil(MiPerfilModel? value) {
    _perfil = value;
    notifyListeners();
  }

  void resetProvider() {
    _loading = false;
    _errorMessage = '';
    _perfil = null;
    notifyListeners();
  }
}
