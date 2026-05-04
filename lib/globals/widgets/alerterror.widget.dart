import 'package:flutter/material.dart';

void alertError(BuildContext context,
    {String mensaje =
        'Ocurrio un error al realizar esta acción, intente de nuevo.'}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final tema = Theme.of(context).colorScheme;
      return AlertDialog(
        backgroundColor: tema.surface,
        content: Text(
          mensaje,
          style: TextStyle(fontSize: 18, color: tema.onSurface),
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
            ),
            child: Text('Aceptar', style: TextStyle(color: tema.onPrimary)),
          ),
        ],
      );
    },
  );
}
