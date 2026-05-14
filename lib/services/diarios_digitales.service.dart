import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/services/http.service.dart';

enum DiariosDigitalesStatus { ok, forbidden, error }

class DiariosDigitalesResult {
  const DiariosDigitalesResult({required this.status, this.diarios = const []});

  final DiariosDigitalesStatus status;
  final List<DiarioDigitalModel> diarios;
}

class DiariosDigitalesService {
  final HttpService _httpService = HttpService();

  Future<DiariosDigitalesResult> obtenerDiariosDigitales({
    required int anio,
    required int mes,
  }) async {
    final uri = Uri.parse('${apiUrl}mis-notas').replace(
      queryParameters: {
        'anio': anio.toString(),
        'mes': mes.toString(),
      },
    );
    final response = await _httpService.get(uri.toString());

    if (response.statusCode == 403) {
      return const DiariosDigitalesResult(status: DiariosDigitalesStatus.forbidden);
    }

    if (response.statusCode != 200) {
      return const DiariosDigitalesResult(status: DiariosDigitalesStatus.error);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiariosDigitalesResult(
      status: DiariosDigitalesStatus.ok,
      diarios: DiariosDigitalesResponse.fromJson(body).data,
    );
  }
}
