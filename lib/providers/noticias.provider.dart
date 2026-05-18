import 'package:flips_app/models/noticias.model.dart';
import 'package:flutter/material.dart';

class NoticiasProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  bool _usingCache = false;
  List<NoticiaModel> _noticias = [];

  bool get loading => _loading;
  String get errorMessage => _errorMessage;
  bool get usingCache => _usingCache;
  List<NoticiaModel> get noticias => _noticias;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String value) {
    _errorMessage = value;
    notifyListeners();
  }

  void setUsingCache(bool value) {
    _usingCache = value;
    notifyListeners();
  }

  void setNoticias(List<NoticiaModel> value) {
    _noticias = value;
    notifyListeners();
  }
}
