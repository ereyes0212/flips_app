import 'package:dio/dio.dart';
import '../errors/app_exception.dart';

class ApiErrorHandler {
  static AppException map(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkException('Tiempo de espera agotado');
    }
    if (e.type == DioExceptionType.cancel) {
      return const NetworkException('Solicitud cancelada');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkException('Sin conexión de red');
    }

    final status = e.response?.statusCode;
    switch (status) {
      case 400:
        return AppException('Solicitud inválida', statusCode: status, details: e.response?.data);
      case 401:
        return UnauthorizedException('No autorizado', statusCode: status);
      case 403:
        return AppException('Acceso denegado', statusCode: status);
      case 404:
        return AppException('Recurso no encontrado', statusCode: status);
      case 409:
        return AppException('Conflicto de datos', statusCode: status);
      case 500:
        return AppException('Error interno del servidor', statusCode: status);
      default:
        return AppException('Error inesperado', statusCode: status, details: e.response?.data);
    }
  }
}
