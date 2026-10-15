import 'dart:async';

import 'package:flips_app/constants.dart';
import 'package:flips_app/controllers/diarios_digitales.controller.dart';
import 'package:flips_app/globals/widgets/muro_login.widget.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flips_app/screens/diarios_digitales/ediciones_anteriores.widget.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/diarios_digitales.service.dart';
import 'package:flips_app/services/interstitial_ads.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flips_app/utils/imagen.util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DiariosDigitalesScreen extends StatefulWidget {
  const DiariosDigitalesScreen({super.key});

  @override
  State<DiariosDigitalesScreen> createState() => _DiariosDigitalesScreenState();
}

class _DiariosDigitalesScreenState extends State<DiariosDigitalesScreen> {
  final _controller = DiariosDigitalesController();
  late final List<int> _anios;
  late int _anioSeleccionado;
  late int _mesSeleccionado;
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  /// Mes de los diarios en pantalla. No es lo mismo que el seleccionado: los
  /// desplegables pueden cambiar antes de tocar "Buscar".
  ({int anio, int mes})? _mesCargado;

  /// Día elegido dentro del mes cargado; `null` = todos.
  int? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    _resolverAcceso();
    final now = DateTime.now();
    _anioSeleccionado = now.year;
    _mesSeleccionado = now.month;
    _anios = List.generate(
      now.year + 2 - 2008 + 1,
      (index) => now.year + 2 - index,
    );
    Future.microtask(_cargarLoQueCorresponda);
  }

  /// La edición del día se pide siempre; el archivo solo con sesión.
  ///
  /// `/mis-notas` es contenido de cuenta: sin sesión solo devolvería un `401`
  /// y, peor, arrastraría al invitado fuera de la pestaña. Se corta antes de
  /// salir a la red.
  Future<void> _cargarLoQueCorresponda() async {
    // Se pide también con sesión: quien tiene cuenta pero no suscripción recibe
    // un `403` en el archivo, y sin esto vería menos que un invitado — que es
    // justo al revés de lo que uno esperaría al iniciar sesión.
    unawaited(_controller.cargarUltimoPublico(context));
    // Las anteriores bloqueadas solo se ven sin suscripción, pero la lista es
    // un JSON chico y las portadas se piden solo si se muestran.
    unawaited(_controller.cargarAnteriores(context));

    if (!mounted || !context.read<AuthProvider>().sesionIniciada) return;
    await _buscarDiarios();
  }

  /// Lo que ve un invitado: la edición del día y las anteriores bloqueadas.
  Future<void> _recargarPublico() => Future.wait([
        _controller.cargarUltimoPublico(context),
        _controller.cargarAnteriores(context),
      ]);

  /// Los diarios son contenido de suscriptor, así que el anuncio le toca solo
  /// a quien entra sin suscripción a leer la edición del día. Quien paga no ve
  /// anuncios, y los admins tampoco para poder revisar la app.
  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;

    setState(() => _acceso = acceso);

    // Se pide apenas se abre la pantalla, no al tocar la portada: pedirlo en
    // el toque dejaría el diario esperando a que el anuncio viaje.
    if (acceso.mostrarAnuncios) InterstitialAdsService.diarios.precargar();
  }

  /// Abre la edición pública, renovando la firma si hace falta (ver
  /// [DiariosDigitalesController.edicionPublicaVigente]).
  Future<void> _abrirUltimaEdicionPublica(DiarioDigitalModel diario) async {
    final edicion = await _controller.edicionPublicaVigente(context, diario);
    if (!mounted) return;

    if (edicion == null) {
      mostrarErrorAlAbrirEdicionDelDia(context);
      return;
    }

    _abrirDiario(edicion, publico: true);
  }

  void _abrirDiario(DiarioDigitalModel diario, {bool publico = false}) {
    abrirDiarioDigital(
      Navigator.of(context),
      diario,
      conAnuncio: _acceso.mostrarAnuncios,
      publico: publico,
    );
  }

  static const _meses = {
    1: 'Enero',
    2: 'Febrero',
    3: 'Marzo',
    4: 'Abril',
    5: 'Mayo',
    6: 'Junio',
    7: 'Julio',
    8: 'Agosto',
    9: 'Septiembre',
    10: 'Octubre',
    11: 'Noviembre',
    12: 'Diciembre',
  };

  Future<void> _buscarDiarios() {
    final periodo = (anio: _anioSeleccionado, mes: _mesSeleccionado);
    // Otro mes, otros días: el día elegido no tiene sentido en el nuevo. Al
    // recargar el mismo mes (tirar hacia abajo) se conserva.
    setState(() {
      if (_mesCargado != periodo) _diaSeleccionado = null;
      _mesCargado = periodo;
    });
    return _controller.cargarDiarios(context, anio: periodo.anio, mes: periodo.mes);
  }

  /// Días del mes cargado que tienen al menos un diario con fecha confirmada.
  ///
  /// Se filtra en el teléfono y no en el servidor: el mes ya está en pantalla
  /// completo, así que elegir un día es instantáneo y no gasta otra petición.
  List<int> _diasConDiarios(List<DiarioDigitalModel> diarios) {
    final periodo = _mesCargado;
    if (periodo == null) return const [];
    final dias = {
      for (final d in diarios)
        if (d.fechaEdicion case final fecha?
            when fecha.year == periodo.anio && fecha.month == periodo.mes)
          fecha.day,
    }.toList()
      ..sort();
    return dias;
  }

  List<DiarioDigitalModel> _diariosDelDia(List<DiarioDigitalModel> diarios) {
    final dia = _diaSeleccionado;
    final periodo = _mesCargado;
    if (dia == null || periodo == null) return diarios;
    return diarios
        .where((d) =>
            d.fechaEdicion != null &&
            d.fechaEdicion!.year == periodo.anio &&
            d.fechaEdicion!.month == periodo.mes &&
            d.fechaEdicion!.day == dia)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiariosDigitalesProvider>();
    final sesionIniciada = context.watch<AuthProvider>().sesionIniciada;

    // El invitado lee la edición del día completa; el archivo desde 2008 es lo
    // que sigue siendo de suscriptor. Los filtros de año y mes no se le
    // muestran porque no tendría con qué llenarlos.
    if (!sesionIniciada) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diarios digitales')),
        body: RefreshIndicator(
          onRefresh: _recargarPublico,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _UltimaEdicionPublica(
                provider: provider,
                mes: _meses[provider.ultimoPublico?.mes] ?? '',
                onAbrir: _abrirUltimaEdicionPublica,
              ),
              const SizedBox(height: 24),
              EdicionesAnterioresBloqueadas(diarios: provider.anteriores, sesionIniciada: false),
              const SizedBox(height: 16),
              const MuroLoginCard(
                titulo: 'Ediciones anteriores',
                detalle:
                    'Los anuarios desde 2008 están disponibles para cuentas con '
                    'suscripción activa. La edición del día se lee sin cuenta.',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Diarios digitales')),
      body: RefreshIndicator(
        // También renueva la edición pública: se muestra en esta misma pantalla
        // a las cuentas sin suscripción, y su firma caduca a los 30 minutos.
        onRefresh: _cargarLoQueCorresponda,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _FiltrosDiarios(
                  anios: _anios,
                  meses: _meses,
                  anioSeleccionado: _anioSeleccionado,
                  mesSeleccionado: _mesSeleccionado,
                  loading: provider.loading,
                  onAnioChanged: (value) {
                    if (value == null) return;
                    setState(() => _anioSeleccionado = value);
                  },
                  onMesChanged: (value) {
                    if (value == null) return;
                    setState(() => _mesSeleccionado = value);
                  },
                  onBuscar: _buscarDiarios,
                ),
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: Text(provider.errorMessage)),
              )
            else if (provider.subscriptionRequired)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    // Una cuenta sin suscripción recibe `403` en el archivo. Sin
                    // esto vería menos que un invitado, que es absurdo: la
                    // edición del día es pública para todos.
                    _UltimaEdicionPublica(
                      provider: provider,
                      mes: _meses[provider.ultimoPublico?.mes] ?? '',
                      onAbrir: _abrirUltimaEdicionPublica,
                    ),
                    const SizedBox(height: 24),
                    EdicionesAnterioresBloqueadas(diarios: provider.anteriores, sesionIniciada: true),
                    const SizedBox(height: 16),
                    _SubscriptionUpsellCard(
                      onVerPaquetes: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PaquetesScreen()),
                        );
                      },
                    ),
                  ],
                ),
              )
            else if (provider.diarios.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Text('No hay diarios para mostrar.'),
                ),
              )
            else ...[
              if (_diasConDiarios(provider.diarios) case final dias when dias.isNotEmpty)
                SliverToBoxAdapter(
                  child: _FiltroDia(
                    anio: _mesCargado!.anio,
                    mes: _mesCargado!.mes,
                    dias: dias,
                    seleccionado: _diaSeleccionado,
                    onChanged: (dia) => setState(() => _diaSeleccionado = dia),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: Builder(
                  builder: (context) {
                    final diarios = _diariosDelDia(provider.diarios);
                    return SliverGrid.builder(
                      itemCount: diarios.length,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.56,
                      ),
                      itemBuilder: (context, index) {
                        final diario = diarios[index];
                        return _DiarioPosterCard(
                          diario: diario,
                          mes: _meses[diario.mes] ?? diario.mes.toString(),
                          onTap: !diario.hasPdf ? null : () => _abrirDiario(diario),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Días del mes cargado, para quedarse con uno. Solo aparecen los que tienen
/// un diario con fecha confirmada; "Todos" vuelve al mes completo.
class _FiltroDia extends StatelessWidget {
  const _FiltroDia({
    required this.anio,
    required this.mes,
    required this.dias,
    required this.seleccionado,
    required this.onChanged,
  });

  final int anio;
  final int mes;
  final List<int> dias;
  final int? seleccionado;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: dias.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('Todos'),
              selected: seleccionado == null,
              onSelected: (_) => onChanged(null),
            );
          }
          final dia = dias[index - 1];
          // "mar 22": el día de la semana ayuda a ubicarse más que el número.
          final etiqueta = fechaCortaDiario(DateTime.utc(anio, mes, dia)).split(' ').take(2).join(' ');
          return ChoiceChip(
            label: Text(etiqueta),
            selected: seleccionado == dia,
            onSelected: (marcado) => onChanged(marcado ? dia : null),
          );
        },
      ),
    );
  }
}

/// La edición del día, abierta a cualquiera.
///
/// Se muestra en la pestaña tanto a invitados como a cuentas sin suscripción:
/// son los dos casos que antes no veían absolutamente nada acá.
class _UltimaEdicionPublica extends StatelessWidget {
  const _UltimaEdicionPublica({
    required this.provider,
    required this.mes,
    required this.onAbrir,
  });

  final DiariosDigitalesProvider provider;
  final String mes;
  final ValueChanged<DiarioDigitalModel> onAbrir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diario = provider.ultimoPublico;

    if (provider.cargandoUltimoPublico && diario == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Ni error ni edición: no se dice nada. Es contenido de cortesía, y un
    // mensaje de fallo acá solo ensuciaría la pantalla de quien venía al
    // archivo. El caso "aún no hay edición" sí se nombra, porque es informativo.
    if (diario == null) {
      if (!provider.sinEdicionPublica) return const SizedBox.shrink();

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Todavía no hay una edición publicada.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Edición del día',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Léela completa, sin cuenta.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        // Mismo alto que una tarjeta de la cuadrícula del archivo, para que las
        // dos secciones se lean como lo mismo.
        SizedBox(
          height: 330,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AspectRatio(
              aspectRatio: 0.56,
              child: _DiarioPosterCard(
                diario: diario,
                mes: mes.isEmpty ? diario.mes.toString() : mes,
                publico: true,
                onTap: !diario.hasPdf ? null : () => onAbrir(diario),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiarioPosterCard extends StatelessWidget {
  const _DiarioPosterCard({
    required this.diario,
    required this.mes,
    required this.onTap,
    this.publico = false,
  });

  final DiarioDigitalModel diario;
  final String mes;
  final VoidCallback? onTap;

  /// La edición abierta a invitados: su portada va sin credenciales.
  final bool publico;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPdf = diario.hasPdf;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DiarioPdfCover(diario: diario, publico: publico),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.42),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            // La fecha real si ya está confirmada; si no, el mes.
                            switch (diario.fechaEdicion) {
                              final fecha? => '${fechaCortaDiario(fecha)} ${fecha.year}',
                              null => '$mes ${diario.anio}',
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!hasPdf)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Center(
                            child: Text(
                              'PDF no disponible',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (hasPdf)
                      const Positioned(
                        right: 10,
                        bottom: 10,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.visibility, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            diario.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portada de un diario, con las cabeceras que correspondan a su origen.
///
/// Pública porque también la dibuja el aviso del diario del día: la portada
/// privada lleva credenciales y la pública no puede llevarlas, y esa decisión
/// tiene que vivir en un solo lugar.
class DiarioPdfCover extends StatelessWidget {
  const DiarioPdfCover({super.key, required this.diario, this.publico = false});

  final DiarioDigitalModel diario;
  final bool publico;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!diario.hasCover) {
      return _DiarioCoverPlaceholder(colorScheme: colorScheme);
    }

    final coverUrl = _DiarioNetwork.resolveUrl(diario.coverUrl);

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: FutureBuilder<Map<String, String>>(
        future: _DiarioNetwork.headersPara(coverUrl, publico: publico),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _DiarioCoverPlaceholder(colorScheme: colorScheme);
          }

          return LayoutBuilder(
            builder: (context, constraints) => Image.network(
              coverUrl,
              key: ValueKey(coverUrl),
              fit: BoxFit.cover,
              headers: snapshot.data ?? const {},
              // La portada es una celda de la grilla, no una página a tamaño
              // real: se mide acá porque el ancho depende de cuántas columnas
              // entren, y a ojo se quedaría corto o de más.
              cacheWidth: anchoDeDecodificacion(
                context,
                constraints.hasBoundedWidth ? constraints.maxWidth : null,
              ),
              errorBuilder: (_, __, ___) =>
                  _DiarioCoverPlaceholder(colorScheme: colorScheme),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes == null
                        ? null
                        : loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DiarioCoverPlaceholder extends StatelessWidget {
  const _DiarioCoverPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.70),
            colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Icon(
        Icons.picture_as_pdf_outlined,
        size: 54,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _FiltrosDiarios extends StatelessWidget {
  const _FiltrosDiarios({
    required this.anios,
    required this.meses,
    required this.anioSeleccionado,
    required this.mesSeleccionado,
    required this.loading,
    required this.onAnioChanged,
    required this.onMesChanged,
    required this.onBuscar,
  });

  final List<int> anios;
  final Map<int, String> meses;
  final int anioSeleccionado;
  final int mesSeleccionado;
  final bool loading;
  final ValueChanged<int?> onAnioChanged;
  final ValueChanged<int?> onMesChanged;
  final VoidCallback onBuscar;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buscar diarios por fecha',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: anioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        anios
                            .map(
                              (anio) => DropdownMenuItem<int>(
                                value: anio,
                                child: Text(anio.toString()),
                              ),
                            )
                            .toList(),
                    onChanged: loading ? null : onAnioChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: mesSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        meses.entries
                            .map(
                              (mes) => DropdownMenuItem<int>(
                                value: mes.key,
                                child: Text(mes.value),
                              ),
                            )
                            .toList(),
                    onChanged: loading ? null : onMesChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onBuscar,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiarioNetwork {
  static String resolveUrl(String value) {
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final baseUri = Uri.parse(apiUrl);
    final origin = '${baseUri.scheme}://${baseUri.authority}';

    if (value.startsWith('/')) return '$origin$value';

    return baseUri.resolve(value).toString();
  }

  /// Cabeceras para bajar la portada o el PDF de un diario.
  ///
  /// Quién puede llevar credenciales lo decide [diarioAceptaCredenciales].
  static Future<Map<String, String>> headersPara(
    String url, {
    required bool publico,
  }) async {
    if (!diarioAceptaCredenciales(url, publico: publico)) {
      return const {'Accept': '*/*'};
    }

    return _privateHeaders();
  }

  /// Si la sesión ya no sirve se lanza [SessionExpiredException] y lo resuelve
  /// el `FutureBuilder` que envuelve al visor: antes esto llamaba a
  /// `expireAndRedirect` y vaciaba la pila de navegación desde dentro de un
  /// `build`, así que perder el token mientras se cargaba una portada sacaba al
  /// usuario de la pantalla sin explicación.
  static Future<Map<String, String>> _privateHeaders() async {
    final token =
        await SessionService.getValidToken(expulsarSiFalla: false) ?? '';
    if (token.isEmpty) {
      throw const SessionExpiredException();
    }

    final sessionCookie =
        await SessionService.getSessionCookie(expulsarSiFalla: false) ?? '';

    return {
      'Accept': '*/*',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (sessionCookie.isNotEmpty) 'Cookie': sessionCookie,
    };
  }
}

/// Abre el visor de un diario, con el interstitial de diarios delante cuando al
/// usuario le tocan anuncios.
///
/// Lo usan la pestaña de diarios y el aviso del diario del día, para que las
/// dos entradas cuenten las aperturas en el mismo lugar. El navegador se recibe
/// ya tomado porque el interstitial se lleva la pantalla, y el `context` de
/// quien llamó puede no seguir montado cuando el anuncio se cierra.
void abrirDiarioDigital(
  NavigatorState navigator,
  DiarioDigitalModel diario, {
  required bool conAnuncio,
  bool publico = false,
}) {
  void abrir() {
    if (!navigator.mounted) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(diario: diario, publico: publico),
      ),
    );
  }

  if (!conAnuncio) {
    abrir();
    return;
  }

  InterstitialAdsService.diarios.registrarAperturaYContinuar(abrir);
}

/// El aviso cuando la firma de la edición del día venció y no se pudo renovar.
void mostrarErrorAlAbrirEdicionDelDia(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'No pudimos abrir la edición del día. Revisa tu conexión e '
        'intenta nuevamente.',
      ),
    ),
  );
}

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.diario,
    this.publico = false,
  });

  final DiarioDigitalModel diario;

  /// La edición del día, legible sin cuenta. Su URL viene firmada por S3 y
  /// adjuntarle el Bearer la invalidaría.
  final bool publico;

  @override
  Widget build(BuildContext context) {
    final url = _DiarioNetwork.resolveUrl(diario.pdfViewerUrl);

    return Scaffold(
      appBar: AppBar(title: Text(diario.titulo)),
      body: FutureBuilder<Map<String, String>>(
        future: _DiarioNetwork.headersPara(url, publico: publico),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudo validar la sesión para abrir el PDF.'),
            );
          }

          return SfPdfViewer.network(url, headers: snapshot.data ?? const {});
        },
      ),
    );
  }
}


class _SubscriptionUpsellCard extends StatelessWidget {
  const _SubscriptionUpsellCard({required this.onVerPaquetes});

  final VoidCallback onVerPaquetes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Suscripción requerida',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Para abrir estos diarios necesitas una suscripción activa. Revisa el estado de tu cuenta desde el sitio web.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onVerPaquetes,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Gestionar mi cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
