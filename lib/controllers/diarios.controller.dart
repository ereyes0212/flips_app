import '../providers/providers.dart';

class DiariosController {
  const DiariosController(this._provider);

  final NewspapersProvider _provider;

  Future<void> cargarDiarios() => _provider.loadDiarios();
}
