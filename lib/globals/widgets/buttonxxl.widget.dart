import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ButtonXXL extends StatelessWidget {
  const ButtonXXL({
    super.key,
    required this.funcion,
    required this.texto,
    this.sinMargen = false,
    this.colorFondo,
    this.fontWeight,
    this.colorTexto,
    this.sinMargenVertical,
    this.icono,
  });

  final Function() funcion;
  final String texto;
  final bool? sinMargen;
  final bool? sinMargenVertical;
  final Color? colorFondo;
  final FontWeight? fontWeight;
  final Color? colorTexto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final tema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 50,
      margin: EdgeInsets.symmetric(
          horizontal: (sinMargen!) ? 0 : size.width * 0.04,
          vertical: sinMargen ?? false ? 0 : 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: colorFondo ?? tema.primary),
        onPressed: funcion,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null)
              Padding(
                padding: EdgeInsets.only(right: size.width * 0.01),
                child: Icon(icono),
              ),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontWeight: fontWeight ?? FontWeight.w600, color: colorTexto ?? tema.surface),
            ),
          ],
        ),
      ),
    );
  }
}
