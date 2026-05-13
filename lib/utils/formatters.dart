import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _hnMoneyFormatter = NumberFormat('#,##0.00', 'es_HN');

  static String moneyFromCentavos(int centavos) {
    return 'L ${_hnMoneyFormatter.format(centavos / 100)}';
  }

  static String dateFromIso(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }
}
