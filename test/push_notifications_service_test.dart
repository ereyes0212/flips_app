import 'dart:convert';

import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El handler de background corre en otro isolate y escribe el historial
/// directo en `SharedPreferences`. Estos tests simulan esa escritura para
/// comprobar que la instancia del isolate principal la ve al releer.
const _storageKey = 'push_notifications_history';
const _newsAlertsKey = 'push_news_alerts_enabled';

String _entrada({
  required String id,
  required String title,
  DateTime? receivedAt,
  bool read = false,
  Map<String, dynamic> data = const {},
}) {
  return jsonEncode({
    'id': id,
    'title': title,
    'body': 'Cuerpo de $id',
    'data': data,
    'receivedAt': (receivedAt ?? DateTime.utc(2026, 1, 1)).toIso8601String(),
    'read': read,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = PushNotificationsService.instance;

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await service.refreshFromStorage();
  });

  test('lee del disco los avisos que llegaron con la app cerrada', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: [
        _entrada(id: 'b', title: 'Nueva', receivedAt: DateTime.utc(2026, 5, 2)),
        _entrada(id: 'a', title: 'Vieja', receivedAt: DateTime.utc(2026, 5, 1)),
      ],
    });

    await service.refreshFromStorage();

    expect(service.notifications, hasLength(2));
    expect(service.notifications.first.title, 'Nueva');
    expect(service.notifications.last.title, 'Vieja');
    expect(service.notificationById('a')?.body, 'Cuerpo de a');
  });

  test('cuenta como no leídos los avisos guardados en background', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: [
        _entrada(id: 'a', title: 'Sin leer'),
        _entrada(id: 'b', title: 'Ya leída', read: true),
      ],
    });

    await service.refreshFromStorage();
    expect(service.unreadCount, 1);

    await service.markAllAsRead();
    expect(service.unreadCount, 0);

    // Y queda persistido, no solo en memoria.
    await service.refreshFromStorage();
    expect(service.unreadCount, 0);
  });

  test('notifica a los oyentes al releer el disco', () async {
    SharedPreferences.setMockInitialValues({_storageKey: <String>[]});
    await service.refreshFromStorage();

    var avisos = 0;
    void listener() => avisos++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    SharedPreferences.setMockInitialValues({
      _storageKey: [_entrada(id: 'a', title: 'Llegó cerrada')],
    });
    await service.refreshFromStorage();

    expect(avisos, greaterThan(0));
    expect(service.notifications.single.title, 'Llegó cerrada');
  });

  test('borrar avisos los quita también del disco', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: [
        _entrada(id: 'a', title: 'Una'),
        _entrada(id: 'b', title: 'Otra'),
      ],
    });
    await service.refreshFromStorage();

    await service.deleteNotification('a');
    await service.refreshFromStorage();

    expect(service.notifications.single.id, 'b');
  });

  test('recuerda que los avisos quedaron apagados', () async {
    SharedPreferences.setMockInitialValues({_newsAlertsKey: false});
    await service.refreshFromStorage();
    expect(service.newsAlertsEnabled, isFalse);

    SharedPreferences.setMockInitialValues({_newsAlertsKey: true});
    await service.refreshFromStorage();
    expect(service.newsAlertsEnabled, isTrue);
  });

  test('sin preferencia guardada los avisos vienen encendidos', () async {
    SharedPreferences.setMockInitialValues({});
    await service.refreshFromStorage();
    expect(service.newsAlertsEnabled, isTrue);
  });
}
