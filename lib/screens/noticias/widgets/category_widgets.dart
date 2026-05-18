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
