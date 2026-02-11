import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:yaml/yaml.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/router_generator.dart';
import '../core/watcher.dart';
import 'tauri_scaffold.dart';

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
    argParser.addFlag(
      'desktop',
      defaultsTo: false,
      help: 'Run in a native desktop window (Tauri dev mode)',
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
    final desktop = argResults!['desktop'] as bool;
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

    // Kill stale build daemons that may be holding ports (scoped to this project)
    print('\x1B[90m→\x1B[0m Cleaning up stale processes...');
    await Process.run('pkill', ['-f', 'build_runner.*${projectDir.replaceAll('/', '\\/')}']);
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
    final devToolsPort = port + 4; // WebSocket port for dev tools
    final devTools = _DevTools(devToolsPort);

    // Start dev tools WebSocket server (non-fatal if port is busy)
    try {
      await devTools.start();
    } catch (e) {
      // Kill stale process on the port and retry once
      try {
        final result = await Process.run('lsof', ['-ti', ':$devToolsPort']);
        final pids = result.stdout.toString().trim();
        if (pids.isNotEmpty) {
          for (final pid in pids.split('\n')) {
            if (pid.trim().isNotEmpty) {
              await Process.run('kill', ['-9', pid.trim()]);
            }
          }
          await Future.delayed(const Duration(milliseconds: 500));
          await devTools.start();
        }
      } catch (_) {
        print('  \x1B[33m!\x1B[0m DevTools overlay unavailable (port $devToolsPort in use)');
      }
    }

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

    // Check if this is a fresh build (no .dart_tool/build exists)
    final buildDir = Directory(p.join(projectDir, '.dart_tool', 'build'));
    final isFirstBuild = !buildDir.existsSync();
    if (isFirstBuild) {
      print('  \x1B[33mFirst build - this may take 1-2 minutes...\x1B[0m');
      if (!verbose) {
        print('  \x1B[90mRun with --verbose to see build progress\x1B[0m');
      }
    }

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
        }

        // Detect build events regardless of verbose mode
        if (line.contains('Rebuilding web assets') || line.contains('Building web assets') || line.contains('About to build')) {
          if (!isBuilding) {
            isBuilding = true;
            if (!verbose) buildSpinner.start();
            devTools.broadcast('building', 'Building...', details: 'Compiling web assets');
          }
        } else if (line.contains('Rebuilt web assets') || line.contains('Done building web assets') || line.contains('Server application reloaded')) {
          if (isBuilding) {
            if (!verbose) buildSpinner.stop();
            isBuilding = false;
            devTools.broadcast('success', 'Hot Reloaded', details: 'Build complete');
          }
        } else if (line.contains('[ERROR]') || (line.contains('Error') && !line.contains('no-op'))) {
          if (!verbose) buildSpinner.stop();
          isBuilding = false;
          print('\x1B[31m[web]\x1B[0m $line');
          devTools.broadcast('error', 'Build Error', details: line.length > 80 ? '${line.substring(0, 80)}...' : line);
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
          devTools.broadcast('error', 'Error', details: line.length > 80 ? '${line.substring(0, 80)}...' : line);
        }
      }
    });

    // Wait for Jaspr to actually be ready (with timeout fallback)
    await jasprReady.future.timeout(
      const Duration(seconds: 180),
      onTimeout: () {
        print('\x1B[33m!\x1B[0m Build taking longer than expected...');
        print('  \x1B[90mFirst builds can take 2-3 minutes. Run with --verbose for details.\x1B[0m');
      },
    );

    // Stop spinner and broadcast ready state
    if (isBuilding) {
      buildSpinner.stop();
      isBuilding = false;
    }
    devTools.broadcast('success', 'Ready!', details: 'Development server started');

    // Start proxy server on main port
    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler((request) => _proxyHandler(request, apiPort, jasprPort, hasApi, devToolsPort));

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
    print('  \x1B[90mProxy:\x1B[0m    $port');
    if (hasApi) {
      print('  \x1B[90mAPI:\x1B[0m      $apiPort');
    }
    print('  \x1B[90mJaspr:\x1B[0m    $jasprPort');
    print('  \x1B[90mWebdev:\x1B[0m   $webdevPort');
    print('  \x1B[90mDevTools:\x1B[0m $devToolsPort');
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Launch Tauri dev window if --desktop
    Process? tauriProcess;
    if (desktop) {
      tauriProcess = await _launchTauriDev(projectDir, port, verbose: verbose);
    }

    // Keep running until interrupted
    await ProcessSignal.sigint.watch().first;

    print('');
    print('\x1B[90mShutting down...\x1B[0m');

    tauriProcess?.kill();
    await devTools.stop();
    await proxyServer.close();
    await watcher.stop();
    tailwindProcess?.kill();
    apiProcess?.kill();
    jasprProcess.kill();

    return 0;
  }

  /// Launch Tauri in dev mode, pointing at the jaspr dev server
  Future<Process?> _launchTauriDev(String projectDir, int port, {bool verbose = false}) async {
    // Scaffold src-tauri/ if missing
    final tauriDir = Directory(p.join(projectDir, 'src-tauri'));
    if (!tauriDir.existsSync()) {
      print('\x1B[90m→\x1B[0m Scaffolding Tauri project...');
      final pubspec = File(p.join(projectDir, 'pubspec.yaml'));
      final content = await pubspec.readAsString();
      final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
      final projectName = nameMatch?.group(1)?.trim() ?? 'duxt_app';
      await TauriScaffold.scaffold(projectDir, projectName);
    }

    // Set devUrl in tauri.conf.json so Tauri points at the dev server
    final confFile = File(p.join(projectDir, 'src-tauri', 'tauri.conf.json'));
    final conf = jsonDecode(await confFile.readAsString()) as Map<String, dynamic>;
    final build = (conf['build'] as Map<String, dynamic>?) ?? {};
    build['devUrl'] = 'http://localhost:$port';
    conf['build'] = build;
    await confFile.writeAsString(jsonEncode(conf));

    // Wait for web assets to be ready before opening the window
    print('\x1B[90m→\x1B[0m Waiting for web assets to compile...');
    final client = HttpClient();
    for (var i = 0; i < 120; i++) {
      try {
        final req = await client.getUrl(Uri.parse('http://localhost:$port/main.client.dart.js'));
        final res = await req.close();
        await res.drain();
        if (res.statusCode == 200) {
          print('  Web assets ready');
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    client.close();

    print('\x1B[90m→\x1B[0m Launching Tauri desktop window...');

    final process = await Process.start(
      'cargo',
      ['tauri', 'dev'],
      workingDirectory: projectDir,
    );

    process.stdout.listen((data) {
      final output = utf8.decode(data).trim();
      for (final line in output.split('\n')) {
        if (line.trim().isNotEmpty) {
          print('\x1B[36m[desktop]\x1B[0m $line');
        }
      }
    });
    process.stderr.listen((data) {
      final output = utf8.decode(data).trim();
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;
        // Filter cargo compile progress noise
        if (line.contains('Compiling') || line.contains('Downloading') || line.contains('Updating')) {
          if (verbose) print('\x1B[90m[desktop]\x1B[0m $line');
        } else {
          print('\x1B[36m[desktop]\x1B[0m $line');
        }
      }
    });

    return process;
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
    int devToolsPort,
  ) async {
    final path = request.url.path;
    final isApi = hasApi && path.startsWith('api/');
    final targetPort = isApi ? apiPort : jasprPort;

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
      var responseBytes = await proxyResponse.fold<List<int>>(
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

      // Inject dev tools script into HTML responses
      final contentType = headers['content-type'] ?? '';
      if (contentType.contains('text/html')) {
        var html = utf8.decode(responseBytes);
        final script = _DevTools.overlayScript.replaceAll('__DEVTOOLS_PORT__', devToolsPort.toString());
        // Inject before </body>
        if (html.contains('</body>')) {
          html = html.replaceFirst('</body>', '$script</body>');
          responseBytes = utf8.encode(html);
          // Update content-length
          headers['content-length'] = responseBytes.length.toString();
        }
      }

      return shelf.Response(
        proxyResponse.statusCode,
        body: responseBytes,
        headers: headers,
      );
    } catch (e) {
      // For API requests, return JSON error
      if (isApi) {
        return shelf.Response.internalServerError(
          body: jsonEncode({
            'error': 'API server not available',
            'message': 'The API server is starting up. Please try again.',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // For asset requests (.js, .css, etc.), return 503 so browser retries
      final ext = p.extension(path).toLowerCase();
      if (['.js', '.css', '.map', '.json', '.woff', '.woff2', '.ttf', '.png', '.jpg', '.svg', '.ico'].contains(ext)) {
        return shelf.Response(
          503,
          body: 'Server starting...',
          headers: {
            'Content-Type': 'text/plain',
            'Retry-After': '2',
          },
        );
      }

      // For HTML document requests, return a nice loading page
      return shelf.Response.ok(
        _loadingPageHtml(devToolsPort),
        headers: {'Content-Type': 'text/html'},
      );
    }
  }

  /// Loading page HTML shown while Jaspr is building
  String _loadingPageHtml(int devToolsPort) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Building... | Duxt</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: system-ui, -apple-system, sans-serif;
      background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #e2e8f0;
    }
    .container { text-align: center; padding: 2rem; }
    .logo {
      font-size: 2.5rem;
      font-weight: 700;
      background: linear-gradient(135deg, #06b6d4 0%, #22d3ee 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 2rem;
    }
    .spinner {
      width: 48px;
      height: 48px;
      border: 3px solid rgba(6, 182, 212, 0.2);
      border-top-color: #06b6d4;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 1.5rem;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    h1 { font-size: 1.25rem; font-weight: 500; margin-bottom: 0.5rem; }
    p { color: #94a3b8; font-size: 0.875rem; }
    .status {
      margin-top: 2rem;
      padding: 1rem;
      background: rgba(6, 182, 212, 0.1);
      border-radius: 8px;
      border: 1px solid rgba(6, 182, 212, 0.2);
    }
    .status-dot {
      display: inline-block;
      width: 8px;
      height: 8px;
      background: #eab308;
      border-radius: 50%;
      margin-right: 8px;
      animation: pulse 1.5s ease infinite;
    }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">duxt</div>
    <div class="spinner"></div>
    <h1>Building your app...</h1>
    <p>The development server is compiling your code.</p>
    <div class="status">
      <span class="status-dot"></span>
      <span id="status-text">Connecting to build server...</span>
    </div>
  </div>
  <script>
    const statusEl = document.getElementById('status-text');
    const wsPort = $devToolsPort;
    let connected = false;

    function tryConnect() {
      const ws = new WebSocket('ws://localhost:' + wsPort);
      ws.onopen = () => {
        connected = true;
        statusEl.textContent = 'Connected - waiting for build...';
      };
      ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.type === 'success' || data.type === 'reload') {
            statusEl.textContent = 'Build complete! Reloading...';
            setTimeout(() => location.reload(), 500);
          } else if (data.type === 'building') {
            statusEl.textContent = data.details || 'Compiling...';
          } else if (data.type === 'error') {
            statusEl.textContent = 'Build error: ' + (data.details || 'Check terminal');
          }
        } catch (err) {}
      };
      ws.onclose = () => {
        if (!connected) {
          statusEl.textContent = 'Server starting...';
          setTimeout(tryConnect, 1000);
        }
      };
      ws.onerror = () => {};
    }

    tryConnect();

    // Also try refreshing periodically as fallback
    setTimeout(function checkReady() {
      fetch(location.href, { method: 'HEAD' })
        .then(r => { if (r.ok) location.reload(); else setTimeout(checkReady, 2000); })
        .catch(() => setTimeout(checkReady, 2000));
    }, 3000);
  </script>
</body>
</html>
''';
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
    final packagesToSync = ['duxt_ui', 'duxt'];
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

/// Dev tools overlay for showing build status toasts
class _DevTools {
  final int port;
  final List<WebSocketChannel> _clients = [];
  HttpServer? _server;
  String? _lastState; // Track last state to send to new clients

  _DevTools(this.port);

  /// Start the WebSocket server
  Future<void> start() async {
    final handler = webSocketHandler((WebSocketChannel webSocket, String? subprotocol) {
      _clients.add(webSocket);

      // Send welcome message
      webSocket.sink.add(jsonEncode({
        'type': 'connected',
        'message': 'Duxt DevTools connected',
      }));

      // Send current state to new client (fixes race condition where
      // client connects after build completed)
      if (_lastState != null) {
        try {
          webSocket.sink.add(_lastState!);
        } catch (_) {}
      }

      webSocket.stream.listen(
        (_) {},
        onDone: () => _clients.remove(webSocket),
        onError: (_) => _clients.remove(webSocket),
      );
    });

    _server = await shelf_io.serve(handler, 'localhost', port);
  }

  /// Broadcast a message to all connected clients
  void broadcast(String type, String message, {String? details}) {
    final payload = jsonEncode({
      'type': type,
      'message': message,
      if (details != null) 'details': details,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Store state for new clients (only track success/building states)
    if (type == 'success' || type == 'building') {
      _lastState = payload;
    }

    for (final client in _clients.toList()) {
      try {
        client.sink.add(payload);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  /// Stop the WebSocket server
  Future<void> stop() async {
    for (final client in _clients) {
      await client.sink.close();
    }
    _clients.clear();
    await _server?.close();
  }

  /// JavaScript to inject into HTML for dev overlay (uses inline styles for reliability)
  static String get overlayScript => r'''
<script>
(function() {
  const DEVTOOLS_WS_PORT = '__DEVTOOLS_PORT__';

  // All styles inline to avoid Tailwind compilation issues
  const styles = `
    @keyframes duxt-slide-in { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
    @keyframes duxt-slide-out { from { transform: translateX(0); opacity: 1; } to { transform: translateX(100%); opacity: 0; } }
    @keyframes duxt-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
    #duxt-devtools { position: fixed; bottom: 16px; right: 16px; z-index: 99999; display: flex; flex-direction: column; gap: 8px; font-family: system-ui, -apple-system, sans-serif; font-size: 14px; }
    #duxt-badge { position: fixed; bottom: 16px; left: 16px; z-index: 99998; display: flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 6px; background: linear-gradient(135deg, #0891b2 0%, #06b6d4 100%); color: white; font-size: 12px; font-weight: 600; box-shadow: 0 4px 14px rgba(6, 182, 212, 0.35); cursor: pointer; transition: all 0.2s ease; }
    #duxt-badge:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(6, 182, 212, 0.45); }
    .duxt-toast { display: flex; align-items: flex-start; gap: 12px; padding: 12px 16px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); min-width: 280px; max-width: 360px; }
    .duxt-toast.slide-in { animation: duxt-slide-in 0.3s ease; }
    .duxt-toast.slide-out { animation: duxt-slide-out 0.3s ease forwards; }
    .duxt-toast.success { background: #22c55e; color: white; }
    .duxt-toast.building { background: #eab308; color: white; }
    .duxt-toast.error { background: #ef4444; color: white; }
    .duxt-toast.info { background: #3b82f6; color: white; }
    .duxt-toast-icon { flex-shrink: 0; margin-top: 2px; }
    .duxt-toast-icon svg { width: 16px; height: 16px; }
    .duxt-toast-icon.spin svg { animation: duxt-spin 1s linear infinite; }
    .duxt-toast-content { flex: 1; min-width: 0; }
    .duxt-toast-title { font-weight: 500; }
    .duxt-toast-details { font-size: 12px; opacity: 0.9; margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  `;

  // Create container
  const container = document.createElement('div');
  container.id = 'duxt-devtools';

  // Add styles
  const styleEl = document.createElement('style');
  styleEl.textContent = styles;
  document.head.appendChild(styleEl);
  document.body.appendChild(container);

  // Add Duxt badge
  const badge = document.createElement('div');
  badge.id = 'duxt-badge';
  badge.innerHTML = '<svg style="width:14px;height:14px" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg><span>DEV</span>';
  badge.title = 'Duxt Development Mode';
  document.body.appendChild(badge);

  // Toast management
  let toasts = [];
  let buildingToast = null;

  // Icons as SVG strings
  const icons = {
    success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>',
    building: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v4m0 12v4M4.93 4.93l2.83 2.83m8.48 8.48l2.83 2.83M2 12h4m12 0h4M4.93 19.07l2.83-2.83m8.48-8.48l2.83-2.83"/></svg>',
    error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 8v4m0 4h.01"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4m0-4h.01"/></svg>'
  };

  function showToast(type, message, details, duration = 3000) {
    if (type !== 'building' && buildingToast) {
      removeToast(buildingToast);
      buildingToast = null;
    }

    const toast = document.createElement('div');
    toast.className = 'duxt-toast slide-in ' + type;
    const iconClass = type === 'building' ? 'duxt-toast-icon spin' : 'duxt-toast-icon';
    toast.innerHTML = '<div class="' + iconClass + '">' + (icons[type] || icons.info) + '</div>' +
      '<div class="duxt-toast-content">' +
        '<div class="duxt-toast-title">' + message + '</div>' +
        (details ? '<div class="duxt-toast-details">' + details + '</div>' : '') +
      '</div>';
    container.appendChild(toast);
    toasts.push(toast);

    if (type === 'building') {
      buildingToast = toast;
      return toast;
    }

    setTimeout(() => removeToast(toast), duration);
    return toast;
  }

  function removeToast(toast) {
    if (!toast || !toast.parentNode) return;
    toast.classList.remove('slide-in');
    toast.classList.add('slide-out');
    setTimeout(() => {
      toast.remove();
      toasts = toasts.filter(t => t !== toast);
    }, 300);
  }

  // WebSocket connection
  let ws;
  let reconnectAttempts = 0;

  function connect() {
    ws = new WebSocket('ws://localhost:' + DEVTOOLS_WS_PORT);
    ws.onopen = () => { reconnectAttempts = 0; console.log('[Duxt DevTools] Connected'); };
    ws.onmessage = (e) => { try { handleMessage(JSON.parse(e.data)); } catch(err) {} };
    ws.onclose = () => { if (reconnectAttempts < 5) { reconnectAttempts++; setTimeout(connect, 1000 * reconnectAttempts); } };
    ws.onerror = () => {};
  }

  function handleMessage(data) {
    switch (data.type) {
      case 'building': showToast('building', data.message || 'Building...', data.details); break;
      case 'success': showToast('success', data.message || 'Ready!', data.details, 2500); break;
      case 'reload': showToast('success', data.message || 'Hot Reloaded', data.details, 2000); setTimeout(() => location.reload(), 600); break;
      case 'error': showToast('error', data.message || 'Build Error', data.details, 6000); break;
      case 'info': showToast('info', data.message || 'Info', data.details); break;
    }
  }

  connect();
})();
</script>
''';
}
