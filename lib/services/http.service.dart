import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class HttpService {
  final Duration timeout;

  HttpService({this.timeout = const Duration(seconds: 20)});

  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _request(() => http.get(Uri.parse(url), headers: headers));
  }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      () => http.post(
        Uri.parse(url),
        headers: _jsonHeaders(headers),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      () => http.put(
        Uri.parse(url),
        headers: _jsonHeaders(headers),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      () => http.delete(
        Uri.parse(url),
        headers: _jsonHeaders(headers),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> _request(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    }
  }

  Map<String, String> _jsonHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      ...?headers,
    };
  }
}
