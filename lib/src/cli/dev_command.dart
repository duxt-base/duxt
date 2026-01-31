import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:yaml/yaml.dart';
import '../core/router_generator.dart';
import '../core/watcher.dart';

/// Command to start development server
/// Usage: duxt dev [--port=4000]
/// Ports are auto-incremented: proxy=port, api=port+1, jaspr=port+2, webdev=port+3
class DevCommand extends Command<int> {
  @override
  final name = 'dev';

  @override
  final description = 'Start development server with hot reload';

  DevCommand() {
    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '4000',
      help: 'Base port (api=+1, jaspr=+2, webdev=+3)',
    );
    argParser.addFlag(
      'no-api',
      defaultsTo: false,
      help: 'Skip starting the API server',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      help: 'Show detailed build output',
    );
  }

  @override
  Future<int> run() async {
    final port = int.parse(argResults!['port'] as String);
    final apiPort = port + 1;
    final jasprPort = port + 2;
    final webdevPort = (port + 3).toString();
    final noApi = argResults!['no-api'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final projectDir = Directory.current.path;

    // Check if this is a Duxt project
    if (!File('$projectDir/duxt.config.dart').existsSync() &&
        !Directory('$projectDir/lib').existsSync()) {
      print('Error: Not a Duxt project. Run this command in a Duxt project directory.');
      return 1;
    }

    print('');
    print('\x1B[36m               88\x1B[0m');
    print('\x1B[36m               88\x1B[0m');
    print('\x1B[36m      .d88888b 88  db       db  db        db d88888888b\x1B[0m');
    print('\x1B[36m    .8P       Y88  88       88   `8b    d8\'      88\x1B[0m');
    print('\x1B[36m    88         88  88       88     `8bd8\'        88\x1B[0m');
    print('\x1B[36m    88         88  88       88     .dPYb.        88\x1B[0m');
    print('\x1B[36m    `8L       d89  88b     d88   .8P    Y8.      88\x1B[0m');
    print('\x1B[36m     `Y888888P8J    ~Y88888\'88  dP        Yb     `Y88P\x1B[0m');
    print('');
    print('\x1B[36m                     oooooooooooooooooooo\x1B[0m');
    print('');

    // Run pub get if needed
    final pubspecLock = File(p.join(projectDir, 'pubspec.lock'));
    final packageConfig = File(p.join(projectDir, '.dart_tool', 'package_config.json'));
    if (!pubspecLock.existsSync() || !packageConfig.existsSync()) {
      print('\x1B[90m→\x1B[0m Installing dependencies...');
      final result = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir);
      if (result.exitCode != 0) {
        print('\x1B[31m✗\x1B[0m Failed to install dependencies');
        print(result.stderr);
        return 1;
      }
      print('  Done');
    }

    // Sync duxt_ui package for Tailwind scanning
    print('\x1B[90m→\x1B[0m Syncing packages...');
    await _syncPackages(projectDir);

    // Compile Tailwind CSS
    print('\x1B[90m→\x1B[0m Compiling Tailwind CSS...');
    final tailwindOk = await _compileTailwind(projectDir);
    if (!tailwindOk) {
      print('  \x1B[33m!\x1B[0m Tailwind compilation skipped (tailwindcss not found)');
    }

    // Kill stale build daemons that may be holding ports
    print('\x1B[90m→\x1B[0m Cleaning up stale processes...');
    await Process.run('pkill', ['-f', 'build_runner']);
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate routes
    print('\x1B[90m→\x1B[0m Generating routes...');
    await RouterGenerator.generate(projectDir);

    // Start file watcher for route generation
    print('\x1B[90m→\x1B[0m Starting file watcher...');
    final watcher = DuxtWatcher(projectDir, onFileChange: (path) async {
      if (path.contains('/pages/')) {
        print('\x1B[33m↻\x1B[0m Route change: $path');
        await RouterGenerator.generate(projectDir);
      }
    });
    await watcher.start();

    Process? apiProcess;
    Process? jasprProcess;
    Process? tailwindProcess;
    HttpServer? proxyServer;

    final hasApi = !noApi && File('$projectDir/server/main.dart').existsSync();

    // Start API server if server/main.dart exists
    if (hasApi) {
      print('\x1B[90m→\x1B[0m Starting API server on port $apiPort...');
      apiProcess = await Process.start(
        'dart',
        ['run', 'server/main.dart'],
        workingDirectory: projectDir,
        environment: {'PORT': apiPort.toString()},
      );

      apiProcess.stdout.listen((data) {
        final output = utf8.decode(data).trim();
        for (final line in output.split('\n')) {
          if (line.trim().isNotEmpty) print('\x1B[35m[api]\x1B[0m $line');
        }
      });
      apiProcess.stderr.listen((data) {
        final output = utf8.decode(data).trim();
        for (final line in output.split('\n')) {
          if (line.trim().isNotEmpty) print('\x1B[31m[api]\x1B[0m $line');
        }
      });

      // Wait for API to start
      await Future.delayed(const Duration(seconds: 2));
    }

    // Start Tailwind in watch mode
    if (tailwindOk) {
      print('\x1B[90m→\x1B[0m Starting Tailwind watcher...');
      tailwindProcess = await _startTailwindWatch(projectDir, verbose: verbose);
    }

    // Start jaspr serve on internal port
    print('\x1B[90m→\x1B[0m Starting Jaspr server on port $jasprPort...');

    // Check for local jaspr first (for development), then fall back to global
    final home = Platform.environment['HOME'] ?? '';
    final localJasprBin = p.join(p.dirname(projectDir), 'jaspr', 'packages', 'jaspr_cli', 'bin', 'jaspr.dart');
    final globalJasprPath = '$home/.pub-cache/bin/jaspr';

    String jasprCmd;
    List<String> jasprArgs;

    if (File(localJasprBin).existsSync()) {
      // Use local jaspr via dart run
      print('  \x1B[90mUsing local jaspr\x1B[0m');
      jasprCmd = 'dart';
      jasprArgs = ['run', localJasprBin, 'serve', '--port', jasprPort.toString(), '--web-port', webdevPort];
    } else {
      // Use global jaspr
      if (!File(globalJasprPath).existsSync()) {
        print('\x1B[33m!\x1B[0m jaspr_cli not found, installing...');
        await Process.run('dart', ['pub', 'global', 'activate', 'jaspr_cli']);
      }
      jasprCmd = globalJasprPath;
      jasprArgs = ['serve', '--port', jasprPort.toString(), '--web-port', webdevPort];
    }

    jasprProcess = await Process.start(
      jasprCmd,
      jasprArgs,
      workingDirectory: projectDir,
    );

    // Track build state for spinner and ready state
    var isBuilding = false;
    var buildSpinner = _Spinner('Building');
    final jasprReady = Completer<void>();

    jasprProcess.stdout.listen((data) {
      final output = utf8.decode(data).trim();
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;

        if (verbose) {
          print('\x1B[34m[web]\x1B[0m $line');
        } else {
          // Show spinner during build, only print important messages
          if (line.contains('Starting web compiler') || line.contains('Building web assets')) {
            if (!isBuilding) {
              isBuilding = true;
              buildSpinner.start();
            }
          } else if (line.contains('Done building web assets')) {
            if (isBuilding) {
              buildSpinner.stop();
              isBuilding = false;
            }
          } else if (line.contains('[ERROR]') || line.contains('Error')) {
            buildSpinner.stop();
            isBuilding = false;
            print('\x1B[31m[web]\x1B[0m $line');
          }
        }

        // Signal ready when server is serving
        if (line.contains('Serving at') && !jasprReady.isCompleted) {
          jasprReady.complete();
        }
      }
    });
    jasprProcess.stderr.listen((data) {
      final output = utf8.decode(data).trim();
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;
        // Always show errors
        if (line.contains('[ERROR]') || verbose) {
          buildSpinner.stop();
          isBuilding = false;
          print('\x1B[31m[web]\x1B[0m $line');
        }
      }
    });

    // Wait for Jaspr to actually be ready (with timeout fallback)
    await jasprReady.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => print('\x1B[33m!\x1B[0m Jaspr taking longer than expected...'),
    );

    // Start proxy server on main port
    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler((request) => _proxyHandler(request, apiPort, jasprPort, hasApi));

    proxyServer = await shelf_io.serve(handler, 'localhost', port);

    // Detect project mode
    final mode = _detectMode(projectDir);
    final modeLabel = _getModeLabel(mode);
    final modeColor = _getModeColor(mode);

    print('\x1B[32m✓\x1B[0m Ready!');
    print('');
    print('  \x1B[1mApp:\x1B[0m    \x1B[36mhttp://localhost:$port\x1B[0m');
    if (hasApi) {
      print('  \x1B[1mAPI:\x1B[0m    \x1B[36mhttp://localhost:$port/api\x1B[0m');
    }
    print('  \x1B[1mMode:\x1B[0m   $modeColor$modeLabel\x1B[0m');
    print('');
    print('\x1B[90mPorts:\x1B[0m');
    print('  \x1B[90mProxy:\x1B[0m  $port');
    if (hasApi) {
      print('  \x1B[90mAPI:\x1B[0m    $apiPort');
    }
    print('  \x1B[90mJaspr:\x1B[0m  $jasprPort');
    print('  \x1B[90mWebdev:\x1B[0m $webdevPort');
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Keep running until interrupted
    await ProcessSignal.sigint.watch().first;

    print('');
    print('\x1B[90mShutting down...\x1B[0m');

    await proxyServer.close();
    await watcher.stop();
    tailwindProcess?.kill();
    apiProcess?.kill();
    jasprProcess.kill();

    return 0;
  }

  /// CORS middleware
  shelf.Middleware _corsMiddleware() {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
    };

    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok('', headers: corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: corsHeaders);
      };
    };
  }

  /// Proxy handler that routes /api/* to API server and rest to Jaspr
  Future<shelf.Response> _proxyHandler(
    shelf.Request request,
    int apiPort,
    int jasprPort,
    bool hasApi,
  ) async {
    final path = request.url.path;
    final targetPort = (hasApi && path.startsWith('api/')) ? apiPort : jasprPort;

    try {
      final client = HttpClient();
      final uri = Uri.parse('http://localhost:$targetPort/${request.url}');

      final proxyRequest = await client.openUrl(request.method, uri);

      // Copy headers
      request.headers.forEach((name, value) {
        if (name.toLowerCase() != 'host') {
          proxyRequest.headers.set(name, value);
        }
      });

      // Copy body if present
      if (['POST', 'PUT', 'PATCH'].contains(request.method)) {
        final body = await request.read().toList();
        for (final chunk in body) {
          proxyRequest.add(chunk);
        }
      }

      final proxyResponse = await proxyRequest.close();

      // Read response body as bytes to handle binary content
      final responseBytes = await proxyResponse.fold<List<int>>(
        <int>[],
        (previous, chunk) => previous..addAll(chunk),
      );

      // Convert headers, but skip content-encoding since HttpClient auto-decompresses
      final headers = <String, String>{};
      proxyResponse.headers.forEach((name, values) {
        // HttpClient automatically decompresses gzip, so don't forward that header
        if (name.toLowerCase() != 'content-encoding') {
          headers[name] = values.join(',');
        }
      });

      return shelf.Response(
        proxyResponse.statusCode,
        body: responseBytes,
        headers: headers,
      );
    } catch (e) {
      final isApi = path.startsWith('api/');
      return shelf.Response.internalServerError(
        body: jsonEncode({
          'error': 'Proxy error: $e',
          'target': isApi ? 'API server' : 'Jaspr server',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Compile Tailwind CSS once
  Future<bool> _compileTailwind(String projectDir) async {
    final inputFile = File(p.join(projectDir, 'web', 'styles.tw.css'));
    if (!inputFile.existsSync()) return false;

    // Check if tailwindcss is available
    final which = await Process.run('which', ['tailwindcss']);
    if (which.exitCode != 0) {
      // Try common locations
      final home = Platform.environment['HOME'] ?? '';
      final locations = [
        '/usr/local/bin/tailwindcss',
        '$home/.local/bin/tailwindcss',
        'tailwindcss',
      ];

      bool found = false;
      for (final loc in locations) {
        if (File(loc).existsSync()) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }

    final result = await Process.run(
      'tailwindcss',
      [
        '--input', p.join(projectDir, 'web', 'styles.tw.css'),
        '--output', p.join(projectDir, 'web', 'styles.css'),
      ],
      workingDirectory: projectDir,
    );

    if (result.exitCode == 0) {
      print('  Compiled styles.css');
      return true;
    } else {
      print('  \x1B[31mTailwind error:\x1B[0m ${result.stderr}');
      return false;
    }
  }

  /// Start Tailwind in watch mode
  Future<Process?> _startTailwindWatch(String projectDir, {bool verbose = false}) async {
    final process = await Process.start(
      'tailwindcss',
      [
        '--input', p.join(projectDir, 'web', 'styles.tw.css'),
        '--output', p.join(projectDir, 'web', 'styles.css'),
        '--watch',
      ],
      workingDirectory: projectDir,
    );

    process.stdout.listen((data) {
      final output = utf8.decode(data).trim();
      if (output.isNotEmpty && !output.contains('tailwindcss v')) {
        if (verbose) {
          print('\x1B[35m[tw]\x1B[0m $output');
        }
        // Silently rebuild CSS in non-verbose mode
      }
    });
    process.stderr.listen((data) {
      final output = utf8.decode(data).trim();
      if (output.isEmpty) return;

      // In non-verbose mode, only show actual errors (not status messages)
      final isStatusMsg = output.contains('Done in') || output.contains('tailwindcss v');
      if (verbose) {
        print('\x1B[31m[tw]\x1B[0m $output');
      } else if (!isStatusMsg) {
        // Only print if it looks like a real error
        print('\x1B[31m[tw]\x1B[0m $output');
      }
    });

    return process;
  }

  /// Sync duxt_ui package to .duxt/packages/ for Tailwind CSS scanning
  Future<void> _syncPackages(String projectDir) async {
    final packagesToSync = ['duxt_ui'];
    final targetDir = Directory(p.join(projectDir, '.duxt', 'packages'));

    // Read package_config.json to find package locations
    final packageConfigFile = File(p.join(projectDir, '.dart_tool', 'package_config.json'));
    if (!packageConfigFile.existsSync()) {
      print('  \x1B[33m!\x1B[0m Run "dart pub get" first');
      return;
    }

    final packageConfig = jsonDecode(await packageConfigFile.readAsString());
    final packages = packageConfig['packages'] as List<dynamic>;

    for (final pkgName in packagesToSync) {
      final pkg = packages.firstWhere(
        (p) => p['name'] == pkgName,
        orElse: () => null,
      );

      if (pkg == null) continue;

      String rootUri = pkg['rootUri'] as String;

      // Resolve the path
      String sourcePath;
      if (rootUri.startsWith('file://')) {
        sourcePath = Uri.parse(rootUri).toFilePath();
      } else if (rootUri.startsWith('../')) {
        // Relative path from .dart_tool/
        sourcePath = p.normalize(p.join(projectDir, '.dart_tool', rootUri));
      } else {
        continue;
      }

      final sourceLib = Directory(p.join(sourcePath, 'lib'));
      if (!sourceLib.existsSync()) continue;

      final targetPkg = Directory(p.join(targetDir.path, pkgName));

      // Remove existing and copy fresh
      if (targetPkg.existsSync()) {
        await targetPkg.delete(recursive: true);
      }
      await targetPkg.create(recursive: true);

      // Copy lib directory contents
      await _copyDirectory(sourceLib, targetPkg);

      print('  Synced $pkgName');
    }
  }

  /// Recursively copy a directory
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));

      if (entity is Directory) {
        final newDir = Directory(targetPath);
        await newDir.create(recursive: true);
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  /// Detect jaspr mode from pubspec.yaml
  String _detectMode(String projectDir) {
    final pubspecFile = File(p.join(projectDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return 'unknown';

    try {
      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content);

      if (yaml is YamlMap && yaml['jaspr'] is YamlMap) {
        final jasprConfig = yaml['jaspr'] as YamlMap;
        return jasprConfig['mode']?.toString() ?? 'auto';
      }
    } catch (_) {}

    return 'auto';
  }

  /// Get human-readable label for mode
  String _getModeLabel(String mode) {
    switch (mode) {
      case 'client':
        return 'Client-side (SPA)';
      case 'server':
        return 'Server-side (SSR)';
      case 'static':
        return 'Static (SSG)';
      case 'auto':
        return 'Auto-detect';
      default:
        return mode;
    }
  }

  /// Get ANSI color for mode
  String _getModeColor(String mode) {
    switch (mode) {
      case 'client':
        return '\x1B[33m'; // Yellow
      case 'server':
        return '\x1B[35m'; // Magenta
      case 'static':
        return '\x1B[32m'; // Green
      default:
        return '\x1B[90m'; // Gray
    }
  }
}

/// Simple spinner for build progress
class _Spinner {
  final String message;
  Timer? _timer;
  int _frame = 0;
  static const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  _Spinner(this.message);

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      stdout.write('\r\x1B[90m${_frames[_frame]}\x1B[0m $message...');
      _frame = (_frame + 1) % _frames.length;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    stdout.write('\r\x1B[K'); // Clear the spinner line
  }
}
