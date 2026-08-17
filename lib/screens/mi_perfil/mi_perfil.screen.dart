import 'package:flips_app/controllers/mi_perfil.controller.dart';
import 'package:flips_app/models/mi_perfil.model.dart';
import 'package:flips_app/providers/mi_perfil.provider.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    final theme = Theme.of(context);
    final plan = perfil.suscripcionActiva?.plan ?? 'Sin plan activo';
    final hasPlan = perfil.suscripcionActiva != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHero(perfil: perfil),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPlan ? 'Tu suscripción' : 'Tu cuenta',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasPlan
                      ? 'Plan activo: $plan. Mantén tus beneficios al día.'
                      : 'Tu cuenta no tiene una suscripción activa. Puedes revisar su estado desde el sitio web.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaquetesScreen()),
                  ),
                  icon: Icon(hasPlan ? Icons.workspace_premium : Icons.manage_accounts_rounded),
                  label: const Text('Gestionar mi cuenta'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSectionCard(
          title: 'Información personal',
          children: [
            _DataTile(label: 'Usuario', value: perfil.usuario, icon: Icons.person_outline_rounded),
            _DataTile(label: 'Teléfono', value: perfil.telefono, icon: Icons.call_outlined),
            _DataTile(label: 'Dirección', value: perfil.direccion, icon: Icons.home_outlined),
            _DataTile(
              label: 'Ciudad',
              value: perfil.ciudad,
              icon: Icons.location_city_outlined,
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileSectionCard(
          title: 'Información de suscripción',
          children: [
            _DataTile(label: 'Plan activo', value: plan, icon: Icons.workspace_premium_outlined),
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
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.perfil});

  final MiPerfilModel perfil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fotoUrl = perfil.fotoUrl?.trim() ?? '';
    final inicial = Text(
      perfil.nombre.isEmpty ? '?' : perfil.nombre[0].toUpperCase(),
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: colorScheme.onPrimaryContainer,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: colorScheme.primaryContainer,
              child: fotoUrl.isEmpty
                  ? inicial
                  : ClipOval(
                      child: Image.network(
                        fotoUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => inicial,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return inicial;
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              perfil.nombre.isEmpty ? 'Sin nombre' : perfil.nombre,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              perfil.email.isEmpty ? '-' : perfil.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({required this.label, required this.value, required this.icon, this.showDivider = true});

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
        border: showDivider ? Border(bottom: BorderSide(color: colorScheme.outlineVariant)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
