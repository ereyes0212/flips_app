import 'package:flutter/foundation.dart';

class GoogleSignInConfig {
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const scopes = ['email', 'profile'];

  static String? get serverClientId => _emptyToNull(webClientId);

  static String? get clientId {
    if (kIsWeb) return _emptyToNull(webClientId);

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _emptyToNull(iosClientId);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return null;
    }
  }

  static String? get missingConfigurationMessage {
    if (kIsWeb && _emptyToNull(webClientId) == null) {
      return 'Falta configurar GOOGLE_WEB_CLIENT_ID para iniciar sesión con Google.';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_emptyToNull(webClientId) == null) {
          return 'Falta configurar GOOGLE_WEB_CLIENT_ID. En Android debe ser el OAuth Client ID de tipo Web asociado al paquete y SHA-1/SHA-256 de la app.';
        }
        return null;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (_emptyToNull(iosClientId) == null) {
          return 'Falta configurar GOOGLE_IOS_CLIENT_ID para iniciar sesión con Google en iOS/macOS.';
        }
        return null;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 'Google Sign-In no está configurado para esta plataforma.';
    }
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
