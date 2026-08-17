import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Consentimiento de anuncios (User Messaging Platform).
///
/// La política de consentimiento de Google exige un mensaje para usuarios del
/// EEE y Reino Unido. Fuera de esas regiones el SDK responde que no hace falta
/// formulario y esto no muestra nada ni cuesta nada perceptible.
class AdsConsentService {
  const AdsConsentService._();

  /// Actualiza el estado de consentimiento y muestra el formulario si toca.
  ///
  /// Nunca lanza: si algo falla se sigue adelante y el SDK de anuncios degrada
  /// por su cuenta a anuncios no personalizados. Debe llamarse antes de
  /// inicializar el SDK, que es lo que documenta Google.
  static Future<void> solicitarSiHaceFalta() async {
    try {
      // Solo la consulta de red lleva límite de tiempo: si el formulario llega
      // a mostrarse hay que esperar a que la persona responda.
      await _actualizarEstado().timeout(const Duration(seconds: 5));

      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) {
          debugPrint('Formulario de consentimiento: ${error.message}');
        }
      });
    } catch (error) {
      debugPrint('No se pudo resolver el consentimiento de anuncios: $error');
    }
  }

  static Future<void> _actualizarEstado() {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(StateError(error.message));
        }
      },
    );

    return completer.future;
  }
}
