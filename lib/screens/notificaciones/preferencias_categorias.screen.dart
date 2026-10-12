import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flips_app/services/notificacion_preferencias.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Permite elegir de qué categorías recibir el aviso horario.
///
/// La preferencia vive en la cuenta (la comparte con la web), así que requiere
/// sesión. Al invitado se le ofrece iniciarla en vez de cargar nada.
///
/// "Todas" mantiene el topic `flips` de siempre; "elegir categorías" saca al
/// dispositivo de ese topic y deja que el backend reparta por token. Ese cambio
/// de topic lo hace `PushNotificationsService.setModoCategorias`.
class PreferenciasCategoriasScreen extends StatefulWidget {
  const PreferenciasCategoriasScreen({super.key});

  @override
  State<PreferenciasCategoriasScreen> createState() =>
      _PreferenciasCategoriasScreenState();
}

class _PreferenciasCategoriasScreenState
    extends State<PreferenciasCategoriasScreen> {
  final NotificacionPreferenciasService _service =
      NotificacionPreferenciasService();

  bool _cargando = true;
  String _error = '';
  bool _porCategoria = false;
  bool _guardando = false;
  final Set<int> _seleccion = {};
  List<CategoriaNoticiaModel> _categorias = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  Future<void> _cargar() async {
    // Sin sesión no hay nada que pedir: el backend exige cuenta y, además, una
    // petición "requerida" sin token mandaría al invitado al login.
    if (!context.read<AuthProvider>().sesionIniciada) {
      setState(() => _cargando = false);
      return;
    }

    setState(() {
      _cargando = true;
      _error = '';
    });

    try {
      var categorias = context.read<NoticiasProvider>().categorias;
      if (categorias.isEmpty) {
        categorias = (await NoticiasService().obtenerCategorias()).items;
      }

      final elegidas = await _service.obtener();
      if (!mounted) return;

      setState(() {
        _categorias = categorias;
        _seleccion
          ..clear()
          ..addAll(elegidas);
        _porCategoria = elegidas.isNotEmpty;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus preferencias.';
        _cargando = false;
      });
    }
  }

  bool get _sinSeleccion => _porCategoria && _seleccion.isEmpty;

  Future<void> _guardar() async {
    if (_guardando || _sinSeleccion) return;

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final elegidas = _porCategoria ? _seleccion.toList() : <int>[];
      final guardadas = await _service.guardar(elegidas);
      await PushNotificationsService.instance.setModoCategorias(guardadas.isNotEmpty);

      if (!mounted) return;
      setState(() {
        _seleccion
          ..clear()
          ..addAll(guardadas);
        _porCategoria = guardadas.isNotEmpty;
        _guardando = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            guardadas.isEmpty
                ? 'Listo. Recibirás todas las noticias.'
                : 'Listo. Recibirás por hora la última nota de '
                      '${guardadas.length} categoría${guardadas.length == 1 ? "" : "s"}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('No pudimos guardar. Intentá de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesionIniciada = context.watch<AuthProvider>().sesionIniciada;

    return Scaffold(
      appBar: AppBar(title: const Text('Avisos por categoría')),
      body: !sesionIniciada
          ? _VistaInvitado(onIniciarSesion: _iniciarSesion)
          : _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? _VistaError(mensaje: _error, onReintentar: _cargar)
          : _contenido(context),
    );
  }

  Future<void> _iniciarSesion() async {
    final ok = await abrirLogin(context);
    if (ok && mounted) await _cargar();
  }

  Widget _contenido(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          child: SwitchListTile(
            value: _porCategoria,
            onChanged: (valor) => setState(() => _porCategoria = valor),
            title: const Text('Elegir categorías'),
            subtitle: Text(
              _porCategoria
                  ? 'Recibís cada hora la última noticia de las categorías marcadas.'
                  : 'Apagado: recibís todas las noticias, como hasta ahora.',
            ),
          ),
        ),
        if (_porCategoria) ...[
          const SizedBox(height: 8),
          if (_categorias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No pudimos cargar las categorías. Intentá de nuevo más tarde.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final categoria in _categorias)
                    CheckboxListTile(
                      value: _seleccion.contains(categoria.id),
                      onChanged: (marcado) {
                        setState(() {
                          if (marcado == true) {
                            _seleccion.add(categoria.id);
                          } else {
                            _seleccion.remove(categoria.id);
                          }
                        });
                      },
                      title: Text(categoria.name),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
          if (_sinSeleccion)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Elegí al menos una categoría, o apagá el interruptor para recibir todas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _guardando || _sinSeleccion ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _VistaInvitado extends StatelessWidget {
  const _VistaInvitado({required this.onIniciarSesion});

  final VoidCallback onIniciarSesion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Elegí tus categorías',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Iniciá sesión para personalizar qué avisos recibís. Tu elección se '
              'guarda en tu cuenta y vale también en la web.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onIniciarSesion, child: const Text('Iniciar sesión')),
          ],
        ),
      ),
    );
  }
}

class _VistaError extends StatelessWidget {
  const _VistaError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
