import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Development server for Duxt
/// Proxies to Jaspr dev server and API server
class DevServer {
  final String projectDir;
  final int port;
  late final int apiPort;
  late final int jasprPort;

  HttpServer? _server;
  Process? _jasprProcess;
  Process? _apiProcess;

  DevServer(this.projectDir, this.port, {int? apiPort}) {
    this.apiPort = apiPort ?? (port + 1);
    jasprPort = port + 100; // Use separate range to avoid conflicts
  }

  Future<void> start() async {
    print('');
    print('\x1B[36m╭───────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1mDuxt Development Server\x1B[0m             \x1B[36m│\x1B[0m');
    print('\x1B[36m╰───────────────────────────────────────╯\x1B[0m');
    print('');

    // 1. Start API server
    print('\x1B[36m→\x1B[0m Starting API server on port $apiPort...');
    final serverFile = File(p.join(projectDir, 'server', 'main.dart'));
    if (serverFile.existsSync()) {
      _apiProcess = await Process.start(
        'dart',
        ['run', 'server/main.dart'],
        workingDirectory: projectDir,
        environment: {'PORT': apiPort.toString()},
      );

      // Forward API server output with prefix
      _apiProcess!.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            print('\x1B[33m[api]\x1B[0m $line');
          }
        }
      });

      _apiProcess!.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            stderr.writeln('\x1B[31m[api]\x1B[0m $line');
          }
        }
      });

      // Wait for API server to start
      await Future.delayed(const Duration(seconds: 2));
      print('  \x1B[32m✓\x1B[0m API server started');
    } else {
      print('  \x1B[33m⚠\x1B[0m No server/main.dart found, API routes disabled');
    }

    // 2. Start Jaspr dev server
    print('\x1B[36m→\x1B[0m Starting Jaspr dev server on port $jasprPort...');

    _jasprProcess = await Process.start(
      'dart',
      ['pub', 'global', 'run', 'jaspr_cli:jaspr', 'serve', '--port', jasprPort.toString()],
      workingDirectory: projectDir,
    );

    // Forward jaspr output with prefix
    _jasprProcess!.stdout.transform(utf8.decoder).listen((data) {
      for (final line in data.split('\n')) {
        if (line.trim().isNotEmpty) {
          print('\x1B[35m[web]\x1B[0m $line');
        }
      }
    });

    _jasprProcess!.stderr.transform(utf8.decoder).listen((data) {
      for (final line in data.split('\n')) {
        if (line.trim().isNotEmpty) {
          stderr.writeln('\x1B[31m[web]\x1B[0m $line');
        }
      }
    });

    // Wait for Jaspr to start
    await Future.delayed(const Duration(seconds: 3));
    print('  \x1B[32m✓\x1B[0m Jaspr dev server started');

    // 3. Create middleware pipeline
    final handler = const shelf.Pipeline()
        .addMiddleware(_logRequests())
        .addMiddleware(_cors())
        .addHandler(_handleRequest());

    // 4. Start proxy server
    _server = await shelf_io.serve(handler, 'localhost', port);

    print('');
    print('\x1B[32m✓\x1B[0m Dev server running at \x1B[1mhttp://localhost:$port\x1B[0m');
    print('');
    print('  \x1B[36mFrontend:\x1B[0m http://localhost:$port');
    print('  \x1B[36mAPI:\x1B[0m      http://localhost:$port/api/*');
    print('');
  }

  Future<void> stop() async {
    await _server?.close();
    _jasprProcess?.kill();
    _apiProcess?.kill();
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

  shelf.Handler _handleRequest() {
    return (shelf.Request request) async {
      final path = request.url.path;

      // Handle API routes
      if (path.startsWith('api/')) {
        return _handleApiRoute(request);
      }

      // Proxy to Jaspr dev server
      return _proxyToJaspr(request);
    };
  }

  Future<shelf.Response> _handleApiRoute(shelf.Request request) async {
    // Proxy to API server
    return _proxyToApi(request);
  }

  Future<shelf.Response> _proxyToApi(shelf.Request request) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('http://localhost:$apiPort/${request.url}');

      final proxyRequest = await client.openUrl(request.method, uri);

      // Copy headers
      request.headers.forEach((name, value) {
        if (name.toLowerCase() != 'host') {
          proxyRequest.headers.set(name, value);
        }
      });
      proxyRequest.headers.set('host', 'localhost:$apiPort');

      // Copy body if present
      if (request.method == 'POST' ||
          request.method == 'PUT' ||
          request.method == 'PATCH') {
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
        body: jsonEncode({'error': 'Error connecting to API server: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<shelf.Response> _proxyToJaspr(shelf.Request request) async {
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
