import 'package:flutter/material.dart';

const String urlBase = 'https://www.diariotiempo.hn/api/';
// const String urlBase = 'http://192.168.2.9:3000/api/';
String apiUrl = urlBase;

// String apiUrl = 'http://192.168.0.33:7781/api/';


// String apiUrl = 'http://10.16.42.157:8080/api/';

String version = '1.0.0';

GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppAssets {
  String logoAppWhite = 'assets/images/logo.png';
  String noImage = 'assets/images/no-image.png';
  // String muestra = 'assets/images/hoja.jpg';
  String ubicacionactiva = 'assets/images/place.png';
}
