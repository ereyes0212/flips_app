import 'package:android_id/android_id.dart';

Future<String?> getDeviceId() async => const AndroidId().getId();
