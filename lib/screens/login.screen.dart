import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals/widgets/widgets.dart';
import '../providers/providers.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FadeInUp(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Diarios Digitales', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                PrimaryButtonWidget(
                  label: 'Continuar con Google',
                  loading: auth.isLoading,
                  onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
