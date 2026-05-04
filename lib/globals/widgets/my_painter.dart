import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyPainter extends CustomPainter {
  final String label;
  Color? color;

  MyPainter({required this.label,  this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();

    paint.color = color ?? Colors.blue;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect rRect =
        RRect.fromRectAndRadius(rect, const Radius.circular(10));

    canvas.drawRRect(rRect, paint);

    // paint.color = Colors.white;

    // canvas.drawCircle(Offset(20, size.height / 2), 10, paint);

    final textPainter = TextPainter(
        text: TextSpan(
            text: label,
            style: GoogleFonts.poppins(fontSize: 31, color: Colors.white)),
        maxLines: 2,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);

    textPainter.layout(maxWidth: size.width, minWidth: 0);
    textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2,
            size.height / 2 - textPainter.size.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
