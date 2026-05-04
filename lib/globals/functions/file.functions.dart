import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> temporaryPdfPath(String fileName) async {
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/$fileName').path;
}
