import 'package:flutter/material.dart';

import 'widgets.dart';

class ParteAbajoCustomAppBar extends StatelessWidget {
  const ParteAbajoCustomAppBar({
    super.key,
    required this.tema,
    required this.size,
    required this.widget,
  });

  final ColorScheme tema;
  final Size size;
  final Widget widget;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            decoration: BoxDecoration(color: tema.secondary),
            padding: EdgeInsets.only(bottom: size.height * 0.02),
            child: widget),
        Stack(
          children: [
            Container(
              height: size.height * 0.02,
              decoration: BoxDecoration(
                color: tema.secondary,
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              child: Container(
                height: size.height * 0.023,
                decoration: BoxDecoration(
                  color: tema.surface,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ItemAbajo extends StatelessWidget {
  const ItemAbajo({
    super.key,
    required this.contenido,
    required this.label,
  });
  final String contenido;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    return Column(
      children: [
        TextPrincipal(
          texto: contenido,
          colorTexto: tema.onPrimary,
        ),
        TextParrafo(
          texto: label,
          colorTexto: tema.primary,
          fontWeight: FontWeight.bold,
        )
      ],
    );
  }
}
