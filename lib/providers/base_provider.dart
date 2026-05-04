import 'package:flutter/foundation.dart';

class BaseProvider extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  String? get error => _error;
  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
  void setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
