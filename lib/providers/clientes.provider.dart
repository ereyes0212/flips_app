import 'package:flutter/foundation.dart';

import '../models/models.dart';

class ClientesProvider extends ChangeNotifier {
  final List<ClienteModel> _clientes = [];

  List<ClienteModel> get clientes => List.unmodifiable(_clientes);
}
