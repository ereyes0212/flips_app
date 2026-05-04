import 'package:intl/intl.dart';

class DateHelper {
  static String formatoLargo(DateTime date) => DateFormat('dd MMMM yyyy', 'es').format(date);
}
