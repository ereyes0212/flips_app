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
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          child: Text(
            perfil.nombre.isEmpty ? '?' : perfil.nombre[0].toUpperCase(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        _DataTile(label: 'Nombre', value: perfil.nombre),
        _DataTile(label: 'Usuario', value: perfil.usuario),
        _DataTile(label: 'Email', value: perfil.email),
        _DataTile(label: 'Teléfono', value: perfil.telefono),
        _DataTile(label: 'Dirección', value: perfil.direccion),
        _DataTile(label: 'Ciudad', value: perfil.ciudad),
        _DataTile(label: 'Rol', value: perfil.rol.nombre),
        _DataTile(
          label: 'Plan activo',
          value: perfil.suscripcionActiva?.plan ?? 'Sin plan activo',
        ),
        _DataTile(
          label: 'Estado suscripción',
          value: perfil.suscripcionActiva?.estado ?? 'N/A',
        ),
        _DataTile(
          label: 'Intervalo',
          value: perfil.suscripcionActiva?.intervalo ?? 'N/A',
        ),
      ],
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(title: Text(label), subtitle: Text(value.isEmpty ? '-' : value)),
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
