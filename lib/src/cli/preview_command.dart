import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../core/error_html.dart';

/// Command to preview production build locally
/// Usage: duxt preview [--port=4000] [--api-port=3001]
class PreviewCommand extends Command<int> {
  @override
  final name = 'preview';

  @override
  final description = 'Preview production build locally (frontend + API)';

  PreviewCommand() {
    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '4000',
      help: 'Port for frontend server',
    );
    argParser.addOption(
      'api-port',
      defaultsTo: '3001',
      help: 'Port for API server',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;
    final port = int.parse(argResults!['port'] as String);
    final apiPort = argResults!['api-port'] as String;

    print('');
    print('\x1B[36m╭─────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1mDuxt\x1B[0m Production Preview          \x1B[36m│\x1B[0m');
    print('\x1B[36m╰─────────────────────────────────────╯\x1B[0m');
    print('');

    // Check for production build
    final buildDir = Directory(p.join(projectDir, 'build', 'jaspr'));
    if (!buildDir.existsSync()) {
      print('\x1B[31m✗\x1B[0m No production build found.');
      print('  Run \x1B[1mduxt build\x1B[0m first.');
      return 1;
    }

    Process? apiProcess;

    // Check for compiled server binary
    final serverBinary = _findServerBinary(projectDir);
    if (serverBinary != null) {
      print('\x1B[90m→\x1B[0m Starting API server...');
      // Run from .output/ directory so native libs are found correctly
      final outputDir = p.dirname(serverBinary);
      apiProcess = await Process.start(
        serverBinary,
        [],
        workingDirectory: outputDir,
        environment: {'PORT': apiPort},
      );

      apiProcess.stdout.listen((data) {
        final output = String.fromCharCodes(data).trim();
        if (output.isNotEmpty) print('\x1B[35m[API]\x1B[0m $output');
      });
      apiProcess.stderr.listen((data) {
        final output = String.fromCharCodes(data).trim();
        if (output.isNotEmpty) print('\x1B[31m[API]\x1B[0m $output');
      });
    }

    // Start frontend server
    print('\x1B[90m→\x1B[0m Starting frontend server...');
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    print('');
    print('\x1B[32m✓\x1B[0m Preview running!');
    print('');
    print('  \x1B[1mApp:\x1B[0m  \x1B[36mhttp://localhost:$port\x1B[0m');
    if (apiProcess != null) {
      print('  \x1B[1mAPI:\x1B[0m  \x1B[36mhttp://localhost:$apiPort\x1B[0m');
    }
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Handle requests
    server.listen((request) => _handleRequest(request, buildDir.path));

    // Handle both SIGINT (Ctrl+C) and SIGTERM (kill)
    void shutdown() {
      print('');
      print('\x1B[90mShutting down...\x1B[0m');
      apiProcess?.kill();
      server.close();
    }

    ProcessSignal.sigterm.watch().listen((_) {
      shutdown();
      exit(0);
    });

    await ProcessSignal.sigint.watch().first;
    shutdown();

    return 0;
  }

  String? _findServerBinary(String projectDir) {
    final outputDir = p.join(projectDir, '.output');

    // Detect current platform
    final os = Platform.operatingSystem;
    final arch = Platform.version.contains('arm64') ? 'arm64' : 'x64';
    final target = '$os-$arch';

    // Check bundle structure first (dart build cli output)
    final bundleBin = Directory(p.join(outputDir, 'bundle', 'bin'));
    if (bundleBin.existsSync()) {
      // Try exact match
      var binary = File(p.join(bundleBin.path, 'server-$target'));
      if (binary.existsSync()) return binary.path;

      // Try any server binary in bundle
      for (final file in bundleBin.listSync()) {
        if (file is File && p.basename(file.path).startsWith('server-')) {
          return file.path;
        }
      }
      // Try 'main' binary (default dart build cli name)
      binary = File(p.join(bundleBin.path, 'main'));
      if (binary.existsSync()) return binary.path;
    }

    // Fall back to flat structure (dart compile exe output)
    var binary = File(p.join(outputDir, 'server-$target'));
    if (binary.existsSync()) return binary.path;

    // Try any server binary in output root
    final dir = Directory(outputDir);
    if (dir.existsSync()) {
      for (final file in dir.listSync()) {
        if (file is File && p.basename(file.path).startsWith('server-')) {
          return file.path;
        }
      }
    }

    return null;
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

    // Try index.html in subdirectory
    if (!file.existsSync() && !path.endsWith('.html')) {
      file = File('$buildDir$path/index.html');
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
    if (path.endsWith('.ico')) return ContentType('image', 'x-icon');
    return ContentType.binary;
  }
}
