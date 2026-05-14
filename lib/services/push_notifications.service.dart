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
  if (kDebugMode) {
    debugPrint('[Push] Background message: ${message.messageId}');
  }
}

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final HttpService _httpService = HttpService();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  Future<void> init() async {
    if (_initialized || !_firebaseReady) return;

    await _initializeLocalNotifications();
    await _requestPermission();
    if (!_firebaseReady) return;
    await _syncCurrentToken();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    _messaging.onTokenRefresh.listen((token) => _syncTokenWithBackend(token));

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  Future<void> syncTokenForLoggedInUser() async {
    await _syncCurrentToken();
  }

  Future<void> unregisterTokenOnLogout() async {
    if (!_firebaseReady) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _deleteTokenFromBackend(token);
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Channel used for important notifications.',
      importance: Importance.high,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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

    if (kDebugMode) {
      debugPrint('[Push] Permission status: ${settings.authorizationStatus.name}');
    }
  }

  Future<void> _syncCurrentToken() async {
    try {
      if (!_firebaseReady) return;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('[Push] FCM token null/empty.');
        return;
      }
      await _syncTokenWithBackend(token);
    } on FirebaseException catch (error) {
      if (kDebugMode) debugPrint('[Push] Error fetching token: ${error.code}');
    }
  }

  Future<void> _syncTokenWithBackend(String token) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}mobile/push-tokens',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint('[Push] Token sync failed: ${response.statusCode}');
        }
      } else {
        if (kDebugMode) debugPrint('[Push] Token synced successfully.');
      }
    } on SocketException {
      if (kDebugMode) debugPrint('[Push] No network for token sync.');
    } catch (error) {
      if (kDebugMode) debugPrint('[Push] Token sync error: $error');
    }
  }

  Future<void> _deleteTokenFromBackend(String token) async {
    try {
      final response = await _httpService.delete(
        '${apiUrl}mobile/push-tokens',
        body: {'token': token},
      );

      if (kDebugMode) {
        debugPrint('[Push] Unregister status: ${response.statusCode}');
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[Push] Unregister error: $error');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Channel used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
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
        navigator.push(MaterialPageRoute(builder: (_) => const MisFacturasScreen()));
        break;
      case 'pago':
      case 'pagos':
        navigator.push(MaterialPageRoute(builder: (_) => const MisPagosScreen()));
        break;
      case 'suscripcion':
        navigator.push(MaterialPageRoute(builder: (_) => const MisSuscripcionScreen()));
        break;
      case 'paquete':
        navigator.push(MaterialPageRoute(builder: (_) => const PaquetesScreen()));
        break;
      default:
        navigator.push(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }
}
