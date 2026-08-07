part of '../noticias.screen.dart';

class _CategoryQuickAccess extends StatelessWidget {
  const _CategoryQuickAccess({
    required this.categorias,
    required this.loading,
    required this.onTap,
  });

  final List<CategoriaNoticiaModel> categorias;
  final bool loading;
  final ValueChanged<CategoriaNoticiaModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading && categorias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (categorias.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final categoria = categorias[index];
          return ActionChip(
            avatar: const Icon(Icons.local_offer_outlined, size: 16),
            label: Text(categoria.name),
            onPressed: () => onTap(categoria),
          );
        },
      ),
    );
  }
}

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.categoryIds,
    required this.categoriasPorId,
    required this.onTap,
  });

  final List<int> categoryIds;
  final Map<int, CategoriaNoticiaModel> categoriasPorId;
  final ValueChanged<CategoriaNoticiaModel> onTap;

  @override
  Widget build(BuildContext context) {
    final categorias = categoryIds
        .map((id) => categoriasPorId[id])
        .whereType<CategoriaNoticiaModel>()
        .toList();

    if (categorias.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categorias.map((categoria) {
        return ActionChip(
          avatar: const Icon(Icons.sell_outlined, size: 16),
          label: Text(categoria.name),
          onPressed: () => onTap(categoria),
        );
      }).toList(),
    );
  }
}

class _NewsFilterResult {
  const _NewsFilterResult({this.clearSearch = false});

  final bool clearSearch;
}

class _NewsDiscoveryRail extends StatelessWidget {
  const _NewsDiscoveryRail({
    required this.categorias,
    required this.loadingCategorias,
    required this.hasQuery,
    required this.filtroFecha,
    required this.onOpenFilters,
    required this.onClearDate,
    required this.onTapCategoria,
  });

  final List<CategoriaNoticiaModel> categorias;
  final bool loadingCategorias;
  final bool hasQuery;
  final DateTimeRange? filtroFecha;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearDate;
  final ValueChanged<CategoriaNoticiaModel> onTapCategoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = hasQuery || filtroFecha != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 8),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Badge(
              isLabelVisible: hasFilters,
              smallSize: 9,
              child: IconButton.filled(
                tooltip: 'Buscar y filtrar',
                onPressed: onOpenFilters,
                icon: const Icon(Icons.search_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size.square(42),
                ),
              ),
            ),
            if (filtroFecha != null) ...[
              const SizedBox(width: 8),
              InputChip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  '${DateFormat('dd/MM').format(filtroFecha!.start)} - ${DateFormat('dd/MM').format(filtroFecha!.end)}',
                ),
                onDeleted: onClearDate,
              ),
            ],
            if (loadingCategorias && categorias.isEmpty)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 8, right: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categorias.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final categoria = categorias[index];
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      label: Text(categoria.name),
                      onPressed: () => onTapCategoria(categoria),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewsFilterSheet extends StatelessWidget {
  const _NewsFilterSheet({
    required this.controller,
    required this.filtroFecha,
    required this.onSelectDate,
    required this.onClearDate,
  });

  final TextEditingController controller;
  final DateTimeRange? filtroFecha;
  final Future<void> Function() onSelectDate;
  final Future<void> Function() onClearDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Buscar noticias',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _NoticiasSearchBar(
            controller: controller,
            loading: false,
            onChanged: (_) {},
            onSubmitted: (_) => Navigator.pop(context, const _NewsFilterResult()),
            onClear: () => Navigator.pop(context, const _NewsFilterResult(clearSearch: true)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await onSelectDate();
              if (context.mounted) Navigator.pop(context, const _NewsFilterResult());
            },
            icon: const Icon(Icons.date_range_rounded),
            label: Text(
              filtroFecha == null
                  ? 'Filtrar por fecha'
                  : '${DateFormat('dd/MM/yyyy').format(filtroFecha!.start)} - ${DateFormat('dd/MM/yyyy').format(filtroFecha!.end)}',
            ),
          ),
          if (filtroFecha != null)
            TextButton.icon(
              onPressed: () async {
                await onClearDate();
                if (context.mounted) Navigator.pop(context, const _NewsFilterResult());
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Limpiar fecha'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, const _NewsFilterResult()),
            child: const Text('Aplicar filtros'),
          ),
        ],
      ),
    );
  }
}
