import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';

class NewspapersProvider extends ChangeNotifier {
  final NewspapersService _service = NewspapersService();

  List<DiarioModel> _diarios = [];
  bool _loading = false;

  List<DiarioModel> get diarios => _diarios;
  bool get loading => _loading;

  Future<void> loadDiarios() async {
    _loading = true;
    notifyListeners();
    _diarios = await _service.fetchDiarios();
    _loading = false;
    notifyListeners();
  }
}
