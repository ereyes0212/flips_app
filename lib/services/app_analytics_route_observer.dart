import 'dart:async';

import 'package:flips_app/services/analytics.service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppAnalyticsRouteObserver extends NavigatorObserver {
  String? _lastTrackedPath;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    unawaited(_track(route, source: 'didPush'));
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      unawaited(_track(previousRoute, source: 'didPop'));
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      unawaited(_track(newRoute, source: 'didReplace'));
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  Future<void> _track(Route<dynamic> route, {required String source}) async {
    if (route.settings.arguments == kRutaConAnalyticsPropio) {
      _debugLog('skip', source: source, route: route, message: 'La pantalla manda su propio screen_view');
      return;
    }

    final name = route.settings.name?.trim() ?? '';
    final resolvedPath = _resolvePath(name: name, route: route);

    if (resolvedPath == null) {
      _debugLog('skip', source: source, route: route, message: 'Sin path resolvible');
      return;
    }

    if (resolvedPath == _lastTrackedPath) {
      _debugLog('skip', source: source, route: route, path: resolvedPath, message: 'Path duplicado');
      return;
    }

    _lastTrackedPath = resolvedPath;
    _debugLog('send', source: source, route: route, path: resolvedPath);
    final sent = await AnalyticsService.logRouteScreen(
      path: resolvedPath,
      title: _resolveTitle(resolvedPath),
    );
    if (sent) {
      _debugLog('ok', source: source, route: route, path: resolvedPath, message: 'Analytics completado');
      return;
    }

    _debugLog('error', source: source, route: route, path: resolvedPath, message: 'Fallo al enviar analytics');
  }


  /// El `<title>` que manda el sitio para la portada, para que el home de la app
  /// caiga en la misma fila que la web.
  static const _tituloPortada =
      'Noticias de Honduras y el mundo l Diario Tiempo de Honduras';

  String? _resolveTitle(String path) => path == '/' ? _tituloPortada : null;

  String? _resolvePath({
    required String name,
    required Route<dynamic> route,
  }) {
    if (name.startsWith('/')) return name;

    return null;
  }

  void _debugLog(
    String action, {
    required String source,
    required Route<dynamic> route,
    String? path,
    String? message,
  }) {
    if (!kDebugMode) return;

    final routeName = route.settings.name ?? '(sin nombre)';
    final routeType = route.runtimeType.toString();
    debugPrint(
      '[AnalyticsRouteObserver][$action] source=$source routeName=$routeName routeType=$routeType path=${path ?? '-'} ${message ?? ''}',
    );
  }
}
