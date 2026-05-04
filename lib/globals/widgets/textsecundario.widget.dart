import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextSecundario extends StatelessWidget {
  const TextSecundario({
    super.key,
    required this.texto,
    this.colorTexto = Colors.black54,
    this.textAlign = TextAlign.center,
  });

  final String texto;
  final Color? colorTexto;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(texto,
        textAlign: textAlign,
        softWrap: true,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, fontSize: 15, color: colorTexto));
  }
}
