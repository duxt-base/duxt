import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Development server for Duxt
/// Proxies to Jaspr dev server and handles API routes
class DevServer {
  final String projectDir;
  final int port;

  HttpServer? _server;
  Process? _jasprProcess;

  DevServer(this.projectDir, this.port);

  Future<void> start() async {
    // Start Jaspr dev server on a different port
    final jasprPort = port + 1;

    // Find jaspr CLI
    final home = Platform.environment['HOME'] ?? '';
    final jasprCli = '$home/.pub-cache/bin/jaspr';
    final jasprCmd = File(jasprCli).existsSync() ? jasprCli : 'jaspr';

    // Start jaspr serve in the background
    _jasprProcess = await Process.start(
      jasprCmd,
      ['serve', '--port', jasprPort.toString()],
      workingDirectory: projectDir,
    );

    // Forward jaspr output
    _jasprProcess!.stdout.transform(utf8.decoder).listen((data) {
      stdout.write(data);
    });

    _jasprProcess!.stderr.transform(utf8.decoder).listen((data) {
      stderr.write(data);
    });

    // Wait a bit for Jaspr to start
    await Future.delayed(const Duration(seconds: 2));

    // Create middleware pipeline
    final handler = const shelf.Pipeline()
        .addMiddleware(_logRequests())
        .addMiddleware(_cors())
        .addHandler(_handleRequest(jasprPort));

    // Start our proxy server
    _server = await shelf_io.serve(handler, 'localhost', port);
  }

  Future<void> stop() async {
    await _server?.close();
    _jasprProcess?.kill();
  }

  shelf.Middleware _logRequests() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final stopwatch = Stopwatch()..start();
        final response = await innerHandler(request);
        stopwatch.stop();

        final method = request.method;
        final path = request.url.path;
        final status = response.statusCode;
        final time = stopwatch.elapsedMilliseconds;

        // Color code status
        String statusColor;
        if (status >= 200 && status < 300) {
          statusColor = '\x1B[32m'; // Green
        } else if (status >= 300 && status < 400) {
          statusColor = '\x1B[33m'; // Yellow
        } else {
          statusColor = '\x1B[31m'; // Red
        }

        print('$method /$path $statusColor$status\x1B[0m ${time}ms');

        return response;
      };
    };
  }

  shelf.Middleware _cors() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok('', headers: _corsHeaders);
        }

        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  };

  shelf.Handler _handleRequest(int jasprPort) {
    return (shelf.Request request) async {
      final path = request.url.path;

      // Handle API routes
      if (path.startsWith('api/')) {
        return _handleApiRoute(request);
      }

      // Proxy to Jaspr dev server
      return _proxyToJaspr(request, jasprPort);
    };
  }

  Future<shelf.Response> _handleApiRoute(shelf.Request request) async {
    final path = request.url.path;
    final apiPath = path.substring(4); // Remove 'api/'

    // Find the API handler file
    final handlerFile = File(p.join(projectDir, 'server', 'api', '$apiPath.dart'));

    if (!handlerFile.existsSync()) {
      // Try index.dart in directory
      final indexFile = File(p.join(projectDir, 'server', 'api', apiPath, 'index.dart'));
      if (!indexFile.existsSync()) {
        return shelf.Response.notFound(
          jsonEncode({'error': 'API route not found: $path'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // For now, return a placeholder
    // In production, this would dynamically load and execute the handler
    return shelf.Response.ok(
      jsonEncode({
        'message': 'API route: $path',
        'method': request.method,
        'note': 'Dynamic API handlers coming soon',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<shelf.Response> _proxyToJaspr(shelf.Request request, int jasprPort) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('http://localhost:$jasprPort/${request.url}');

      final proxyRequest = await client.openUrl(request.method, uri);

      // Copy headers
      request.headers.forEach((name, value) {
        proxyRequest.headers.set(name, value);
      });

      // Copy body if present
      if (request.method == 'POST' || request.method == 'PUT') {
        final body = await request.read().toList();
        for (final chunk in body) {
          proxyRequest.add(chunk);
        }
      }

      final proxyResponse = await proxyRequest.close();

      // Read response body
      final responseBody = await proxyResponse.transform(utf8.decoder).join();

      // Convert headers
      final headers = <String, String>{};
      proxyResponse.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });

      return shelf.Response(
        proxyResponse.statusCode,
        body: responseBody,
        headers: headers,
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: 'Error proxying to Jaspr: $e',
      );
    }
  }
}
