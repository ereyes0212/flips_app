import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'api_error_handler.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({required TokenStorage tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'http://192.168.2.20:3000',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          AppLogger.info('[REQ] ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.info('[RES] ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) async {
          final shouldRetry = _isRetryable(error) &&
              (error.requestOptions.extra['retryCount'] ?? 0) < 2;
          if (shouldRetry) {
            final retryCount = (error.requestOptions.extra['retryCount'] ?? 0) + 1;
            error.requestOptions.extra['retryCount'] = retryCount;
            await Future<void>.delayed(Duration(milliseconds: (300 * retryCount).toInt()));
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (_) {}
          }
          AppLogger.error('[ERR] ${error.requestOptions.path}', error);
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              error: ApiErrorHandler.map(error),
              type: error.type,
            ),
          );
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  bool _isRetryable(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.response?.statusCode == 500;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);
  Future<Response<T>> post<T>(String path, {Object? data}) => _dio.post<T>(path, data: data);
  Future<Response<T>> patch<T>(String path, {Object? data}) => _dio.patch<T>(path, data: data);
  Future<Response<T>> put<T>(String path, {Object? data}) => _dio.put<T>(path, data: data);
}
