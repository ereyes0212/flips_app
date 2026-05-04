import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/services/http.service.dart';

class DiariosDigitalesService {
  final HttpService _httpService = HttpService();

  Future<List<DiarioDigitalModel>?> obtenerDiariosDigitales() async {
    final response = await _httpService.get('${apiUrl}mis-notas');

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiariosDigitalesResponse.fromJson(body).data;
  }
}
