
import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future traerToken(context) async{
  const storage = FlutterSecureStorage();

  final token = await storage.read(key: 'token');
  if (token != null) {
    return token;
  }
  // logo(usuario, password, context)
  AuthController().logoutController(context);
  return '';
}