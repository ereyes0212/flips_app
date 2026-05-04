import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/mis_facturas.model.dart';
import 'package:flips_app/services/http.service.dart';

class MisFacturasService {
  final HttpService _httpService = HttpService();

  Future<List<FacturaModel>?> obtenerMisFacturas() async {
    final response = await _httpService.get('${apiUrl}mis-facturas');

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MisFacturasResponse.fromJson(body).data;
  }
}
