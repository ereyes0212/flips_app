import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccesoUsuario', () {
    test('sin resolver no pide anuncios ni habilita el modo offline', () {
      const acceso = AccesoUsuario.sinResolver();

      expect(acceso.resuelto, isFalse);
      expect(acceso.mostrarAnuncios, isFalse);
      expect(acceso.puedeLeerOffline, isFalse);
    });

    test('una cuenta gratis resuelta sí ve anuncios', () {
      const acceso = AccesoUsuario(
        esAdmin: false,
        tieneSuscripcionActiva: false,
      );

      expect(acceso.mostrarAnuncios, isTrue);
      expect(acceso.puedeLeerOffline, isFalse);
    });

    test('un suscriptor no ve anuncios y lee sin conexión', () {
      const acceso = AccesoUsuario(
        esAdmin: false,
        tieneSuscripcionActiva: true,
      );

      expect(acceso.mostrarAnuncios, isFalse);
      expect(acceso.puedeLeerOffline, isTrue);
    });

    test('un admin sin suscripción tampoco ve anuncios', () {
      const acceso = AccesoUsuario(
        esAdmin: true,
        tieneSuscripcionActiva: false,
      );

      expect(acceso.mostrarAnuncios, isFalse);
      expect(acceso.puedeLeerOffline, isTrue);
    });

    test('las dos políticas se leen por separado', () {
      // Coinciden hoy, pero son getters distintos justamente para que cambiar
      // una regla no arrastre la otra sin querer.
      const suscriptor = AccesoUsuario(
        esAdmin: false,
        tieneSuscripcionActiva: true,
      );

      expect(suscriptor.ocultarAnuncios, isTrue);
      expect(suscriptor.puedeLeerOffline, isTrue);
    });

    test('sin privilegios cuenta como resuelto', () {
      const acceso = AccesoUsuario.sinPrivilegios();

      expect(acceso.resuelto, isTrue);
      expect(acceso.mostrarAnuncios, isTrue);
    });

    test('la igualdad distingue el estado sin resolver', () {
      expect(
        const AccesoUsuario.sinResolver(),
        isNot(const AccesoUsuario.sinPrivilegios()),
      );
      expect(
        const AccesoUsuario(esAdmin: true, tieneSuscripcionActiva: false),
        const AccesoUsuario(esAdmin: true, tieneSuscripcionActiva: false),
      );
    });
  });
}
