import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../core/router_generator.dart';
import '../core/error_html.dart';

/// Command to start production server
/// Usage: duxt start [--port=PORT]
class StartCommand extends Command<int> {
  @override
  final name = 'start';

  @override
  final description = 'Start production server (auto-finds free port or use specified)';

  StartCommand() {
    argParser.addOption(
      'port',
      abbr: 'p',
      help: 'Port to run the server on (auto-finds free port if not specified)',
    );
    argParser.addFlag(
      'open',
      abbr: 'o',
      help: 'Open browser after starting',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;
    final specifiedPort = argResults!['port'] as String?;
    final openBrowser = argResults!['open'] as bool;

    // Check if this is a Duxt project
    if (!File('$projectDir/duxt.config.dart').existsSync() &&
        !Directory('$projectDir/lib/pages').existsSync()) {
      print('Error: Not a Duxt project. Run this command in a Duxt project directory.');
      return 1;
    }

    // Find a free port or use specified
    final port = specifiedPort != null
        ? int.parse(specifiedPort)
        : await _findFreePort();

    print('');
    print('\x1B[36m🚀 Duxt\x1B[0m v0.1.0');
    print('');

    // Generate routes first
    print('→ Generating routes...');
    await RouterGenerator.generate(projectDir);

    // Check if build exists
    final buildDir = Directory('$projectDir/build/jaspr');
    if (!buildDir.existsSync()) {
      print('→ No production build found, building...');

      // Find jaspr CLI
      final home = Platform.environment['HOME'] ?? '';
      final jasprCli = '$home/.pub-cache/bin/jaspr';

      final buildResult = await Process.run(
        File(jasprCli).existsSync() ? jasprCli : 'jaspr',
        ['build'],
        workingDirectory: projectDir,
      );
      if (buildResult.exitCode != 0) {
        print('\x1B[31m✗\x1B[0m Build failed');
        print(buildResult.stderr);
        print(buildResult.stdout);
        return 1;
      }
    }

    print('');
    print('\x1B[32m✓\x1B[0m Server running at \x1B[36mhttp://localhost:$port\x1B[0m');
    print('');
    print('  Press Ctrl+C to stop');
    print('');

    // Start a simple HTTP server for the built files
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    // Open browser if requested
    if (openBrowser) {
      await _openBrowser('http://localhost:$port');
    }

    await for (final request in server) {
      await _handleRequest(request, buildDir.path);
    }

    return 0;
  }

  Future<int> _findFreePort() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  Future<void> _handleRequest(HttpRequest request, String buildDir) async {
    // Security headers on all responses
    request.response.headers
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('X-Frame-Options', 'DENY');

    var path = request.uri.path;

    // Default to index.html
    if (path == '/' || path.isEmpty) {
      path = '/index.html';
    }

    // Try to serve the file
    var file = File('$buildDir$path');

    // Path traversal protection: verify resolved path stays within buildDir
    if (!_isWithinDir(file, buildDir)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType.html
        ..write(DuxtErrorHtml.notFound(path: request.uri.path));
      await request.response.close();
      return;
    }

    // If file doesn't exist and doesn't have extension, try .html
    if (!file.existsSync() && !path.contains('.')) {
      file = File('$buildDir$path.html');
    }

    // For SPA routing, serve index.html for non-file routes
    if (!file.existsSync()) {
      file = File('$buildDir/index.html');
    }

    if (file.existsSync()) {
      final contentType = _getContentType(file.path);
      request.response
        ..headers.contentType = contentType
        ..add(await file.readAsBytes());
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.html
        ..write(DuxtErrorHtml.notFound(path: request.uri.path));
    }

    await request.response.close();
  }

  /// Verify that a file path resolves to within the given directory.
  bool _isWithinDir(File file, String dir) {
    final canonicalDir = p.canonicalize(dir);
    final canonicalFile = p.canonicalize(file.path);
    return canonicalFile.startsWith(canonicalDir);
  }

  ContentType _getContentType(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.css')) return ContentType('text', 'css');
    if (path.endsWith('.js')) return ContentType('application', 'javascript');
    if (path.endsWith('.json')) return ContentType.json;
    if (path.endsWith('.png')) return ContentType('image', 'png');
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return ContentType('image', 'jpeg');
    if (path.endsWith('.gif')) return ContentType('image', 'gif');
    if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (path.endsWith('.webp')) return ContentType('image', 'webp');
    if (path.endsWith('.woff')) return ContentType('font', 'woff');
    if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
    if (path.endsWith('.ttf')) return ContentType('font', 'ttf');
    return ContentType.binary;
  }

  Future<void> _openBrowser(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      }
    } catch (_) {
      // Ignore errors opening browser
    }
  }
}
