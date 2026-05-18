import 'dart:convert';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/mis_facturas/mis_facturas.screen.dart';
import 'package:flips_app/screens/mis_pagos/mis_pagos.screen.dart';
import 'package:flips_app/screens/mis_suscripcion/mis_suscripcion.screen.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationItem {
  PushNotificationItem({
    this.title,
    this.body,
    this.data,
    required this.receivedAt,
  });

  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final DateTime receivedAt;
}

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final HttpService _httpService = HttpService();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<PushNotificationItem> _notifications = [];

  bool _initialized = false;
  bool _notificationsPermissionShown = false;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  Future<void> init() async {
    if (_initialized || !_firebaseReady) return;

    await _initializeLocalNotifications();
    // No solicitar ni sincronizar token automáticamente al iniciar la app.
    // El token se registra después de login y permiso explícito del usuario.
    if (!_firebaseReady) return;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    _messaging.onTokenRefresh.listen((token) async {
      await _syncTokenWithBackend(token);
      await _subscribeToFlipsTopic();
    });

    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _subscribeToFlipsTopic();
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _addNotification(initialMessage);
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  Future<void> syncTokenForLoggedInUser() async {
    await _syncCurrentToken();
  }

  /// Solicita permiso de notificaciones al usuario
  /// Retorna true si el permiso fue otorgado
  Future<bool> requestNotificationPermission() async {
    if (!_firebaseReady) return false;

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final isGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized;

    if (isGranted) {
      await _syncCurrentToken();
      await _subscribeToFlipsTopic();
    }

    return isGranted;
  }

  Future<void> _subscribeToFlipsTopic() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('flips');
    } catch (error) {}
  }

  List<PushNotificationItem> get notifications =>
      List.unmodifiable(_notifications);

  /// Retorna true si el permiso de notificaciones ya está habilitado
  Future<bool> isNotificationPermissionGranted() async {
    if (!_firebaseReady) return false;
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<bool> hasNotificationPermissionBeenShown() async {
    return _notificationsPermissionShown;
  }

  void setNotificationPermissionShown() {
    _notificationsPermissionShown = true;
  }

  Future<void> unregisterTokenOnLogout() async {
    if (!_firebaseReady) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _deleteTokenFromBackend(token);
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _navigateFromPayload(data);
        } catch (_) {}
      },
    );

    const channel = AndroidNotificationChannel(
      'new_flips',
      'Flips Notifications',
      description: 'Channel used for Flips push notifications.',
      importance: Importance.high,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _syncCurrentToken() async {
    try {
      if (!_firebaseReady) return;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _syncTokenWithBackend(token);
    } on FirebaseException catch (error) {}
  }

  Future<void> _syncTokenWithBackend(String token) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}mobile/push/register-token',
        body: {
          'token': token,
          'plataforma': Platform.isIOS ? 'ios' : 'android',
          'activo': true,
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
      } else {}
    } on SocketException {
    } catch (error) {}
  }

  Future<void> _deleteTokenFromBackend(String token) async {
    try {
      final response = await _httpService.delete(
        '${apiUrl}mobile/push-tokens',
        body: {'token': token},
      );
    } catch (error) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    _addNotification(message);
    final notification = message.notification;
    if (notification == null) return;

    await _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_flips',
          'Flips Notifications',
          channelDescription: 'Channel used for Flips push notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _addNotification(RemoteMessage message) {
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Notificación';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'Toque para ver detalles.';

    _notifications.insert(
      0,
      PushNotificationItem(
        title: title,
        body: body,
        data: message.data,
        receivedAt: DateTime.now().toUtc(),
      ),
    );

    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateFromPayload(message.data);
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (type) {
      case 'factura':
      case 'facturas':
        navigator.push(
          MaterialPageRoute(builder: (_) => const MisFacturasScreen()),
        );
        break;
      case 'pago':
      case 'pagos':
        navigator.push(
          MaterialPageRoute(builder: (_) => const MisPagosScreen()),
        );
        break;
      case 'suscripcion':
        navigator.push(
          MaterialPageRoute(builder: (_) => const MisSuscripcionScreen()),
        );
        break;
      case 'paquete':
        navigator.push(
          MaterialPageRoute(builder: (_) => const PaquetesScreen()),
        );
        break;
      default:
        navigator.push(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }
}
