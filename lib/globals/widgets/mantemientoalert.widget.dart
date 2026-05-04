import 'package:flutter/material.dart';
import 'textsecundario.widget.dart';

void alertMantenimiento(BuildContext context,
    {String mensaje = 'Este apartado se encuenta en desarrollo'}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final tema = Theme.of(context).colorScheme;
      Size size = MediaQuery.of(context).size;
      return AlertDialog(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                      padding:
                          EdgeInsets.symmetric(vertical: size.height * 0.02),
                      decoration: BoxDecoration(
                          color: tema.primary,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4))),
                      child: Icon(Icons.manage_history_rounded,
                          size: size.height * 0.1, color: tema.onPrimary)),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.03,
                vertical: 13
              ),
              child: TextSecundario(
                texto: mensaje,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
            ),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}