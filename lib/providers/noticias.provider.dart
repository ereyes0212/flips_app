import 'package:flips_app/models/noticias.model.dart';
import 'package:flutter/material.dart';

class NoticiasProvider with ChangeNotifier {
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadingCategorias = false;
  String _errorMessage = '';
  bool _usingCache = false;
  int _page = 1;
  bool _hasMore = true;
  bool _loadMoreFailed = false;
  String _loadMoreError = '';
  List<NoticiaModel> _noticias = [];
  List<NoticiaModel> _noticiasOffline = [];
  List<CategoriaNoticiaModel> _categorias = [];

  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loadingCategorias => _loadingCategorias;
  String get errorMessage => _errorMessage;
  bool get usingCache => _usingCache;
  int get page => _page;
  bool get hasMore => _hasMore;

  /// La última página pedida por scroll falló.
  ///
  /// Lo mira el listado para dejar de pedir sola la siguiente: si no, un
  /// backend caído se convierte en un reintento por cada scroll.
  bool get loadMoreFailed => _loadMoreFailed;
  String get loadMoreError => _loadMoreError;
  List<NoticiaModel> get noticias => _noticias;
  List<NoticiaModel> get noticiasOffline => _noticiasOffline;
  Set<int> get noticiasOfflineIds => _noticiasOffline.map((e) => e.id).toSet();
  List<CategoriaNoticiaModel> get categorias => _categorias;
  Map<int, CategoriaNoticiaModel> get categoriasPorId => {
        for (final categoria in _categorias) categoria.id: categoria,
      };

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  set loadingMore(bool value) {
    _loadingMore = value;
    notifyListeners();
  }

  set loadingCategorias(bool value) {
    _loadingCategorias = value;
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

  void appendNoticias(List<NoticiaModel> value) {
    _noticias = [..._noticias, ...value];
    notifyListeners();
  }

  void setCategorias(List<CategoriaNoticiaModel> value) {
    _categorias = value;
    notifyListeners();
  }

  void setNoticiasOffline(List<NoticiaModel> value) {
    _noticiasOffline = value;
    notifyListeners();
  }

  void setPagination({required int page, required bool hasMore}) {
    _page = page;
    _hasMore = hasMore;
    notifyListeners();
  }

  void setLoadMoreFailed(bool value, {String message = ''}) {
    // Se llama al empezar cada página: sin esta salida, reconstruiría el
    // listado entero solo para reafirmar que no hay error.
    if (_loadMoreFailed == value && (!value || _loadMoreError == message)) {
      return;
    }
    _loadMoreFailed = value;
    _loadMoreError = value ? message : '';
    notifyListeners();
  }
}
