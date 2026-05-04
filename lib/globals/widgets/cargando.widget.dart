import 'package:flutter/material.dart';

class CargandoWidget extends StatelessWidget {
  const CargandoWidget({
    super.key,
    required this.size,
    required this.conColor,
  });

  final Size size;
  final bool conColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      color: conColor ? Colors.black26 : Colors.transparent,
      child: Center(
        child: SizedBox(
            height: size.height * 0.02,
            width: size.width * 0.8,
            child: const LinearProgressIndicator()),
      ),
    );
  }
}
