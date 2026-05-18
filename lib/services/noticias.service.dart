import 'dart:convert';

import 'package:flips_app/models/noticias.model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NoticiasResult {
  const NoticiasResult({
    required this.items,
    this.errorMessage = '',
    this.fromCache = false,
  });

  final List<NoticiaModel> items;
  final String errorMessage;
  final bool fromCache;

  bool get success => errorMessage.isEmpty;
}

class NoticiasService {
  static const _baseUrl = 'https://tiempo.hn/wp-json/wp/v2';
  static const _cacheKey = 'noticias_cache_v1';
  static const _cacheAtKey = 'noticias_cache_at_v1';
  static const _wordpressUsername = String.fromEnvironment(
    'WP_USER',
  );
  static const _wordpressApplicationPassword = String.fromEnvironment(
    'WP_PASS',
  );

  Future<NoticiasResult> obtenerNoticias({
    int page = 1,
    int perPage = 10,
    int? categoria,
    String? busqueda,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      '_embed': '1',
      '_fields': 'id,date,slug,link,title,excerpt,content,categories,_embedded.wp:featuredmedia.source_url,_embedded.wp:featuredmedia.alt_text',
    };
    if (categoria != null) query['categories'] = '$categoria';
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      query['search'] = busqueda.trim();
    }

    final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: query);

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as List<dynamic>;
        final parsed = body
            .map((e) => NoticiaModel.fromJson(e as Map<String, dynamic>))
            .toList();

        if (page == 1 &&
            categoria == null &&
            (busqueda == null || busqueda.isEmpty)) {
          await _guardarCache(response.body);
        }

        return NoticiasResult(items: parsed);
      }

      return await _desdeCache(
        'Error ${response.statusCode} al cargar noticias.',
      );
    } catch (_) {
      return await _desdeCache('Sin conexión y sin datos en caché.');
    }
  }

  Map<String, String> get _headers {
    if (_wordpressUsername.isEmpty || _wordpressApplicationPassword.isEmpty) {
      return const {};
    }

    final credentials = base64Encode(
      utf8.encode('$_wordpressUsername:$_wordpressApplicationPassword'),
    );
    return {'Authorization': 'Basic $credentials'};
  }

  Future<NoticiasResult> _desdeCache(String fallbackError) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString(_cacheKey);
    if (cache == null || cache.isEmpty) {
      return NoticiasResult(items: const [], errorMessage: fallbackError);
    }

    final body = jsonDecode(cache) as List<dynamic>;
    final parsed = body
        .map((e) => NoticiaModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return NoticiasResult(items: parsed, fromCache: true);
  }

  Future<void> _guardarCache(String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, body);
    await prefs.setString(_cacheAtKey, DateTime.now().toIso8601String());
  }
}
