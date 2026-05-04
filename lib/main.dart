// ignore_for_file: depend_on_referenced_packages, avoid_print, empty_catches, deprecated_member_use

import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flips_app/constants.dart';

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
        // ChangeNotifierProvider(create: (context) => MembresiaProvider()),
        // ChangeNotifierProvider(create: (context) => ClienteProvider()),
        // ChangeNotifierProvider(create: (context) => SuscripcionProvider()),
        // ChangeNotifierProvider(create: (context) => PagosProvider()),
        // ChangeNotifierProvider(create: (context) => FichaTecnicaProvider()),
        // ChangeNotifierProvider(create: (context) => EquipoProvider()),
        // ChangeNotifierProvider(create: (context) => FinanzaProvider()),
        // ChangeNotifierProvider(create: (context) => PromocionProvider()),
        // ChangeNotifierProvider(create: (context) => MensajeProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          // GlobalMaterialLocalizations.delegate,
          // GlobalWidgetsLocalizations.delegate,
          // GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es', 'ES')],
        locale: const Locale('es', 'ES'),
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: snackbarKey,
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
        title: 'Zona Fitness',
        home: const HomeScreen(),
      ),
    );
  }
}
