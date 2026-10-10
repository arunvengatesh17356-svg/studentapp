import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'session.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Thin wrapper around the PHP API. Every method returns the decoded JSON map
/// or throws [ApiException] with the server's `message`.
class Api {
  /// Called when the server answers 401 for a logged-in request.
  static void Function()? onUnauthorized;

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  static Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body ?? <String, dynamic>{}, auth: auth);

  static Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send('PUT', path, body: body ?? <String, dynamic>{});

  static Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  /// Multipart upload (exam answer sheets, question papers).
  /// [fileField] is the form field name, e.g. `files[]` or `question_paper`.
  static Future<Map<String, dynamic>> upload(
    String path, {
    required String fileField,
    required List<UploadFile> files,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    final token = Session.token;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (fields != null) req.fields.addAll(fields);
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes(fileField, f.bytes, filename: f.name));
    }

    http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(minutes: 3));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The upload took too long. Check your connection and try again.');
    } catch (e) {
      throw ApiException('Cannot reach $uri\n\n$e');
    }
    return _handle(res, true);
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
  }) async {
    var uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (query != null) {
      final q = <String, String>{};
      query.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
      });
      if (q.isNotEmpty) uri = uri.replace(queryParameters: q);
    }

    final headers = <String, String>{'Accept': 'application/json'};
    final token = Session.token;
    if (auth && token != null) headers['Authorization'] = 'Bearer $token';
    if (body != null) headers['Content-Type'] = 'application/json';

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } catch (e) {
      throw ApiException('Cannot reach $uri\n\n$e');
    }

    return _handle(res, auth);
  }

  static Future<Map<String, dynamic>> _handle(http.Response res, bool auth) async {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      throw ApiException(
        'Server returned an invalid response (HTTP ${res.statusCode}). '
        'Check the baseUrl in lib/config.dart.',
        res.statusCode,
      );
    }

    if (res.statusCode == 401 && auth && Session.token != null) {
      await Session.clear();
      onUnauthorized?.call();
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException((data['message'] ?? 'Request failed').toString(), res.statusCode);
    }
    return data;
  }
}

/// A file picked on the device, kept in memory so it works on mobile and web.
class UploadFile {
  final String name;
  final List<int> bytes;
  const UploadFile(this.name, this.bytes);
}
