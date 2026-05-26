import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

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
        'event_category': categoryPath,
        'event_label': _sanitize(slug),
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
        'event_category': 'news_search',
        'event_label': _sanitize(trimmedQuery),
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
        'event_category': 'category_search',
        'event_label': _sanitize(categoryName),
      },
    );
  }

  static Future<void> logNewsScreen({
    required String slug,
    required String title,
    required List<int> categoryIds,
  }) async {
    try {
      final normalizedSlug = _sanitize(slug);
      final fallbackTitle = _sanitize(title);
      final screenName = normalizedSlug.isEmpty ? fallbackTitle : normalizedSlug;
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: 'NoticiaDetalleScreen',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('No se pudo registrar screen_view de noticia: $error');
      }
    }

    await _logEvent(
      name: 'news_screen_view',
      parameters: {
        'event_category': categoryIds.join(','),
        'event_label': _sanitize(slug),
      },
    );
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

  static String _sanitize(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= 100) return cleaned;
    return cleaned.substring(0, 100);
  }
}
