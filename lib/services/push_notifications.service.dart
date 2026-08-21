// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/screens/mis_facturas/mis_facturas.screen.dart';
import 'package:flips_app/screens/mis_pagos/mis_pagos.screen.dart';
import 'package:flips_app/screens/mis_suscripcion/mis_suscripcion.screen.dart';
import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flips_app/utils/noticia_link.util.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kStorageKey = 'push_notifications_history';
const String _kNewsAlertsKey = 'push_news_alerts_enabled';
const String _kPendingAlertsSyncKey = 'push_alerts_pending_sync';
const int _kMaxStoredNotifications = 100;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Con la app cerrada o en segundo plano este es el único punto donde el
  // aviso pasa por nuestro código: si no lo guardamos aquí, nunca aparece en
  // la pantalla de Notificaciones.
  await _persistMessageToStorage(message);
}

/// El emisor no siempre usa las mismas llaves: las campañas arman el `data`
/// a partir del objeto de la nota, que trae los nombres en español.
const List<String> _kClavesTitulo = ['title', 'titulo', 'headline', 'subject'];
const List<String> _kClavesCuerpo = [
  'body',
  'cuerpo',
  'mensaje',
  'message',
  'resumen',
  'descripcion',
  'descripción',
  'subtitle',
];

String? _primerTextoNoVacio(Map<String, dynamic> data, List<String> claves) {
  for (final clave in claves) {
    final valor = data[clave]?.toString().trim();
    if (valor != null && valor.isNotEmpty) return valor;
  }
  return null;
}

/// Texto del aviso, venga en el bloque `notification` o suelto en `data`.
///
/// Se descarta el vacío además del nulo: un `notification` con el título en
/// blanco dejaba la tarjeta sin encabezado en vez de caer al respaldo.
String? _tituloDeMensaje(RemoteMessage message) {
  final delBloque = message.notification?.title?.trim();
  if (delBloque != null && delBloque.isNotEmpty) return delBloque;
  return _primerTextoNoVacio(message.data, _kClavesTitulo);
}

String? _cuerpoDeMensaje(RemoteMessage message) {
  final delBloque = message.notification?.body?.trim();
  if (delBloque != null && delBloque.isNotEmpty) return delBloque;
  return _primerTextoNoVacio(message.data, _kClavesCuerpo);
}

/// Imagen del aviso, venga en el bloque `notification` o suelta en `data`.
String? _imagenDeMensaje(RemoteMessage message) {
  final deAndroid = message.notification?.android?.imageUrl?.trim();
  if (deAndroid != null && deAndroid.isNotEmpty) return deAndroid;

  final deApple = message.notification?.apple?.imageUrl?.trim();
  if (deApple != null && deApple.isNotEmpty) return deApple;

  final deData = message.data['imageUrl']?.toString().trim();
  return (deData != null && deData.isNotEmpty) ? deData : null;
}

/// Baja la foto a un archivo temporal para poder mostrarla dentro del aviso.
///
/// Android no acepta una URL: exige un bitmap local. Si falla o tarda se
/// devuelve `null` y el aviso sale sin foto, nunca sin aviso.
Future<String?> _descargarImagenDeAviso(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;

    final respuesta = await http
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (respuesta.statusCode != 200) return null;

    final carpeta = await Directory.systemTemp.createTemp('push_img');
    final archivo = File('${carpeta.path}/portada.jpg');
    await archivo.writeAsBytes(respuesta.bodyBytes);
    return archivo.path;
  } catch (_) {
    return null;
  }
}

/// `false` para los mensajes de control (pings de sincronización, silenciosos
/// de iOS con `content-available`): no traen nada que leer, y guardarlos era lo
/// que llenaba el historial de tarjetas en blanco.
bool _mensajeTieneContenido(RemoteMessage message) =>
    _tituloDeMensaje(message) != null || _cuerpoDeMensaje(message) != null;

/// Id del aviso local: derivarlo del `messageId` evita que un reintento del
/// mismo mensaje apile dos avisos en la bandeja.
int _idDeAvisoLocal(RemoteMessage message) =>
    (message.messageId ?? message.hashCode.toString()).hashCode;

PushNotificationItem _itemFromMessage(RemoteMessage message) {
  return PushNotificationItem(
    id:
        message.messageId ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    title: _tituloDeMensaje(message) ?? 'Notificación',
    body: _cuerpoDeMensaje(message) ?? 'Toque para ver detalles.',
    data: message.data,
    receivedAt: DateTime.now().toUtc(),
  );
}

/// Guarda un mensaje leyendo y escribiendo directamente en disco.
///
/// El handler de background corre en otro isolate y no puede tocar la
/// instancia de [PushNotificationsService], así que la persistencia vive
/// suelta para que ambos isolates compartan la misma lógica.
Future<void> _persistMessageToStorage(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    if (!(prefs.getBool(_kNewsAlertsKey) ?? true)) return;
    if (!_mensajeTieneContenido(message)) return;

    final item = _itemFromMessage(message);
    final stored = prefs.getStringList(_kStorageKey) ?? <String>[];

    final yaGuardado = stored.any((raw) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return json['id']?.toString() == item.id;
      } catch (_) {
        return false;
      }
    });
    if (yaGuardado) return;

    final updated = [jsonEncode(item.toJson()), ...stored];
    if (updated.length > _kMaxStoredNotifications) {
      updated.removeRange(_kMaxStoredNotifications, updated.length);
    }
    await prefs.setStringList(_kStorageKey, updated);
  } catch (_) {}
}

bool _esTipoNoticia(String type) {
  final normalizado = type.trim().toLowerCase();
  return normalizado == 'noticia' || normalizado == 'noticias';
}

String _slugDeNoticia(Map<String, dynamic> data) {
  final slug = data['slug']?.toString().trim() ?? '';
  if (slug.isNotEmpty) return slug;
  return NoticiaLinkUtil.slugDesdeEnlace(data['url']?.toString() ?? '');
}

/// Las notas de nuestros dominios se leen dentro de la app; las de cualquier
/// otro sitio no las podemos renderizar y se abren en el navegador.
bool _noticiaAbreEnLaApp(Map<String, dynamic> data) {
  if (!_esTipoNoticia(data['type']?.toString() ?? '')) return false;

  final url = data['url']?.toString().trim() ?? '';
  if (url.isNotEmpty) return NoticiaLinkUtil.esDominioPropio(url);

  // Sin enlace solo queda el slug, y ese siempre es de la API propia.
  return _slugDeNoticia(data).isNotEmpty;
}

/// Relee el historial cuando la app vuelve al primer plano, porque lo que
/// llegó estando cerrada lo escribió el otro isolate.
class _LifecycleWatcher with WidgetsBindingObserver {
  _LifecycleWatcher(this._onResume);

  final Future<void> Function() _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_onResume());
  }
}

class PushNotificationItem {
  PushNotificationItem({
    required this.id,
    this.title,
    this.body,
    this.data,
    required this.receivedAt,
    this.read = false,
  });

  factory PushNotificationItem.fromJson(Map<String, dynamic> json) {
    return PushNotificationItem(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
      receivedAt:
          DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      read: json['read'] == true,
    );
  }

  final String id;
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final DateTime receivedAt;
  final bool read;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'data': data ?? <String, dynamic>{},
    'receivedAt': receivedAt.toIso8601String(),
    'read': read,
  };

  String get type => data?['type']?.toString() ?? '';

  String? get imageUrl =>
      data?['imageUrl']?.toString().trim().isNotEmpty == true
          ? data!['imageUrl'].toString()
          : null;

  String? get url => data?['url']?.toString().trim().isNotEmpty == true
      ? data!['url'].toString()
      : null;

  /// Slug de la nota cuando el aviso anuncia una noticia.
  String get slug => _slugDeNoticia(data ?? const <String, dynamic>{});

  /// `true` si la nota se puede leer dentro de la app.
  bool get abreEnLaApp => _noticiaAbreEnLaApp(data ?? const <String, dynamic>{});
}

class PushNotificationsService extends ChangeNotifier {
  static const _flipsTopic = 'flips';

  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  /// Perezoso a propósito: `FirebaseMessaging.instance` lanza si Firebase no
  /// arrancó, y como campo tumbaba la app antes de que corriera cualquier
  /// guarda de `_firebaseReady`. Todos los usos ya están detrás de una.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  final HttpService _httpService = HttpService();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  late final _LifecycleWatcher _lifecycleWatcher = _LifecycleWatcher(
    refreshFromStorage,
  );

  final List<PushNotificationItem> _notifications = [];

  bool _initialized = false;
  bool _newsAlertsEnabled = true;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  /// `false` cuando Firebase no pudo inicializarse: no tiene sentido pedir
  /// permisos que no vamos a poder usar.
  bool get isAvailable => _firebaseReady;

  /// Preferencia del usuario para recibir avisos de noticias nuevas.
  ///
  /// Es independiente del permiso del sistema: permite apagar los avisos desde
  /// la app sin tener que ir a los ajustes del teléfono.
  bool get newsAlertsEnabled => _newsAlertsEnabled;

  Future<void> init() async {
    if (_initialized) return;

    await _loadNewsAlertsPreference();
    await _loadNotifications();
    if (!_firebaseReady) {
      _initialized = true;
      notifyListeners();
      return;
    }

    await _initializeLocalNotifications();
    // No solicitar ni sincronizar token automáticamente al iniciar la app.
    // El token se registra después de login y permiso explícito del usuario.

    WidgetsBinding.instance.addObserver(_lifecycleWatcher);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
    _messaging.onTokenRefresh.listen((token) async {
      await _syncTokenWithBackend(token, activo: _newsAlertsEnabled);
      await _subscribeToFlipsTopic();
    });

    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _subscribeToFlipsTopic();
    }

    // Si apagar o encender los avisos falló por red, se reintenta ahora: de lo
    // contrario la preferencia queda guardada pero el servidor sigue enviando.
    unawaited(_retryPendingAlertsSync());

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _addNotification(initialMessage);
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  /// Relee el historial guardado en disco.
  ///
  /// Lo que llega con la app cerrada lo escribe el isolate de background, así
  /// que esta instancia solo se entera releyendo.
  Future<void> refreshFromStorage() async {
    await _loadNewsAlertsPreference();
    await _loadNotifications();
    notifyListeners();
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
      // Conceder el permiso es una aceptación explícita: reactivamos los
      // avisos aunque el usuario los hubiera apagado antes.
      if (!_newsAlertsEnabled) {
        await setNewsAlertsEnabled(true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await _applyAlertsPreference(prefs);
      }
      notifyListeners();
    }

    return isGranted;
  }

  /// Enciende o apaga los avisos de noticias sin tocar el permiso del sistema.
  Future<void> setNewsAlertsEnabled(bool enabled) async {
    if (_newsAlertsEnabled == enabled) return;

    _newsAlertsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNewsAlertsKey, enabled);

    await _applyAlertsPreference(prefs);
  }

  /// Propaga la preferencia a FCM y al backend.
  ///
  /// Desuscribirse del topic no alcanza: el backend también envía a los tokens
  /// registrados uno por uno, así que hay que marcar el token como inactivo o
  /// los avisos siguen llegando igual.
  Future<void> _applyAlertsPreference(SharedPreferences prefs) async {
    final sincronizado = _newsAlertsEnabled
        ? await _enableDelivery()
        : await _disableDelivery();
    // Se guarda el fallo para reintentar en el próximo arranque.
    await prefs.setBool(_kPendingAlertsSyncKey, !sincronizado);
  }

  Future<bool> _enableDelivery() async {
    if (!_firebaseReady) return false;
    final suscrito = await _subscribeToFlipsTopic();
    final registrado = await _updateTokenActivo(true);
    return suscrito && registrado;
  }

  Future<bool> _disableDelivery() async {
    if (!_firebaseReady) return false;
    final desuscrito = await _unsubscribeFromFlipsTopic();
    final desregistrado = await _updateTokenActivo(false);
    return desuscrito && desregistrado;
  }

  Future<void> _retryPendingAlertsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPendingAlertsSyncKey) != true) return;
      await _applyAlertsPreference(prefs);
    } catch (_) {}
  }

  Future<void> _loadNewsAlertsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _newsAlertsEnabled = prefs.getBool(_kNewsAlertsKey) ?? true;
    } catch (_) {}
  }

  Future<bool> _subscribeToFlipsTopic() async {
    if (!_firebaseReady || !_newsAlertsEnabled) return false;
    try {
      await _messaging.subscribeToTopic(_flipsTopic);
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<bool> _unsubscribeFromFlipsTopic() async {
    if (!_firebaseReady) return false;
    try {
      await _messaging.unsubscribeFromTopic(_flipsTopic);
      return true;
    } catch (error) {
      return false;
    }
  }

  List<PushNotificationItem> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((item) => !item.read).length;

  PushNotificationItem? notificationById(String id) {
    for (final item in _notifications) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      final item = _notifications[i];
      if (item.read) continue;
      _notifications[i] = PushNotificationItem(
        id: item.id,
        title: item.title,
        body: item.body,
        data: item.data,
        receivedAt: item.receivedAt,
        read: true,
      );
      changed = true;
    }
    if (!changed) return;
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((item) => item.id == id);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> deleteNotifications(Iterable<String> ids) async {
    final idsSet = ids.toSet();
    if (idsSet.isEmpty) return;
    _notifications.removeWhere((item) => idsSet.contains(item.id));
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sin `reload` seguiríamos viendo la copia en memoria de este isolate y
      // nunca lo que guardó el handler de background.
      await prefs.reload();
      final rawItems = prefs.getStringList(_kStorageKey) ?? <String>[];
      _notifications
        ..clear()
        ..addAll(
          rawItems.map((raw) {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            return PushNotificationItem.fromJson(json);
          }),
        );
    } catch (_) {}
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kStorageKey,
        _notifications.map((item) => jsonEncode(item.toJson())).toList(),
      );
    } catch (_) {}
  }

  /// Retorna true si el permiso de notificaciones ya está habilitado
  Future<bool> isNotificationPermissionGranted() async {
    if (!_firebaseReady) return false;
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// ¿Este equipo ya figura en el backend?
  ///
  /// Tener el permiso concedido no implica estar registrado: son dos cosas
  /// distintas. `_kPendingAlertsSyncKey` se escribe en cada intento de alta,
  /// así que `false` significa que alguno terminó bien y ausente significa que
  /// nunca se intentó.
  ///
  /// Ese «nunca se intentó» es el caso de los teléfonos que traen el permiso
  /// concedido de fábrica: como no había nada que pedir, no se pedía, y sin esa
  /// llamada el token no salía nunca hacia la API por más que el permiso
  /// estuviera en verde.
  Future<bool> isDeviceRegistered() async {
    if (!_firebaseReady) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kPendingAlertsSyncKey) == false;
    } catch (_) {
      return false;
    }
  }

  /// Se llama antes de limpiar la sesión, mientras el token de auth sigue
  /// siendo válido: si no, el backend seguiría enviando avisos a este equipo.
  Future<void> unregisterTokenOnLogout() async {
    if (!_firebaseReady) return;
    await _unsubscribeFromFlipsTopic();
    await _updateTokenActivo(false);
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

  Future<void> _syncCurrentToken() async {
    await _updateTokenActivo(_newsAlertsEnabled);
  }

  /// Marca este equipo como activo o inactivo en el backend.
  Future<bool> _updateTokenActivo(bool activo) async {
    if (!_firebaseReady) return false;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return false;
      return await _syncTokenWithBackend(token, activo: activo);
    } on FirebaseException {
      return false;
    }
  }

  Future<bool> _syncTokenWithBackend(
    String token, {
    required bool activo,
  }) async {
    // Sin sesión válida `HttpService` fuerza el logout: no vale la pena
    // mandar al login a alguien que solo tocó el switch de avisos.
    if (!await SessionService.hasValidSession()) return false;

    try {
      final response = await _httpService.post(
        '${apiUrl}mobile/push/register-token',
        body: {
          'token': token,
          'plataforma': Platform.isIOS ? 'ios' : 'android',
          'activo': activo,
        },
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } on SocketException {
      return false;
    } catch (error) {
      return false;
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // Avisos apagados: ni aviso en pantalla ni entrada en el historial.
    if (!_newsAlertsEnabled) return;
    if (!_mensajeTieneContenido(message)) return;

    await _addNotification(message);

    final titulo = _tituloDeMensaje(message);
    final cuerpo = _cuerpoDeMensaje(message);

    // Con la app abierta el aviso lo dibuja la app, no FCM: si no se baja la
    // foto acá, la noticia llega sin imagen justo cuando el usuario está
    // mirando la pantalla.
    final imagen = _imagenDeMensaje(message);
    final rutaImagen =
        imagen == null ? null : await _descargarImagenDeAviso(imagen);

    // Con la foto se despliega a lo grande; sin ella, al menos el texto
    // completo en vez de una sola línea recortada.
    final estilo = rutaImagen != null
        ? BigPictureStyleInformation(
            FilePathAndroidBitmap(rutaImagen),
            largeIcon: FilePathAndroidBitmap(rutaImagen),
            contentTitle: titulo,
            summaryText: cuerpo,
            hideExpandedLargeIcon: true,
          )
        : (cuerpo != null ? BigTextStyleInformation(cuerpo) : null);

    // Con los textos ya resueltos: el aviso que traía el título solo en `data`
    // se descartaba aquí y nunca llegaba a la bandeja con la app abierta.
    await _localNotificationsPlugin.show(
      _idDeAvisoLocal(message),
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'new_flips',
          'Flips Notifications',
          channelDescription: 'Channel used for Flips push notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: estilo,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _addNotification(RemoteMessage message) async {
    // También entran por aquí `getInitialMessage` y `onMessageOpenedApp`, así
    // que el filtro vive en este punto y no solo en el de primer plano.
    if (!_mensajeTieneContenido(message)) return;

    final item = _itemFromMessage(message);
    // El isolate de background pudo haberlo guardado ya: sin este control el
    // mismo aviso aparecería dos veces al tocarlo.
    if (_notifications.any((guardada) => guardada.id == item.id)) return;

    _notifications.insert(0, item);
    if (_notifications.length > _kMaxStoredNotifications) {
      _notifications.removeRange(
        _kMaxStoredNotifications,
        _notifications.length,
      );
    }

    await _saveNotifications();
    notifyListeners();
  }

  /// En iOS el handler de background solo corre con `content-available`, así
  /// que abrir el aviso es el único momento garantizado para guardarlo.
  Future<void> _onNotificationOpened(RemoteMessage message) async {
    await _addNotification(message);
    _handleNotificationTap(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateFromPayload(message.data);
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (type) {
      case 'noticia':
      case 'noticias':
        _abrirNoticia(navigator, data);
        break;
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
        // Volver al Home ya montado en vez de apilar una copia encima.
        navigator.popUntil((route) => route.isFirst);
    }
  }

  /// Las notificaciones de campaña traen la nota completa en el payload: si es
  /// de un dominio propio se abre el detalle de la app y solo el resto se
  /// delega al navegador.
  void _abrirNoticia(NavigatorState navigator, Map<String, dynamic> data) {
    if (_noticiaAbreEnLaApp(data)) {
      // Sin interstitial: por aquí se entra tocando el aviso del sistema, con
      // la app cerrada o en segundo plano. El anuncio quedaría encima de lo
      // primero que el usuario ve al abrir la app.
      navigator.push(rutaNoticiaDesdePush(data));
      return;
    }

    final url = data['url']?.toString().trim() ?? '';
    final uri = url.isEmpty ? null : Uri.tryParse(url);
    if (uri == null) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }
}
