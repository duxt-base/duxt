import 'dart:convert';

/// Base class for API route handlers
/// Handles HTTP methods for server-side API routes
abstract class ApiHandler {
  /// Handle GET requests
  Future<ApiResponse> get(ApiRequest request) async {
    return ApiResponse.methodNotAllowed();
  }

  /// Handle POST requests
  Future<ApiResponse> post(ApiRequest request) async {
    return ApiResponse.methodNotAllowed();
  }

  /// Handle PUT requests
  Future<ApiResponse> put(ApiRequest request) async {
    return ApiResponse.methodNotAllowed();
  }

  /// Handle DELETE requests
  Future<ApiResponse> delete(ApiRequest request) async {
    return ApiResponse.methodNotAllowed();
  }

  /// Handle PATCH requests
  Future<ApiResponse> patch(ApiRequest request) async {
    return ApiResponse.methodNotAllowed();
  }

  /// Handle any method (catch-all)
  Future<ApiResponse> handler(ApiRequest request) async {
    switch (request.method) {
      case 'GET':
        return get(request);
      case 'POST':
        return post(request);
      case 'PUT':
        return put(request);
      case 'DELETE':
        return delete(request);
      case 'PATCH':
        return patch(request);
      default:
        return ApiResponse.methodNotAllowed();
    }
  }
}

/// Incoming API request
class ApiRequest {
  final String method;
  final String path;
  final Map<String, String> params;
  final Map<String, String> query;
  final Map<String, String> headers;
  final String? body;

  ApiRequest({
    required this.method,
    required this.path,
    this.params = const {},
    this.query = const {},
    this.headers = const {},
    this.body,
  });

  /// Parse body as JSON
  dynamic get json {
    if (body == null || body!.isEmpty) return null;
    return jsonDecode(body!);
  }

  /// Get a specific query parameter
  String? getQuery(String key) => query[key];

  /// Get a specific path parameter
  String? getParam(String key) => params[key];

  /// Get a specific header
  String? getHeader(String key) => headers[key.toLowerCase()];
}

/// API response
class ApiResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  ApiResponse({
    required this.statusCode,
    this.data,
    this.headers = const {},
  });

  /// Success response with JSON data
  factory ApiResponse.json(dynamic data, {int statusCode = 200}) {
    return ApiResponse(
      statusCode: statusCode,
      data: data,
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Success response
  factory ApiResponse.ok([dynamic data]) {
    return ApiResponse.json(data ?? {'success': true});
  }

  /// Created response (201)
  factory ApiResponse.created([dynamic data]) {
    return ApiResponse.json(data ?? {'success': true}, statusCode: 201);
  }

  /// No content response (204)
  factory ApiResponse.noContent() {
    return ApiResponse(statusCode: 204);
  }

  /// Bad request response (400)
  factory ApiResponse.badRequest([String? message]) {
    return ApiResponse.json(
      {'error': message ?? 'Bad request'},
      statusCode: 400,
    );
  }

  /// Unauthorized response (401)
  factory ApiResponse.unauthorized([String? message]) {
    return ApiResponse.json(
      {'error': message ?? 'Unauthorized'},
      statusCode: 401,
    );
  }

  /// Forbidden response (403)
  factory ApiResponse.forbidden([String? message]) {
    return ApiResponse.json(
      {'error': message ?? 'Forbidden'},
      statusCode: 403,
    );
  }

  /// Not found response (404)
  factory ApiResponse.notFound([String? message]) {
    return ApiResponse.json(
      {'error': message ?? 'Not found'},
      statusCode: 404,
    );
  }

  /// Method not allowed response (405)
  factory ApiResponse.methodNotAllowed() {
    return ApiResponse.json(
      {'error': 'Method not allowed'},
      statusCode: 405,
    );
  }

  /// Internal server error response (500)
  factory ApiResponse.error([String? message]) {
    return ApiResponse.json(
      {'error': message ?? 'Internal server error'},
      statusCode: 500,
    );
  }

  /// Redirect response
  factory ApiResponse.redirect(String location, {bool permanent = false}) {
    return ApiResponse(
      statusCode: permanent ? 301 : 302,
      headers: {'Location': location},
    );
  }

  /// Convert to JSON string
  String toJson() {
    if (data == null) return '';
    return jsonEncode(data);
  }
}

/// Define an event handler (for API routes)
typedef EventHandler = Future<ApiResponse> Function(ApiRequest request);

/// Create an event handler
EventHandler defineEventHandler(EventHandler handler) => handler;

/// Read body as JSON
Future<dynamic> readBody(ApiRequest request) async {
  return request.json;
}

/// Get query parameters
Map<String, String> getQuery(ApiRequest request) => request.query;

/// Get a single query parameter
String? getQueryParam(ApiRequest request, String key) => request.query[key];

/// Get route parameters
Map<String, String> getRouteParams(ApiRequest request) => request.params;

/// Send a redirect
ApiResponse sendRedirect(String location, {int statusCode = 302}) {
  return ApiResponse(
    statusCode: statusCode,
    headers: {'Location': location},
  );
}

/// Send an error
ApiResponse sendError(int statusCode, String message) {
  return ApiResponse.json({'error': message}, statusCode: statusCode);
}

/// Set response header
ApiResponse setHeader(ApiResponse response, String name, String value) {
  final newHeaders = Map<String, String>.from(response.headers);
  newHeaders[name] = value;
  return ApiResponse(
    statusCode: response.statusCode,
    data: response.data,
    headers: newHeaders,
  );
}
