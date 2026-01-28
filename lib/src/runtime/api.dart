import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple static API class for HTTP requests.
///
/// Usage:
/// ```dart
/// // Configure once
/// Api.configure(baseUrl: 'https://api.example.com');
///
/// // Use anywhere
/// final posts = await Api.get('/posts');
/// final post = await Api.post('/posts', body: {'title': 'Hello'});
/// ```
class Api {
  static String _baseUrl = '/api';
  static Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };
  static void Function(Object error)? _onError;

  /// Configure the API client.
  static void configure({
    String? baseUrl,
    Map<String, String>? headers,
    void Function(Object error)? onError,
  }) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (headers != null) _defaultHeaders.addAll(headers);
    if (onError != null) _onError = onError;
  }

  /// Set authorization header.
  static void setAuth(String token, {String type = 'Bearer'}) {
    _defaultHeaders['Authorization'] = '$type $token';
  }

  /// Clear authorization header.
  static void clearAuth() {
    _defaultHeaders.remove('Authorization');
  }

  /// GET request.
  static Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final response = await http.get(
      uri,
      headers: {..._defaultHeaders, ...?headers},
    );

    return _handleResponse(response);
  }

  /// POST request.
  static Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {..._defaultHeaders, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );

    return _handleResponse(response);
  }

  /// PUT request.
  static Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: {..._defaultHeaders, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );

    return _handleResponse(response);
  }

  /// PATCH request.
  static Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: {..._defaultHeaders, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );

    return _handleResponse(response);
  }

  /// DELETE request.
  static Future<dynamic> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: {..._defaultHeaders, ...?headers},
    );

    return _handleResponse(response);
  }

  /// Handle response and errors.
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    final error = ApiException(
      statusCode: response.statusCode,
      message: response.reasonPhrase ?? 'Request failed',
      body: response.body.isNotEmpty ? jsonDecode(response.body) : null,
    );

    _onError?.call(error);
    throw error;
  }
}

/// API exception with status code and response body.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;

  ApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() => 'ApiException: $statusCode $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
}
