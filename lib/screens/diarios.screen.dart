import 'package:board_datetime_picker/board_datetime_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals/widgets/widgets.dart';
import '../providers/providers.dart';
import 'screens.dart';

class DiariosScreen extends StatefulWidget {
  const DiariosScreen({super.key});

  @override
  State<DiariosScreen> createState() => _DiariosScreenState();
}

class _DiariosScreenState extends State<DiariosScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<NewspapersProvider>().loadDiarios());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewspapersProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ediciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => showBoardDateTimePicker(context: context, pickerType: DateTimePickerType.date),
          )
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.diarios.length,
              itemBuilder: (_, i) {
                final diario = provider.diarios[i];
                return DiarioCardWidget(
                  diario: diario,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PdfViewerScreen(diario: diario)),
                  ),
                );
              },
            ),
    );
  }
}
