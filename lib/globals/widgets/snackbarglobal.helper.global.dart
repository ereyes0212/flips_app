
import 'package:flips_app/constants.dart';
import 'package:flutter/material.dart';



snackbarGlobal(String texto, {Color? color = Colors.red}) {
  final snackBar = SnackBar(
    duration: const Duration(seconds: 1),
    content: Text(texto),
    backgroundColor: color,
  );
  snackbarKey.currentState?.showSnackBar(snackBar);
}
