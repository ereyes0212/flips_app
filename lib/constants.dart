

import 'package:flutter/material.dart';

// String apiUrl = 'http://190.92.48.230:7781/api/';
// String apiUrl = 'http://192.168.1.25:7780/api/';
// String apiUrl = 'http://192.168.1.21:8080/api/';
// String apiUrl = 'http://192.141.7.174:7780/api/';
const String urlBase = 'http://192.168.2.20:3000/api/';
String apiUrl = urlBase;

// String apiUrl = 'http://192.168.0.33:7781/api/';

// String apiUrl = 'http://10.16.42.157:8080/api/';

String version = '1.0.0';

// PixelPay configuration
const String pixelpayEndpoint = 'https://api.pixelpay.app';
const String pixelpayPublicKey = 'FH1828955021';
const String pixelpaySecretKey = '2d98aaf75de7a9ba64574ad608412d9795605eb1aa7868d776dc38ff2c5aeee8c9c63c645b1edfaaacafba2c0841c6bc8e5f4f113f81bc636c1233f75ad0e4f0';

GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();

class AppAssets {
  String logoAppWhite = 'assets/images/logozf.png';
  String noImage = 'assets/images/no-image.png';
  // String muestra = 'assets/images/hoja.jpg';
  String ubicacionactiva = 'assets/images/place.png';
}
