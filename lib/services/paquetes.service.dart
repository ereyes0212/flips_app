import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/paquetes.model.dart';
import 'package:flips_app/services/http.service.dart';

class PaquetesService {
  final HttpService _httpService = HttpService();

  Future<List<PaqueteModel>?> obtenerPaquetes() async {
    final response = await _httpService.get('${apiUrl}paquetes');

    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PaquetesResponse.fromJson(body).data;
  }
}
