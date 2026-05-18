import 'dart:async';

import 'package:flips_app/controllers/noticias.controller.dart';
import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  final _controller = NoticiasController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarNoticias(context));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _buscar(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _controller.cargarNoticias(context, busqueda: value.trim());
    });
  }

  Future<void> _refrescar() {
    return _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticiasProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 150,
              title: const Text('Noticias'),
              flexibleSpace: FlexibleSpaceBar(
                background: _NoticiasHeader(
                  total: provider.noticias.length,
                  usingCache: provider.usingCache,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _SearchBar(
                  controller: _searchController,
                  loading: provider.loading,
                  onChanged: _buscar,
                  onSubmitted: (value) => _controller.cargarNoticias(
                    context,
                    busqueda: value.trim(),
                  ),
                  onClear: () {
                    _searchController.clear();
                    _controller.cargarNoticias(context);
                  },
                ),
              ),
            ),
            if (provider.loading && provider.noticias.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage.isNotEmpty && provider.noticias.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'No pudimos cargar las noticias',
                  message: provider.errorMessage,
                ),
              )
            else if (provider.noticias.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.search_off_outlined,
                  title: 'Sin resultados',
                  message: 'Intenta con otra palabra clave para encontrar noticias.',
                ),
              )
            else ...[
              if (provider.errorMessage.isNotEmpty || provider.usingCache)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: _StatusBanner(
                      text: provider.usingCache
                          ? 'Mostrando noticias guardadas mientras vuelve la conexión.'
                          : provider.errorMessage,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _PortadaCard(noticia: provider.noticias.first),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        'Últimas noticias',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (provider.loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 14);
                      }
                      final item = provider.noticias[index ~/ 2];
                      return _NoticiaCard(noticia: item);
                    },
                    childCount: provider.noticias.length * 2 - 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoticiasHeader extends StatelessWidget {
  const _NoticiasHeader({required this.total, required this.usingCache});

  final int total;
  final bool usingCache;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diario Tiempo HN',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Información actualizada desde WordPress',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                    ),
                  ],
                ),
              ),
              _HeaderChip(
                icon: usingCache ? Icons.offline_bolt_outlined : Icons.article_outlined,
                label: usingCache ? 'Caché' : '$total notas',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: 'Buscar noticias, temas o palabras clave',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? (loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null)
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
      },
    );
  }
}

class _PortadaCard extends StatelessWidget {
  const _PortadaCard({required this.noticia});

  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _abrirDetalle(context, noticia),
      child: Container(
        height: 310,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NewsImage(
              url: noticia.imageUrl,
              iconSize: 64,
              borderRadius: BorderRadius.zero,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge(text: 'Portada principal'),
                  const SizedBox(height: 12),
                  Text(
                    noticia.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    noticia.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DateLabel(date: noticia.date, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticiaCard extends StatelessWidget {
  const _NoticiaCard({required this.noticia});

  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _abrirDetalle(context, noticia),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NewsImage(url: noticia.imageUrl, size: 112),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _DateLabel(date: noticia.date),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      noticia.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      noticia.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticiaDetalleScreen extends StatelessWidget {
  const _NoticiaDetalleScreen({required this.noticia});

  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            title: Text(
              noticia.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _NewsImage(
                    url: noticia.imageUrl,
                    iconSize: 72,
                    borderRadius: BorderRadius.zero,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge(text: 'Noticia completa'),
                  const SizedBox(height: 14),
                  Text(
                    noticia.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateLabel(date: noticia.date),
                  const SizedBox(height: 20),
                  if (noticia.excerpt.isNotEmpty) ...[
                    Text(
                      noticia.excerpt,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Divider(height: 28),
                  Text(
                    noticia.content.isNotEmpty
                        ? noticia.content
                        : 'Esta noticia no incluye contenido disponible desde la API.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsImage extends StatelessWidget {
  const _NewsImage({
    required this.url,
    this.size,
    this.iconSize = 36,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final String url;
  final double? size;
  final double iconSize;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.article_outlined,
        size: iconSize,
        color: colorScheme.primary,
      ),
    );

    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          );
        },
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date, this.color});

  final DateTime? date;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final textColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_outlined, size: 14, color: textColor),
        const SizedBox(width: 6),
        Text(
          DateFormat('dd/MM/yyyy').format(date!),
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.error.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: themeText(context))),
        ],
      ),
    );
  }

  TextStyle? themeText(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w700,
        );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 58, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

void _abrirDetalle(BuildContext context, NoticiaModel noticia) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _NoticiaDetalleScreen(noticia: noticia)),
  );
}
