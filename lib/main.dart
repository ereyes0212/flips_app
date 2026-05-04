import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'screens/screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlipsApp());
}

class FlipsApp extends StatelessWidget {
  const FlipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NewspapersProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const AppRoot(),
    );
  }
}
