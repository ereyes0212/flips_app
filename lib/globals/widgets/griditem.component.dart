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
    
  });

  final IconData icono;
  final Function() funcion;
  final String texto;
  final double? height;
  final Color? color;
  final Color? colorContainer;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: funcion,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
            color: colorContainer ?? tema.surface,
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8.7, spreadRadius: -5)
            ],
            borderRadius: const BorderRadius.all(Radius.circular(4))),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Center(
          child: Row(
            children: [
              const Expanded(flex: 1, child: SizedBox()),
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, color: color ?? tema.primary, size: 35),
                    TextSecundario(
                        texto: texto,
                        colorTexto: tema.onSurface,
                        textAlign: TextAlign.left),
                  ],
                ),
              ),
              const Expanded(flex: 1, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}
