import 'package:flutter/material.dart';

import '../../helpers/helpers.dart';
import '../../models/models.dart';

class DiarioCardWidget extends StatelessWidget {
  const DiarioCardWidget({super.key, required this.diario, required this.onTap});

  final DiarioModel diario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(diario.portadaUrl, width: 48, fit: BoxFit.cover),
        ),
        title: Text(diario.titulo),
        subtitle: Text(DateHelper.formatoLargo(diario.fecha)),
      ),
    );
  }
}
