import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import 'screens.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flips App',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        colorSchemeSeed: const Color(0xFF1F4ED8),
      ),
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) => auth.isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
