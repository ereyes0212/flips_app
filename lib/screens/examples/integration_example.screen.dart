import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';

class IntegrationExampleScreen extends StatelessWidget {
  const IntegrationExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ejemplo Integración API')),
      body: Consumer2<AuthProvider, PerfilProvider>(
        builder: (_, auth, perfil, __) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: auth.loading ? null : () => auth.login('demo@mail.com', '123456'),
                child: const Text('Login'),
              ),
              ElevatedButton(
                onPressed: perfil.loading ? null : perfil.cargarPerfil,
                child: const Text('Cargar perfil'),
              ),
              if (auth.error != null) Text('Auth error: ${auth.error}'),
              if (perfil.perfil != null) Text('Hola ${perfil.perfil!.nombre}'),
            ],
          ),
        ),
      ),
    );
  }
}
