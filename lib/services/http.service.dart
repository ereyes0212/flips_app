import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class HttpService {
  final Duration timeout;

  HttpService({this.timeout = const Duration(seconds: 20)});

  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final allHeaders = await _headersWithToken(headers, useJson: false);
    return _request(() => http.get(Uri.parse(url), headers: allHeaders));
  }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final allHeaders = await _headersWithToken(headers, useJson: true);
    return _request(
      () => http.post(
        Uri.parse(url),
        headers: allHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final allHeaders = await _headersWithToken(headers, useJson: true);
    return _request(
      () => http.put(
        Uri.parse(url),
        headers: allHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final allHeaders = await _headersWithToken(headers, useJson: true);
    return _request(
      () => http.delete(
        Uri.parse(url),
        headers: allHeaders,
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

  Future<Map<String, String>> _headersWithToken(
    Map<String, String>? headers, {
    required bool useJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return {
      if (useJson) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };
  }
}
