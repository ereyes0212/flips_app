import 'dart:convert';
import 'dart:io';

import 'package:flips_app/models/noticias.model.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoticiasResult {
  const NoticiasResult({
    required this.items,
    this.errorMessage = '',
    this.fromCache = false,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  final List<NoticiaModel> items;
  final String errorMessage;
  final bool fromCache;
  final int currentPage;
  final int totalPages;

  bool get success => errorMessage.isEmpty;
  bool get hasMore => currentPage < totalPages;
}

class CategoriasNoticiasResult {
  const CategoriasNoticiasResult({required this.items, this.errorMessage = ''});

  final List<CategoriaNoticiaModel> items;
  final String errorMessage;

  bool get success => errorMessage.isEmpty;
}

class NoticiasService {
  static const _baseUrl = 'https://tiempo.hn/wp-json/wp/v2';
  static const _cacheKey = 'noticias_cache_v1';
  static const _cacheAtKey = 'noticias_cache_at_v1';
  static const _offlineNewsKey = 'offline_news_v1';
  static const _postFields =
      'id,date,slug,link,title,excerpt,content,categories,yoast_head_json,_embedded.wp:featuredmedia.source_url,_embedded.wp:featuredmedia.alt_text';
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
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      '_embed': '1',
      '_fields': _postFields,
    };
    if (categoria != null) query['categories'] = '$categoria';
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      query['search'] = busqueda.trim();
    }
    if (fechaDesde != null) {
      query['after'] = fechaDesde.toUtc().toIso8601String();
    }
    if (fechaHasta != null) {
      query['before'] = fechaHasta.toUtc().toIso8601String();
    }

    final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: query);

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as List<dynamic>;
        final parsed = body
            .map((e) => NoticiaModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final totalPages = int.tryParse(
              response.headers['x-wp-totalpages'] ?? '',
            ) ??
            page;

        if (page == 1 &&
            categoria == null &&
            (busqueda == null || busqueda.isEmpty)) {
          await _guardarCache(response.body);
        }

        return NoticiasResult(
          items: parsed,
          currentPage: page,
          totalPages: totalPages,
        );
      }

      return await _desdeCache(
        'Error ${response.statusCode} al cargar noticias.',
      );
    } catch (_) {
      return await _desdeCache('Sin conexión y sin datos en caché.');
    }
  }

  Future<NoticiaModel?> obtenerNoticiaPorLink(String link) async {
    final slug = _slugFromLink(link);
    if (slug.isEmpty) return null;

    final query = <String, String>{
      'slug': slug,
      'per_page': '1',
      '_embed': '1',
      '_fields': _postFields,
    };
    final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: query);

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as List<dynamic>;
      if (body.isEmpty) return null;

      return NoticiaModel.fromJson(body.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<CategoriasNoticiasResult> obtenerCategorias({int perPage = 100}) async {
    final query = <String, String>{
      'per_page': '$perPage',
      'orderby': 'count',
      'order': 'desc',
      'hide_empty': 'true',
      '_fields': 'id,name,slug,count',
    };
    final uri = Uri.parse('$_baseUrl/categories').replace(
      queryParameters: query,
    );

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as List<dynamic>;
        final parsed = body
            .map((e) => CategoriaNoticiaModel.fromJson(e as Map<String, dynamic>))
            .where((e) => e.id > 0)
            .toList();
        return CategoriasNoticiasResult(items: parsed);
      }

      return CategoriasNoticiasResult(
        items: const [],
        errorMessage: 'Error ${response.statusCode} al cargar categorías.',
      );
    } catch (_) {
      return const CategoriasNoticiasResult(
        items: [],
        errorMessage: 'Sin conexión para cargar categorías.',
      );
    }
  }

  String _slugFromLink(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return '';

    final segments = uri.pathSegments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return '';

    return segments.last;
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
    return NoticiasResult(
      items: parsed,
      errorMessage: fallbackError,
      fromCache: true,
    );
  }

  Future<void> _guardarCache(String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, body);
    await prefs.setString(_cacheAtKey, DateTime.now().toIso8601String());
  }

  Future<void> guardarNoticiaOffline(NoticiaModel noticia) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await obtenerNoticiasOffline();
    final byId = <int, NoticiaModel>{for (final item in saved) item.id: item};
    final localImagePath = await _guardarImagenLocal(
      noticia.id,
      noticia.imageUrl,
    );
    final offlineBlocks = await _guardarContenidoMultimediaLocal(
      noticia.id,
      noticia.contentBlocks,
    );
    byId[noticia.id] = NoticiaModel(
      id: noticia.id,
      link: noticia.link,
      slug: noticia.slug,
      date: noticia.date,
      title: noticia.title,
      excerpt: noticia.excerpt,
      content: noticia.content,
      contentBlocks: offlineBlocks,
      imageUrl: noticia.imageUrl,
      imageAlt: noticia.imageAlt,
      localImagePath: localImagePath,
      categories: noticia.categories,
    );
    final encoded = jsonEncode(
      byId.values.map((item) => item.toStorageJson()).toList(),
    );
    await prefs.setString(_offlineNewsKey, encoded);
  }

  Future<List<NoticiaModel>> obtenerNoticiasOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineNewsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final body = jsonDecode(raw) as List<dynamic>;
      return body
          .map((e) => NoticiaModel.fromStorageJson(e as Map<String, dynamic>))
          .where((item) => item.id > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> eliminarNoticiaOffline(int noticiaId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await obtenerNoticiasOffline();
    final filtered = saved.where((item) => item.id != noticiaId).toList();

    final removed = saved.where((item) => item.id == noticiaId).toList();
    for (final item in removed) {
      await _eliminarArchivoSiExiste(item.localImagePath);
      for (final block in item.contentBlocks) {
        if (block.isImage) {
          await _eliminarArchivoSiExiste(block.imageUrl);
        } else if (block.isGallery) {
          for (final galleryItem in block.galleryItems) {
            await _eliminarArchivoSiExiste(galleryItem.imageUrl);
          }
        }
      }
    }

    final encoded = jsonEncode(
      filtered.map((item) => item.toStorageJson()).toList(),
    );
    await prefs.setString(_offlineNewsKey, encoded);
  }

  Future<String> _guardarImagenLocal(int noticiaId, String imageUrl) async {
    if (imageUrl.trim().isEmpty) return '';
    try {
      final uri = Uri.tryParse(imageUrl.trim());
      if (uri == null) return '';
      final response = await http.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return '';
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/offline_news_image_$noticiaId.jpg');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return '';
    }
  }

  Future<void> _eliminarArchivoSiExiste(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    if (!normalized.startsWith('/') && !normalized.startsWith('file://')) return;
    try {
      final filePath =
          normalized.startsWith('file://')
              ? Uri.parse(normalized).toFilePath()
              : normalized;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<List<NoticiaContentBlock>> _guardarContenidoMultimediaLocal(
    int noticiaId,
    List<NoticiaContentBlock> blocks,
  ) async {
    final result = <NoticiaContentBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isImage) {
        final local = await _guardarImagenLocal(
          noticiaId * 1000 + i,
          block.imageUrl,
        );
        result.add(
          NoticiaContentBlock.image(
            url: local.isNotEmpty ? local : block.imageUrl,
            caption: block.caption,
          ),
        );
        continue;
      }
      if (block.isGallery) {
        final items = <NoticiaGalleryItem>[];
        for (var gi = 0; gi < block.galleryItems.length; gi++) {
          final item = block.galleryItems[gi];
          final local = await _guardarImagenLocal(
            noticiaId * 100000 + (i * 100) + gi,
            item.imageUrl,
          );
          items.add(
            NoticiaGalleryItem(
              imageUrl: local.isNotEmpty ? local : item.imageUrl,
              caption: item.caption,
            ),
          );
        }
        result.add(NoticiaContentBlock.gallery(items));
        continue;
      }
      result.add(block);
    }
    return result;
  }
}
