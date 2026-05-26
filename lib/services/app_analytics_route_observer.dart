import 'package:flips_app/services/analytics.service.dart';
import 'package:flutter/widgets.dart';

class AppAnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _track(previousRoute);
    }
    super.didPop(route, previousRoute);
  }

  void _track(Route<dynamic> route) {
    final name = route.settings.name?.trim() ?? '';
    if (name.isEmpty || !name.startsWith('/')) return;
    AnalyticsService.logRouteScreen(path: name);
  }
}
