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
