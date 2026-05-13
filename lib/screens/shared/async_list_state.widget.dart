import 'package:flutter/material.dart';

class AsyncListState extends StatelessWidget {
  const AsyncListState({
    super.key,
    required this.loading,
    required this.errorMessage,
    required this.isEmpty,
    required this.emptyMessage,
  });

  final bool loading;
  final String errorMessage;
  final bool isEmpty;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage.isNotEmpty) return Text(errorMessage);

    if (isEmpty) return Text(emptyMessage);

    return const SizedBox.shrink();
  }
}
