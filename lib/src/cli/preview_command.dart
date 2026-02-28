import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../core/static_server.dart';

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
      help: 'Port for the unified server (proxies /api to API server)',
    );
    argParser.addOption(
      'api-port',
      defaultsTo: '3001',
      help: 'Internal port for API server',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;
    final port = int.parse(argResults!['port'] as String);
    final apiPort = int.parse(argResults!['api-port'] as String);

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
    var hasApi = false;

    // Check for compiled server binary
    final serverBinary = _findServerBinary(projectDir);
    if (serverBinary != null) {
      hasApi = true;
      print('\x1B[90m→\x1B[0m Starting API server on port $apiPort...');
      // Run from .output/ directory so native libs are found correctly
      final outputDir = p.dirname(serverBinary);
      apiProcess = await Process.start(
        serverBinary,
        [],
        workingDirectory: outputDir,
        environment: {'PORT': apiPort.toString()},
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

    // Start unified server — proxies /api/* to API, serves static for rest
    print('\x1B[90m→\x1B[0m Starting server...');
    final staticServer = StaticFileServer(buildDir.path);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    print('');
    print('\x1B[32m✓\x1B[0m Preview running!');
    print('');
    print('  \x1B[1mApp:\x1B[0m  \x1B[36mhttp://localhost:$port\x1B[0m');
    if (hasApi) {
      print('  \x1B[1mAPI:\x1B[0m  \x1B[36mhttp://localhost:$port/api\x1B[0m');
    }
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Handle requests — proxy /api/* to API server, static for everything else
    server.listen((request) async {
      if (hasApi && request.uri.path.startsWith('/api')) {
        await _proxyToApi(request, apiPort);
      } else {
        await staticServer.handleRequest(request);
      }
    });

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

  /// Proxy an incoming request to the API server.
  Future<void> _proxyToApi(HttpRequest request, int apiPort) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('http://localhost:$apiPort${request.uri}');
      final proxyReq = await client.openUrl(request.method, uri);

      // Copy headers
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host') {
          for (final v in values) {
            proxyReq.headers.add(name, v);
          }
        }
      });

      // Copy request body
      final body = await request.fold<List<int>>(
        <int>[],
        (previous, chunk) => previous..addAll(chunk),
      );
      proxyReq.add(body);
      final proxyRes = await proxyReq.close();

      // Copy response status and headers
      request.response.statusCode = proxyRes.statusCode;
      proxyRes.headers.forEach((name, values) {
        if (name.toLowerCase() != 'transfer-encoding') {
          for (final v in values) {
            request.response.headers.add(name, v);
          }
        }
      });

      // Pipe response body
      await proxyRes.pipe(request.response);
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badGateway
        ..headers.contentType = ContentType.json
        ..write('{"error":"API server not available","message":"$e"}');
      await request.response.close();
    }
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
}
