import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission() async {
  // Comprueba si ya se tiene el permiso
  if (await Permission.storage.isGranted) {
    return true;
  }
  
  // Solicita el permiso al usuario
  final status = await Permission.storage.request();
  
  if (status.isGranted) {
    return true;
  } else {
    // Aquí podrías mostrar un mensaje al usuario explicando la necesidad del permiso
    return false;
  }
}
