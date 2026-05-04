import 'dart:developer' as dev;

class AppLogger {
  static void info(String message) => dev.log(message, name: 'FLIPS');
  static void error(String message, [Object? error]) =>
      dev.log(message, name: 'FLIPS', error: error);
}
