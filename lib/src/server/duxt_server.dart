import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import 'api_handler.dart';

/// Duxt Server - Shelf-based HTTP server
class DuxtServer {
  final int port;
  final String apiDir;
  final String? staticDir;
  final List<Middleware> middleware;
  final Map<String, Handler> _routes = {};
  HttpServer? _server;

  DuxtServer({
    this.port = 3000,
    this.apiDir = 'server/api',
    this.staticDir,
    this.middleware = const [],
  });

  /// Register a GET route
  void get(String path, Handler handler) {
    _routes['GET:$path'] = handler;
  }

  /// Register a POST route
  void post(String path, Handler handler) {
    _routes['POST:$path'] = handler;
  }

  /// Register a PUT route
  void put(String path, Handler handler) {
    _routes['PUT:$path'] = handler;
  }

  /// Register a DELETE route
  void delete(String path, Handler handler) {
    _routes['DELETE:$path'] = handler;
  }

  /// Register a PATCH route
  void patch(String path, Handler handler) {
    _routes['PATCH:$path'] = handler;
  }

  /// Register any method
  void all(String path, Handler handler) {
    for (final method in ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']) {
      _routes['$method:$path'] = handler;
    }
  }

  /// Register an API handler class
  void use(String path, ApiHandler handler) {
    get(path, (req) => _handleApi(req, handler.get));
    post(path, (req) => _handleApi(req, handler.post));
    put(path, (req) => _handleApi(req, handler.put));
    delete(path, (req) => _handleApi(req, handler.delete));
    patch(path, (req) => _handleApi(req, handler.patch));
  }

  Future<Response> _handleApi(
    Request request,
    Future<ApiResponse> Function(ApiRequest) handler,
  ) async {
    final body = await request.readAsString();
    final apiRequest = ApiRequest(
      method: request.method,
      path: request.url.path,
      params: {}, // Will be populated by router
      query: request.url.queryParameters,
      headers: request.headers,
      body: body,
    );

    try {
      final apiResponse = await handler(apiRequest);
      return Response(
        apiResponse.statusCode,
        body: apiResponse.toJson(),
        headers: {
          'Content-Type': 'application/json',
          ...apiResponse.headers,
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Main request handler
  Handler get handler {
    return (Request request) async {
      final method = request.method;
      final path = '/${request.url.path}';

      // Try exact match
      final key = '$method:$path';
      if (_routes.containsKey(key)) {
        return _routes[key]!(request);
      }

      // Try pattern matching for dynamic routes
      for (final entry in _routes.entries) {
        final routeKey = entry.key;
        if (!routeKey.startsWith('$method:')) continue;

        final routePath = routeKey.substring(method.length + 1);
        final params = _matchRoute(routePath, path);
        if (params != null) {
          // Add params to request context
          final newRequest = request.change(context: {
            ...request.context,
            'params': params,
          });
          return entry.value(newRequest);
        }
      }

      // Try serving static files if staticDir is set
      if (staticDir != null) {
        final staticHandler = createStaticHandler(
          staticDir!,
          defaultDocument: 'index.html',
        );
        final staticResponse = await staticHandler(request);
        if (staticResponse.statusCode != 404) {
          return staticResponse;
        }
        // For SPA routing, try serving index.html for HTML requests
        if (request.headers['accept']?.contains('text/html') ?? false) {
          final indexFile = File('$staticDir/index.html');
          if (indexFile.existsSync()) {
            return Response.ok(
              indexFile.readAsStringSync(),
              headers: {'Content-Type': 'text/html'},
            );
          }
        }
      }

      return Response.notFound(
        jsonEncode({'error': 'Not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    };
  }

  /// Match route pattern to path
  Map<String, String>? _matchRoute(String pattern, String path) {
    final patternParts = pattern.split('/').where((p) => p.isNotEmpty).toList();
    final pathParts = path.split('/').where((p) => p.isNotEmpty).toList();

    if (patternParts.length != pathParts.length) return null;

    final params = <String, String>{};
    for (var i = 0; i < patternParts.length; i++) {
      final patternPart = patternParts[i];
      final pathPart = pathParts[i];

      if (patternPart.startsWith(':')) {
        params[patternPart.substring(1)] = pathPart;
      } else if (patternPart != pathPart) {
        return null;
      }
    }
    return params;
  }

  /// Build the pipeline with middleware
  Handler get pipeline {
    var h = handler;
    for (final m in middleware.reversed) {
      h = m(h);
    }
    return h;
  }

  /// Start the server
  Future<void> start() async {
    _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
    print('Server running at http://localhost:$port');
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}

/// CORS middleware
Middleware cors({
  List<String> origins = const ['*'],
  List<String> methods = const ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  List<String> headers = const ['Content-Type', 'Authorization'],
}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['origin'] ?? '*';
      final allowedOrigin = origins.contains('*') ? '*' : (origins.contains(origin) ? origin : null);

      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': allowedOrigin ?? '',
          'Access-Control-Allow-Methods': methods.join(', '),
          'Access-Control-Allow-Headers': headers.join(', '),
        });
      }

      final response = await innerHandler(request);
      return response.change(headers: {
        ...response.headers,
        if (allowedOrigin != null) 'Access-Control-Allow-Origin': allowedOrigin,
      });
    };
  };
}

/// JSON body parser middleware
Middleware jsonBody() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'GET' || request.method == 'HEAD') {
        return innerHandler(request);
      }

      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return innerHandler(request);
      }

      final body = await request.readAsString();
      final json = body.isNotEmpty ? jsonDecode(body) : null;

      return innerHandler(request.change(context: {
        ...request.context,
        'body': json,
      }));
    };
  };
}

/// Logger middleware
Middleware logger() {
  return (Handler innerHandler) {
    return (Request request) async {
      final stopwatch = Stopwatch()..start();
      final response = await innerHandler(request);
      stopwatch.stop();

      final status = response.statusCode;
      final color = status < 400 ? '\x1B[32m' : '\x1B[31m';
      print('${request.method} ${request.url.path} $color$status\x1B[0m ${stopwatch.elapsedMilliseconds}ms');

      return response;
    };
  };
}

/// Auth middleware
Middleware auth(Future<bool> Function(Request) verify) {
  return (Handler innerHandler) {
    return (Request request) async {
      if (!await verify(request)) {
        return Response.unauthorized(
          jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return innerHandler(request);
    };
  };
}

/// Extension to get parsed data from request
extension RequestExtensions on Request {
  /// Get route parameters
  Map<String, String> get params => context['params'] as Map<String, String>? ?? {};

  /// Get a route parameter
  String? param(String key) => params[key];

  /// Get parsed JSON body
  dynamic get body => context['body'];

  /// Get query parameter
  String? query(String key) => url.queryParameters[key];
}

/// Helper to create a JSON response
Response json(dynamic data, {int statusCode = 200, Map<String, String>? headers}) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {
      'Content-Type': 'application/json',
      ...?headers,
    },
  );
}

/// Define a handler function
typedef HandlerFunc = FutureOr<Response> Function(Request request);

/// Create a handler
Handler defineHandler(HandlerFunc fn) => fn;
