import 'package:flips_app/controllers/mi_perfil.controller.dart';
import 'package:flips_app/models/mi_perfil.model.dart';
import 'package:flips_app/providers/mi_perfil.provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MiPerfilScreen extends StatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  State<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends State<MiPerfilScreen> {
  final MiPerfilController _controller = MiPerfilController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarPerfil(context));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MiPerfilProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: RefreshIndicator(
        onRefresh: () => _controller.cargarPerfil(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (provider.loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage.isNotEmpty)
              _ErrorState(
                message: provider.errorMessage,
                onRetry: () => _controller.cargarPerfil(context),
              )
            else if (provider.perfil == null)
              _ErrorState(
                message: 'No hay información para mostrar.',
                onRetry: () => _controller.cargarPerfil(context),
              )
            else
              _PerfilData(perfil: provider.perfil!),
          ],
        ),
      ),
    );
  }
}

class _PerfilData extends StatelessWidget {
  const _PerfilData({required this.perfil});

  final MiPerfilModel perfil;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.32),
                  colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        perfil.nombre.isEmpty
                            ? '?'
                            : perfil.nombre[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perfil.nombre.isEmpty ? 'Sin nombre' : perfil.nombre,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            perfil.email.isEmpty ? '-' : perfil.email,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Información personal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _DataTile(
                  label: 'Usuario',
                  value: perfil.usuario,
                  icon: Icons.person_outline_rounded,
                ),
                _DataTile(
                  label: 'Teléfono',
                  value: perfil.telefono,
                  icon: Icons.call_outlined,
                ),
                _DataTile(
                  label: 'Dirección',
                  value: perfil.direccion,
                  icon: Icons.home_outlined,
                ),
                _DataTile(
                  label: 'Ciudad',
                  value: perfil.ciudad,
                  icon: Icons.location_city_outlined,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Suscripción',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _DataTile(
                  label: 'Plan activo',
                  value: perfil.suscripcionActiva?.plan ?? 'Sin plan activo',
                  icon: Icons.workspace_premium_outlined,
                ),
                _DataTile(
                  label: 'Estado suscripción',
                  value: perfil.suscripcionActiva?.estado ?? 'N/A',
                  icon: Icons.verified_user_outlined,
                ),
                _DataTile(
                  label: 'Intervalo',
                  value: perfil.suscripcionActiva?.intervalo ?? 'N/A',
                  icon: Icons.date_range_outlined,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.label,
    required this.value,
    required this.icon,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colorScheme.outlineVariant))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
