import 'package:flutter/material.dart';

const String urlBase = 'https://www.diariotiempo.hn/api/';
// const String urlBase = 'http://192.168.2.9:3000/api/';
String apiUrl = urlBase;

// String apiUrl = 'http://192.168.0.33:7781/api/';

// String apiUrl = 'http://10.16.42.157:8080/api/';

/// Versión instalada: la usan la cabecera `X-App-Version` y el banner de nueva
/// versión.
///
/// Al arrancar, `cargarVersionInstalada()` la reemplaza por la real (la de
/// pubspec.yaml, leída con package_info_plus). Este valor solo queda si esa
/// lectura falla; conviene igual mantenerlo en sync en cada release.
String version = '1.1.7';

/// Número de compilación (el `+15` de pubspec.yaml). Lo carga
/// `cargarVersionInstalada()`; vacío si no se pudo leer. Sirve para distinguir
/// compilaciones de una misma versión en las pruebas internas.
String compilacion = '';

/// Identifica la petición como originada en la app (cabecera `X-Client-App`),
/// para distinguirla en el backend del tráfico del sitio web.
const String clientApp = 'tiempo-app';

GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Permite a una pantalla enterarse de que volvió al frente.
///
/// `AppAnalyticsRouteObserver` es un `NavigatorObserver` y no sirve para esto:
/// `RouteAware` (y con él `didPopNext`) necesita un `RouteObserver`. Lo usa el
/// listado de noticias para recargar al regresar de una nota, que es el caso que
/// `initState` no cubre — la pantalla nunca se destruyó.
final RouteObserver<PageRoute<dynamic>> rutasObserver =
    RouteObserver<PageRoute<dynamic>>();

class AppAssets {
  String logoAppWhite = 'assets/images/logo.png';
  String noImage = 'assets/images/no-image.png';
  // String muestra = 'assets/images/hoja.jpg';
  String ubicacionactiva = 'assets/images/place.png';
}
