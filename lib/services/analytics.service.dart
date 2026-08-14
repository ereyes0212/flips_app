import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Marca las rutas que ya reportan su propio `screen_view` (el detalle de una
/// nota lo manda junto con el título), para que el observer global no lo
/// duplique.
const String kRutaConAnalyticsPropio = 'analytics_propio';

class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logNoteView({
    required int noteId,
    required String slug,
    required String title,
    required List<int> categoryIds,
    String source = 'wordpress_api',
  }) async {
    final categoryPath = categoryIds.join(',');

    await _logEvent(
      name: 'select_content',
      parameters: {
        'content_type': 'article',
        'item_id': noteId.toString(),
        'item_name': _sanitize(title),
        'item_category': categoryPath,
        'source': source,
      },
    );

    await _logEvent(
      name: 'view_item',
      parameters: {
        'item_id': noteId.toString(),
        'item_name': _sanitize(title),
        'item_category': categoryPath,
        'item_variant': _sanitize(slug),
        'source': source,
        'content_type': 'article',
      },
    );
  }

  static Future<void> logNewsSearch({
    required String query,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    await _logEvent(
      name: 'search',
      parameters: {
        'search_term': _sanitize(trimmedQuery),
      },
    );
  }

  static Future<void> logCategorySearch({
    required int categoryId,
    required String categoryName,
  }) async {
    await _logEvent(
      name: 'select_content',
      parameters: {
        'content_type': 'category',
        'item_id': categoryId.toString(),
        'item_name': _sanitize(categoryName),
      },
    );
  }

  /// `path` viaja en `screen_class` a propósito: la dimensión "Ruta de página y
  /// clase de pantalla" de GA4 usa la ruta en web y la clase en app, así que es
  /// la única forma de que la misma nota sume en una sola fila desde los dos
  /// lados.
  static Future<void> logNewsScreen({
    required String path,
    required String slug,
    required String title,
  }) async {
    try {
      final screenName = _sanitize(_normalizeNewsTitle(title));
      final normalizedSlug = _sanitize(slug);
      final fallbackName = normalizedSlug.isEmpty ? 'noticia_detalle' : normalizedSlug;
      final resolvedScreenName = screenName.isEmpty ? fallbackName : screenName;
      final normalizedPath = _sanitize(path);
      await _analytics.logScreenView(
        screenName: resolvedScreenName,
        screenClass: normalizedPath.isEmpty ? 'NoticiaDetalleScreen' : normalizedPath,
      );

    } catch (error) {
      if (kDebugMode) {
        debugPrint('No se pudo registrar screen_view de noticia: $error');
      }
    }

  }



  /// Igual que [logNewsScreen]: la ruta va en `screen_class` para que la
  /// pantalla sume con su equivalente del sitio. `title` es el `page_title` que
  /// manda la web para esa misma ruta, cuando lo conocemos.
  static Future<bool> logRouteScreen({
    required String path,
    String? title,
  }) async {
    final normalizedPath = _sanitize(path);
    if (normalizedPath.isEmpty) return false;

    final normalizedTitle = _sanitize(title ?? '');
    final screenName = normalizedTitle.isEmpty ? normalizedPath : normalizedTitle;

    if (kDebugMode) {
      debugPrint('[AnalyticsService][send] screen_view path=$normalizedPath name=$screenName');
    }

    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: normalizedPath,
      );

      if (kDebugMode) {
        debugPrint('[AnalyticsService][ok] screen_view path=$normalizedPath');
      }
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AnalyticsService][error] screen_view/page_view path=$normalizedPath error=$error');
      }
      return false;
    }
  }

  static Future<void> logNoteShare({
    required int noteId,
    required String slug,
    required String title,
    String method = 'system_share_sheet',
  }) async {
    await _logEvent(
      name: 'share',
      parameters: {
        'content_type': 'article',
        'item_id': noteId.toString(),
        'item_name': _sanitize(title),
        'item_variant': _sanitize(slug),
        'method': _sanitize(method),
      },
    );
  }

  static Future<void> _logEvent({
    required String name,
    required Map<String, Object?> parameters,
  }) async {
    try {
      final normalized = <String, Object>{};
      parameters.forEach((key, value) {
        if (value == null) return;
        if (value is String) {
          final sanitized = _sanitize(value);
          if (sanitized.isEmpty) return;
          normalized[key] = sanitized;
          return;
        }
        normalized[key] = value;
      });
      await _analytics.logEvent(name: name, parameters: normalized);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('No se pudo registrar evento de analytics ($name): $error');
      }
    }
  }


  static String _normalizeNewsTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    const suffixes = [
      ' l Diario Tiempo de Honduras',
      ' | Diario Tiempo de Honduras',
    ];

    for (final suffix in suffixes) {
      if (trimmed.endsWith(suffix)) {
        return trimmed.substring(0, trimmed.length - suffix.length).trim();
      }
    }

    return trimmed;
  }

  static String _sanitize(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= 100) return cleaned;
    return cleaned.substring(0, 100);
  }
}
