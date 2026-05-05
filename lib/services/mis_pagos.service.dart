import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/mis_pagos.model.dart';
import 'package:flips_app/services/http.service.dart';

class MisPagosService {
  final HttpService _httpService = HttpService();

  Future<List<PagoModel>?> obtenerMisPagos() async {
    final response = await _httpService.get('${apiUrl}mis-pagos');

    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MisPagosResponse.fromJson(body).data;
  }
}
