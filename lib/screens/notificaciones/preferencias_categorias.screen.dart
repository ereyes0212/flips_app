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

  /// Tope que manda el servidor; el backend recorta igual si llegan de más.
  int _max = kMaxCategoriasNotificacionDefault;

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

      final preferencia = await _service.obtener();
      if (!mounted) return;

      setState(() {
        _categorias = categorias;
        _max = preferencia.maxCategorias;
        _seleccion
          ..clear()
          ..addAll(preferencia.categorias);
        _porCategoria = preferencia.categorias.isNotEmpty;
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

  bool get _enTope => _seleccion.length >= _max;

  /// Cuentas que guardaron más de la cuenta antes de que existiera el tope: se
  /// les muestran todas, pero tienen que quitar hasta quedar en `_max`.
  bool get _excede => _porCategoria && _seleccion.length > _max;

  void _alternar(int categoriaId) {
    if (_seleccion.contains(categoriaId)) {
      setState(() => _seleccion.remove(categoriaId));
      return;
    }

    if (_enTope) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Podés elegir hasta $_max categorías. Quitá una para elegir otra.',
            ),
          ),
        );
      return;
    }

    setState(() => _seleccion.add(categoriaId));
  }

  Future<void> _guardar() async {
    if (_guardando || _sinSeleccion || _excede) return;

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final elegidas = _porCategoria ? _seleccion.toList() : <int>[];
      final guardada = await _service.guardar(elegidas);
      final guardadas = guardada.categorias;
      await PushNotificationsService.instance.setModoCategorias(
        guardadas.isNotEmpty,
      );

      if (!mounted) return;
      setState(() {
        _max = guardada.maxCategorias;
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
      body:
          !sesionIniciada
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
                  ? 'Recibís cada hora la última noticia de las categorías marcadas (hasta $_max).'
                  : 'Apagado: recibís todas las noticias, como hasta ahora.',
            ),
          ),
        ),
        if (_porCategoria) ...[
          const SizedBox(height: 12),
          if (_categorias.isNotEmpty)
            _EncabezadoTope(elegidas: _seleccion.length, max: _max),
          const SizedBox(height: 10),
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
            LayoutBuilder(
              builder: (context, constraints) {
                // Dos por fila: cada chip ocupa la mitad del ancho menos la
                // separación. Se adapta solo a cualquier ancho de pantalla.
                const separacion = 10.0;
                final anchoItem = (constraints.maxWidth - separacion) / 2;

                return Wrap(
                  spacing: separacion,
                  runSpacing: separacion,
                  children: [
                    for (final categoria in _categorias)
                      SizedBox(
                        width: anchoItem,
                        child: _CategoriaChip(
                          nombre: categoria.name,
                          seleccionada: _seleccion.contains(categoria.id),
                          // Sigue respondiendo al toque (para explicar el
                          // tope), pero se ve apagada.
                          bloqueada:
                              _enTope && !_seleccion.contains(categoria.id),
                          onTap: () => _alternar(categoria.id),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (_sinSeleccion || _excede)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _excede
                    ? 'Tenés ${_seleccion.length} categorías y el máximo es $_max. '
                        'Quitá ${_seleccion.length - _max} para poder guardar.'
                    : 'Elegí al menos una categoría, o apagá el interruptor para recibir todas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _guardando || _sinSeleccion || _excede ? null : _guardar,
          child:
              _guardando
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
            FilledButton(
              onPressed: onIniciarSesion,
              child: const Text('Iniciar sesión'),
            ),
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
            ElevatedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Elegí hasta 3" con el contador `N/3`, que se tiñe al llegar al tope.
class _EncabezadoTope extends StatelessWidget {
  const _EncabezadoTope({required this.elegidas, required this.max});

  final int elegidas;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completo = elegidas >= max;

    return Row(
      children: [
        Expanded(
          child: Text(
            completo
                ? 'Llegaste al máximo de $max categorías'
                : 'Elegí hasta $max categorías',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: completo ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$elegidas/$max',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: completo ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip seleccionable de una categoría. Va en una grilla de dos columnas; al
/// marcarse se tiñe con el color primario y muestra el check. `bloqueada` la
/// apaga cuando ya se llegó al tope (el toque igual llega, para avisar).
class _CategoriaChip extends StatelessWidget {
  const _CategoriaChip({
    required this.nombre,
    required this.seleccionada,
    required this.onTap,
    this.bloqueada = false,
  });

  final String nombre;
  final bool seleccionada;
  final bool bloqueada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: bloqueada ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color:
                  seleccionada
                      ? colors.primary.withValues(alpha: 0.10)
                      : colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: seleccionada ? colors.primary : colors.outlineVariant,
                width: seleccionada ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  seleccionada ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: seleccionada ? colors.primary : colors.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight:
                          seleccionada ? FontWeight.w700 : FontWeight.w500,
                      color: seleccionada ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
