import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flips_app/services/session.service.dart';
import 'package:http/http.dart' as http;

class HttpService {
  final Duration timeout;

  HttpService({this.timeout = const Duration(seconds: 20)});

  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final allHeaders = await _headersWithToken(
      headers,
      useJson: false,
      includeAuth: includeAuth,
    );
    return _request(
      () => http.get(Uri.parse(url), headers: allHeaders),
      enforceAuthErrors: includeAuth,
    );
  }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final allHeaders = await _headersWithToken(
      headers,
      useJson: true,
      includeAuth: includeAuth,
    );
    return _request(
      () => http.post(
        Uri.parse(url),
        headers: allHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
      enforceAuthErrors: includeAuth,
    );
  }

  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final allHeaders = await _headersWithToken(
      headers,
      useJson: true,
      includeAuth: includeAuth,
    );
    return _request(
      () => http.put(
        Uri.parse(url),
        headers: allHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
      enforceAuthErrors: includeAuth,
    );
  }

  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final allHeaders = await _headersWithToken(
      headers,
      useJson: true,
      includeAuth: includeAuth,
    );
    return _request(
      () => http.delete(
        Uri.parse(url),
        headers: allHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
      enforceAuthErrors: includeAuth,
    );
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request, {
    required bool enforceAuthErrors,
  }) async {
    try {
      final response = await request().timeout(timeout);
      if (enforceAuthErrors &&
          (response.statusCode == 401 || response.statusCode == 403)) {
        await SessionService.expireAndRedirect(
          message: 'Tu sesión expiró. Inicia sesión nuevamente.',
        );
        throw const SessionExpiredException();
      }
      return response;
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    }
  }

  Future<Map<String, String>> _headersWithToken(
    Map<String, String>? headers, {
    required bool useJson,
    required bool includeAuth,
  }) async {
    final token = includeAuth ? await SessionService.getValidToken() ?? '' : '';
    if (includeAuth && token.isEmpty) {
      await SessionService.expireAndRedirect(
        message: 'Tu sesión expiró. Inicia sesión nuevamente.',
      );
      throw const SessionExpiredException();
    }
    final allHeaders = {
      'Accept': 'application/json',
      if (useJson) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    return allHeaders;
  }
}
