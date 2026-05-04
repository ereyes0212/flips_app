import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: usuario == null
          ? const Center(child: Text('Sin sesión'))
          : ListTile(
              leading: CircleAvatar(backgroundImage: usuario.photoUrl != null ? NetworkImage(usuario.photoUrl!) : null),
              title: Text(usuario.nombre),
              subtitle: Text(usuario.email),
            ),
    );
  }
}
