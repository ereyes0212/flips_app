import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/mis_suscripcion.model.dart';
import 'package:flips_app/services/http.service.dart';

class MisSuscripcionService {
  final HttpService _httpService = HttpService();

  Future<List<SuscripcionModel>?> obtenerMisSuscripciones() async {
    final response = await _httpService.get('${apiUrl}mis-suscripcion');

    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MisSuscripcionesResponse.fromJson(body).data;
  }
}
