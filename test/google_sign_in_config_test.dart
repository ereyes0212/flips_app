import 'package:flips_app/config/google_sign_in.config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Estos tests corren sin `--dart-define`, así que comprueban justo el caso
/// que rompía: un build donde la bandera se olvidó.
void main() {
  group('GoogleSignInConfig sin --dart-define', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('el Web Client ID cae al valor por defecto', () {
      expect(GoogleSignInConfig.webClientId, isNotEmpty);
      expect(
        GoogleSignInConfig.webClientId,
        '374905649903-tatkk8u7keo8r0aq8580k1kqeiotvvc8.apps.googleusercontent.com',
      );
    });

    test('el iOS Client ID cae al valor por defecto', () {
      expect(
        GoogleSignInConfig.iosClientId,
        '374905649903-t8toeo9bp074mlm9qv69tbc00qco5rki.apps.googleusercontent.com',
      );
    });

    test('serverClientId nunca queda nulo en un build sin la bandera', () {
      expect(GoogleSignInConfig.serverClientId, isNotNull);
    });

    test('Android no reporta configuración faltante', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(GoogleSignInConfig.missingConfigurationMessage, isNull);
    });

    test('iOS no reporta configuración faltante', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(GoogleSignInConfig.missingConfigurationMessage, isNull);
    });

    test('en Android no se manda clientId, solo serverClientId', () {
      // Android identifica la app por paquete + SHA-1, no por client ID.
      // Mandar uno hace que el plugin falle.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(GoogleSignInConfig.clientId, isNull);
    });

    test('en iOS sí se manda el clientId', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(GoogleSignInConfig.clientId, GoogleSignInConfig.iosClientId);
    });
  });
}
