

import 'package:flutter/material.dart';

// String apiUrl = 'http://190.92.48.230:7781/api/';
// String apiUrl = 'http://192.168.1.25:7780/api/';
// String apiUrl = 'http://192.168.1.21:8080/api/';
// String apiUrl = 'http://192.141.7.174:7780/api/';
const String urlBase = 'https://www.diariotiempo.hn/api/';
String apiUrl = urlBase;

// String apiUrl = 'http://192.168.0.33:7781/api/';

// String apiUrl = 'http://10.16.42.157:8080/api/';

String version = '1.0.0';

// PixelPay configuration
// Values are injected at build/run time with Flutter --dart-define.
const String pixelpayEndpoint = String.fromEnvironment(
  'NEXT_PUBLIC_PIXELPAY_ENDPOINT',
  defaultValue: 'https://hn.ficoposonline.com',
);
const String pixelpayPublicKey = String.fromEnvironment(
  'NEXT_PUBLIC_PIXELPAY_KEY_ID',
);
const String pixelpaySecretKey = String.fromEnvironment(
  'NEXT_PUBLIC_PIXELPAY_KEY_HASH',
);

GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppAssets {
  String logoAppWhite = 'assets/images/logo.png';
  String noImage = 'assets/images/no-image.png';
  // String muestra = 'assets/images/hoja.jpg';
  String ubicacionactiva = 'assets/images/place.png';
}
