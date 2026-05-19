// ignore_for_file: depend_on_referenced_packages, avoid_print, empty_catches, deprecated_member_use

import 'package:flips_app/constants.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/providers/mi_perfil.provider.dart';
import 'package:flips_app/providers/mis_facturas.provider.dart';
import 'package:flips_app/providers/mis_pagos.provider.dart';
import 'package:flips_app/providers/mis_suscripcion.provider.dart';
import 'package:flips_app/providers/paquetes.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error) {
  }

  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationsService.instance.init();
  }

  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

Future<bool> _resolveInitialSession() async {
  try {
    return await SessionService.hasValidSession().timeout(
      const Duration(seconds: 4),
    );
  } catch (_) {
    return SessionService.hasStoredSession();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A3D91),
      primary: const Color(0xFF0A3D91),
      secondary: const Color(0xFF0ABAB5),
      error: const Color(0xFFD72638),
      surface: const Color(0xFFF6F8FC),
      brightness: Brightness.light,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => MiPerfilProvider()),
        ChangeNotifierProvider(create: (context) => MisFacturasProvider()),
        ChangeNotifierProvider(create: (context) => DiariosDigitalesProvider()),
        ChangeNotifierProvider(create: (context) => NoticiasProvider()),
        ChangeNotifierProvider(create: (context) => PaquetesProvider()),
        ChangeNotifierProvider(create: (context) => MisPagosProvider()),
        ChangeNotifierProvider(create: (context) => MisSuscripcionProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es', 'ES')],
        locale: const Locale('es', 'ES'),
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: snackbarKey,
        navigatorKey: navigatorKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: colorScheme.surface,
          iconTheme: IconThemeData(color: colorScheme.primary, size: 22),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            centerTitle: false,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.9), fontSize: 14),
            floatingLabelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            prefixIconColor: colorScheme.primary,
            suffixIconColor: colorScheme.onSurfaceVariant,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.error, width: 1.6),
            ),
          ),
          textTheme: TextTheme(
            titleLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700),
            bodyLarge: TextStyle(color: colorScheme.onSurface),
            bodyMedium: TextStyle(color: colorScheme.onSurface.withOpacity(0.9)),
            bodySmall: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
        title: 'Diario Tiempo HN',
        routes: {'/login': (_) => const LoginScreen()},
        home: FutureBuilder<bool>(
          future: _resolveInitialSession(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (snapshot.hasError) {
              return const LoginScreen();
            }

            final hasValidSession = snapshot.data ?? false;
            return hasValidSession ? const HomeScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}
