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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: usuario.photoUrl != null ? NetworkImage(usuario.photoUrl!) : null,
                        child: usuario.photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(usuario.nombre, style: Theme.of(context).textTheme.titleMedium),
                            Text(usuario.email, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Mi cuenta', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ProfileOptionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Paquetes',
                  subtitle: 'Consulta y administra tus paquetes activos',
                  onTap: () {},
                ),
                _ProfileOptionTile(
                  icon: Icons.subscriptions_outlined,
                  title: 'Mis suscripciones',
                  subtitle: 'Revisa tus planes y fechas de renovación',
                  onTap: () {},
                ),
              ],
            ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
