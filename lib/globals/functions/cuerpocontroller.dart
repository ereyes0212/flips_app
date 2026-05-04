import '../widgets/widgets.dart';

class CuerpoDeController {
  cuerpoNormal(
    context, {
    required String mensajeError,
    required int codRespuesta,
    Function()? funcion400,
    Function()? funcion401,
    Function()? funcion404,
    Function()? funcion409,
    Function()? funcion500,
    Function()? funcion1200,
    Function()? funcion4500,
    Function()? funcion4501,
    Function()? funcionFinal,
  }) async {
    switch (codRespuesta) {
      case 400:
        alertError(context,
            mensaje: 'Error en los parametros al $mensajeError.');
        funcion400?.call();
        break;
      case 401:
        globalSnackBar('Por favor inicie sesión para realizar esta acción');
        funcion401?.call();
        break;
      case 409:
        funcion409?.call();
        break;
      case 404:
        funcion404?.call();
        break;
      case 500:
        alertError(context,
            mensaje:
                'Ocurrió un error interno en el servidor al $mensajeError, contacte con soporte técnico.');
        funcion500?.call();
        break;
      case 1200:
        alertError(context, mensaje: 'Ocurrió un error al $mensajeError.');
        funcion1200?.call();
        break;
      case 4501:
        alertError(context,
            mensaje:
                'Ocurrió un error al $mensajeError, verifique si:  tiene conexión a internet, los datos móviles o el wifi están activados, se encuentra conectado a una red interna sin acceso al servidor.');
        funcion4501?.call();
        break;
      default:
    }
    funcionFinal?.call();
  }
}
