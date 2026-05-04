import 'package:flutter/material.dart';

import 'widgets.dart';

AppBar customAppBar(
    {required ColorScheme tema,
    Function()? funcionAtras,
    required String titulo,
    String? subTitulo,
    Widget? widgetFinal,
    required BuildContext context}) {
  return AppBar(
    backgroundColor: tema.surface,
    elevation: 0,
    leading: IconButton(
        onPressed: () {
          funcionAtras?.call();
          Navigator.pop(context);
        },
        icon: Icon(
          Icons.arrow_back_ios,
          color: tema.primary,
        )),
    titleSpacing: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextSecundario(texto: titulo, colorTexto: tema.primary),
        if (subTitulo != null)
          TextParrafo(
            texto: subTitulo,
            colorTexto: tema.onSurfaceVariant,
          )
      ],
    ),
    actions: [if (widgetFinal != null) widgetFinal],
  );
}
