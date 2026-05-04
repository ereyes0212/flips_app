class AppException implements Exception {
  const AppException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => 'AppException(statusCode: $statusCode, message: $message, details: $details)';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.statusCode, super.details});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.statusCode, super.details});
}
