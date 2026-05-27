import 'package:flips_app/services/analytics.service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppAnalyticsRouteObserver extends NavigatorObserver {
  String? _lastTrackedPath;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route, source: 'didPush');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _track(previousRoute, source: 'didPop');
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _track(newRoute, source: 'didReplace');
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _track(Route<dynamic> route, {required String source}) {
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
    AnalyticsService.logRouteScreen(path: resolvedPath);
  }

  String? _resolvePath({
    required String name,
    required Route<dynamic> route,
  }) {
    if (name.startsWith('/')) return name;

    final routeType = route.runtimeType.toString();
    if (routeType.isEmpty) return null;

    return '/screen/$routeType';
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
