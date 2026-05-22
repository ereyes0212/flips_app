import 'package:flutter/material.dart';

import 'widgets.dart';

class GridItem extends StatelessWidget {
  const GridItem({
    super.key,
    required this.icono,
    required this.funcion,
    required this.texto,
    this.color,
    this.height, 
    this.colorContainer,
    this.subtitulo,
    this.trailing,
  });

  final IconData icono;
  final Function() funcion;
  final String texto;
  final double? height;
  final Color? color;
  final Color? colorContainer;
  final String? subtitulo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: funcion,
      child: Container(
        height: height ?? 86,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: colorContainer ?? tema.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tema.primary.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -6),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: (color ?? tema.primary).withOpacity(0.12),
              child: Icon(icono, color: color ?? tema.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextSecundario(texto: texto, colorTexto: tema.onSurface, textAlign: TextAlign.left),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: TextStyle(color: tema.secondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: tema.primary),
          ],
        ),
      ),
    );
  }
}
