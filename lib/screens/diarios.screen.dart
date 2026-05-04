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
  DateTime? _selectedDate;

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
            onPressed: () async {
              final result = await showBoardDateTimePicker(
                context: context,
                pickerType: DateTimePickerType.date,
              );
              if (result != null) {
                setState(() => _selectedDate = result);
              }
            },
          )
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedDate != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: const Icon(Icons.event_available, size: 18),
                        label: Text('Fecha: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                        onDeleted: () => setState(() => _selectedDate = null),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
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
                ),
              ],
            ),
    );
  }
}
