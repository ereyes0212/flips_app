import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter/foundation.dart';
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
    this.total = 0,
    this.hasMore = false,
  });

  final List<NoticiaModel> items;
  final String errorMessage;
  final bool fromCache;
  final int currentPage;
  final int totalPages;
  final int total;
  final bool hasMore;

  bool get success => errorMessage.isEmpty;
}

class CategoriasNoticiasResult {
  const CategoriasNoticiasResult({required this.items, this.errorMessage = ''});

  final List<CategoriaNoticiaModel> items;
  final String errorMessage;

  bool get success => errorMessage.isEmpty;
}

class _Paginacion {
  const _Paginacion({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.hasMore,
  });

  final int page;
  final int totalPages;
  final int total;
  final bool hasMore;
}

class NoticiasService {
  // El caché sigue en v1: `NoticiaModel.fromJson` lee tanto el formato nuevo
  // como el anterior, así que no hay que descartar lo ya guardado.
  static const _cacheKey = 'noticias_cache_v1';
  static const _cacheAtKey = 'noticias_cache_at_v1';
  static const _offlineNewsKey = 'offline_news_v1';

  /// Límites que valida la API.
  static const _maxPage = 100;
  static const _maxPerPage = 50;
  static const _maxCategorias = 10;
  static const _minBusqueda = 3;
  static const _maxBusqueda = 100;

  final HttpService _httpService = HttpService(
    timeout: const Duration(seconds: 12),
  );

  String get _baseUrl => '${apiUrl}noticias';

  /// Listado de tarjetas: solo trae los datos necesarios para el home,
  /// la categoría o la búsqueda (sin el contenido de la nota).
  Future<NoticiasResult> obtenerNoticias({
    int page = 1,
    int perPage = 10,
    int? categoria,
    List<int>? categorias,
    String? busqueda,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final paginaSolicitada = page.clamp(1, _maxPage);
    final porPagina = perPage.clamp(1, _maxPerPage);
    final query = <String, String>{
      'page': '$paginaSolicitada',
      'perPage': '$porPagina',
    };

    final idsCategorias = <int>{
      if (categoria != null) categoria,
      ...?categorias,
    }.where((id) => id > 0).take(_maxCategorias).toList();
    if (idsCategorias.isNotEmpty) {
      query['categoria'] = idsCategorias.join(',');
    }

    final texto = _busquedaValida(busqueda);
    if (texto.isNotEmpty) query['busqueda'] = texto;

    final desde = fechaDesde;
    final hasta = fechaHasta;
    if (desde != null) query['fechaDesde'] = _fechaIso(desde);
    if (hasta != null && (desde == null || !hasta.isBefore(desde))) {
      query['fechaHasta'] = _fechaIso(hasta);
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: query);

    try {
      final response = await _httpService.get(uri.toString());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final rawItems = _extraerLista(body);
        final parsed = rawItems
            .map((e) => NoticiaModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _avisarSiNoSeLeyoLaTarjeta(rawItems, parsed);

        final paginacion = _paginacion(
          body,
          page: paginaSolicitada,
          perPage: porPagina,
          itemCount: rawItems.length,
        );

        final sinFiltros = idsCategorias.isEmpty &&
            texto.isEmpty &&
            desde == null &&
            hasta == null;
        if (paginaSolicitada == 1 && sinFiltros) {
          await _guardarCache(jsonEncode(rawItems));
        }

        return NoticiasResult(
          items: parsed,
          currentPage: paginacion.page,
          totalPages: paginacion.totalPages,
          total: paginacion.total,
          hasMore: paginacion.hasMore,
        );
      }

      if (kDebugMode) {
        debugPrint(
          '[noticias] ${response.statusCode} en $uri -> ${response.body}',
        );
      }
      // 400: algún filtro llegó fuera de rango (la API no los silencia).
      return await _desdeCache(
        response.statusCode == 400
            ? 'Los filtros de búsqueda no son válidos. '
                'Mostrando la última versión guardada.'
            : 'No pudimos actualizar las noticias (error ${response.statusCode}). '
                'Mostrando la última versión guardada.',
      );
    } on SocketException {
      return await _desdeCache('Sin conexión a internet. Mostrando noticias guardadas.');
    } on TimeoutException {
      return await _desdeCache(
        'La conexión tardó demasiado. Mostrando noticias guardadas.',
      );
    } on SessionExpiredException {
      return await _desdeCache(
        'Tu sesión expiró. Inicia sesión nuevamente para ver las noticias.',
      );
    } catch (_) {
      return await _desdeCache(
        'No pudimos actualizar las noticias. '
        'Mostrando la última versión guardada.',
      );
    }
  }

  /// Nota completa (incluye `contenido` en HTML). Acepta un link completo o un
  /// slug; devuelve `null` si la API responde 404.
  Future<NoticiaModel?> obtenerNoticiaPorLink(String link) async {
    final normalizado = link.trim();
    if (normalizado.isEmpty) return null;

    final parsed = Uri.tryParse(normalizado);
    final esUrlCompleta =
        parsed != null && parsed.hasScheme && parsed.host.isNotEmpty;
    if (esUrlCompleta) {
      return _obtenerNota(<String, String>{'link': normalizado});
    }

    return obtenerNoticiaPorSlug(_slugFromLink(normalizado));
  }

  /// La API valida el slug (alfanumérico, `-`, `_`, máx. 200) y responde 400 si
  /// no cumple, así que se filtra antes de llamar.
  Future<NoticiaModel?> obtenerNoticiaPorSlug(String slug) async {
    final normalizado = slug.trim();
    if (!_slugValido(normalizado)) return null;
    return _obtenerNota(<String, String>{'slug': normalizado});
  }

  bool _slugValido(String slug) {
    return slug.isNotEmpty &&
        slug.length <= 200 &&
        RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(slug);
  }

  /// Descarga el contenido de una tarjeta del listado y lo fusiona con los
  /// datos que ya se tenían (imagen local, etc.).
  Future<NoticiaModel?> obtenerNoticiaCompleta(NoticiaModel noticia) async {
    if (noticia.tieneContenido) return noticia;

    final porSlug = await obtenerNoticiaPorSlug(noticia.slug);
    final detalle = porSlug ?? await obtenerNoticiaPorLink(noticia.link);
    if (detalle == null) return null;

    return noticia.mergeDetalle(detalle);
  }

  Future<NoticiaModel?> _obtenerNota(Map<String, String> query) async {
    final uri = Uri.parse('$_baseUrl/by-link').replace(queryParameters: query);

    try {
      final response = await _httpService.get(uri.toString());
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            '[noticias] ${response.statusCode} en $uri -> ${response.body}',
          );
        }
        return null;
      }

      final body = jsonDecode(response.body);
      final nota = _extraerNota(body);
      if (nota == null) return null;

      final parsed = NoticiaModel.fromJson(nota);
      if (kDebugMode && !parsed.tieneContenido) {
        debugPrint(
          '[noticias] La nota llegó sin contenido. '
          'Claves recibidas: ${nota.keys.join(', ')}',
        );
      }
      return parsed.id > 0 || parsed.slug.isNotEmpty ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  /// La API de categorías es un passthrough de WordPress: array plano.
  Future<CategoriasNoticiasResult> obtenerCategorias({
    int page = 1,
    int perPage = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/categorias').replace(
      queryParameters: <String, String>{
        'page': '${page.clamp(1, _maxPage)}',
        'perPage': '${perPage.clamp(1, 100)}',
      },
    );
    try {
      final response = await _httpService.get(uri.toString());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final parsed = _extraerLista(body)
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

  List<dynamic> _extraerLista(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      for (final key in const ['data', 'items', 'noticias', 'results']) {
        final value = body[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  /// Si la API cambia los nombres de los campos, en debug se imprime la primera
  /// nota tal cual llegó para no tener que adivinar el formato.
  void _avisarSiNoSeLeyoLaTarjeta(
    List<dynamic> rawItems,
    List<NoticiaModel> parsed,
  ) {
    if (!kDebugMode || rawItems.isEmpty || parsed.isEmpty) return;
    final primera = parsed.first;
    if (primera.title.isNotEmpty && primera.date != null) return;

    final raw = rawItems.first;
    debugPrint(
      '[noticias] No se pudieron leer título/fecha. '
      'Claves recibidas: ${raw is Map ? raw.keys.join(', ') : raw.runtimeType}',
    );
    debugPrint('[noticias] Primer elemento: ${jsonEncode(raw)}');
  }

  Map<String, dynamic>? _extraerNota(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body.isEmpty ? null : body;
    }

    final items = _extraerLista(body);
    if (items.isEmpty) return null;
    final first = items.first;
    return first is Map<String, dynamic> ? first : null;
  }

  _Paginacion _paginacion(
    dynamic body, {
    required int page,
    required int perPage,
    required int itemCount,
  }) {
    final meta = body is Map<String, dynamic> && body['paginacion'] is Map
        ? (body['paginacion'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final paginaActual = int.tryParse(meta['page']?.toString() ?? '') ?? page;
    final total = int.tryParse(meta['total']?.toString() ?? '') ?? 0;
    final totalPages =
        int.tryParse(meta['totalPages']?.toString() ?? '') ??
            // Sin metadatos: si la página vino llena asumimos que hay más.
            (itemCount >= perPage ? paginaActual + 1 : paginaActual);
    final hasMore = meta['hasMore'] is bool
        ? meta['hasMore'] as bool
        : paginaActual < totalPages;

    return _Paginacion(
      page: paginaActual,
      totalPages: totalPages,
      total: total,
      hasMore: hasMore,
    );
  }

  /// La API exige entre 3 y 100 caracteres; fuera de ese rango se omite.
  String _busquedaValida(String? busqueda) {
    final texto = busqueda?.trim() ?? '';
    if (texto.length < _minBusqueda) return '';
    return texto.length > _maxBusqueda ? texto.substring(0, _maxBusqueda) : texto;
  }

  String _fechaIso(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year.toString().padLeft(4, '0')}-$mes-$dia';
  }

  Future<NoticiasResult> _desdeCache(String fallbackError) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString(_cacheKey);
    if (cache == null || cache.isEmpty) {
      return NoticiasResult(items: const [], errorMessage: fallbackError);
    }

    try {
      final parsed = _extraerLista(jsonDecode(cache))
          .map((e) => NoticiaModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return NoticiasResult(
        items: parsed,
        errorMessage: fallbackError,
        fromCache: true,
      );
    } catch (_) {
      return NoticiasResult(items: const [], errorMessage: fallbackError);
    }
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
    byId[noticia.id] = noticia.copyWith(
      contentBlocks: offlineBlocks,
      localImagePath: localImagePath,
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
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
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
