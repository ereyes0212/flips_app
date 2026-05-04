import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/mi_perfil.model.dart';
import 'package:flips_app/services/http.service.dart';

class MiPerfilService {
  final HttpService _httpService = HttpService();

  Future<MiPerfilModel?> obtenerMiPerfil() async {
    final response = await _httpService.get('${apiUrl}mi-perfil');

    print(response.headers);
    print(response.statusCode);
    print(response.body);
    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    print(body);
    if (body['data'] == null) {
      return null;
    }

    return MiPerfilModel.fromJson(body['data']);
  }
}
