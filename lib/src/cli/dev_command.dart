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
import '../core/jaspr_cli.dart';
import '../core/router_generator.dart';
import '../core/watcher.dart';
import '../core/tailwind.dart';
import '../core/package_sync.dart';
import '../core/build_events.dart';
import 'tauri_scaffold.dart';

/// Command to start development server
/// Usage: duxt dev [--port=4000]
/// Ports are auto-incremented: proxy=port, api=port+1, jaspr=port+2, webdev=port+3, jaspr-proxy=port+4
/// Run multiple apps: duxt dev --port=4000 and duxt dev --port=5000
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
      help:
          'Base port (api=+1, jaspr=+2, webdev=+3, jaspr-proxy=+4). Use different ports to run multiple apps.',
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
      'perf',
      defaultsTo: false,
      help: 'Print rebuild stage timings (save->build->reload)',
    );
    argParser.addFlag(
      'reload',
      defaultsTo: false,
      help:
          'Use module reload mode for jaspr serve (faster but can be less stable).',
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
    final jasprProxyPort = (port + 4).toString();
    final noApi = argResults!['no-api'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final perf = argResults!['perf'] as bool;
    final reload = argResults!['reload'] as bool;
    final desktop = argResults!['desktop'] as bool;
    final projectDir = Directory.current.path;
    final jasprMode = reload ? 'reload' : 'refresh';
    final perfTracer = _RebuildPerfTracer(
      enabled: perf || verbose,
      projectDir: projectDir,
    );

    // Check if this is a Duxt project
    if (!File('$projectDir/duxt.config.dart').existsSync() &&
        !Directory('$projectDir/lib').existsSync()) {
      print(
        'Error: Not a Duxt project. Run this command in a Duxt project directory.',
      );
      return 1;
    }

    print('');
    print('\x1B[36m               88\x1B[0m');
    print('\x1B[36m               88\x1B[0m');
    print(
      '\x1B[36m      .d88888b 88  db       db  db        db d88888888b\x1B[0m',
    );
    print(
      '\x1B[36m    .8P       Y88  88       88   `8b    d8\'      88\x1B[0m',
    );
    print(
      '\x1B[36m    88         88  88       88     `8bd8\'        88\x1B[0m',
    );
    print('\x1B[36m    88         88  88       88     .dPYb.        88\x1B[0m');
    print('\x1B[36m    `8L       d89  88b     d88   .8P    Y8.      88\x1B[0m');
    print(
      '\x1B[36m     `Y888888P8J    ~Y88888\'88  dP        Yb     `Y88P\x1B[0m',
    );
    print('');
    print('\x1B[36m                     oooooooooooooooooooo\x1B[0m');
    print('');

    final totalTimer = Stopwatch()..start();

    // Run pub get if needed
    final pubspecLock = File(p.join(projectDir, 'pubspec.lock'));
    final packageConfig = File(
      p.join(projectDir, '.dart_tool', 'package_config.json'),
    );
    if (!pubspecLock.existsSync() || !packageConfig.existsSync()) {
      print('\x1B[90m→\x1B[0m Installing dependencies...');
      final result = await Process.run(
          'dart', ['pub', 'get'],
          workingDirectory: projectDir);
      if (result.exitCode != 0) {
        print('\x1B[31m✗\x1B[0m Failed to install dependencies');
        print(result.stderr);
        return 1;
      }
      print('  Done');
    }

    // Run init steps in parallel — these are all independent
    print('\x1B[90m→\x1B[0m Initializing...');
    late PackageSyncResult syncResult;
    late TailwindCompileResult tailwindResult;
    final twTimer = Stopwatch()..start();

    await Future.wait([
      PackageSync.sync(projectDir).then((r) => syncResult = r),
      DuxtTailwind.compile(projectDir).then((r) => tailwindResult = r),
      _cleanupStaleBuildRunners(projectDir, verbose: verbose),
      RouterGenerator.generate(projectDir),
    ]);

    twTimer.stop();
    final tailwindOk = tailwindResult.ok;

    // Report results
    if (!syncResult.packageConfigFound) {
      print('  \x1B[33m!\x1B[0m Run "dart pub get" first');
    } else {
      for (final pkg in syncResult.syncedPackages) {
        print('  Synced $pkg');
      }
    }
    if (tailwindResult.ok) {
      print('  Compiled styles.css \x1B[90m${twTimer.elapsedMilliseconds}ms\x1B[0m');
    } else {
      switch (tailwindResult.reason) {
        case TailwindFailureReason.noInputFile:
          print('  \x1B[90mNo styles.tw.css found, skipping\x1B[0m');
          break;
        case TailwindFailureReason.binaryNotFound:
          print(
            '  \x1B[33m!\x1B[0m Tailwind compilation skipped (tailwindcss not found)',
          );
          break;
        case TailwindFailureReason.compileFailed:
          print('  \x1B[31mTailwind error:\x1B[0m ${tailwindResult.stderr}');
          break;
        case null:
          break;
      }
    }
    print('  Routes generated');

    Process? apiProcess;
    Process? jasprProcess;
    Process? tailwindProcess;
    HttpServer? proxyServer;
    final devTools = _DevTools();

    // Start file watcher for route generation and content hot reload
    print('\x1B[90m→\x1B[0m Starting file watcher...');
    final watcher = DuxtWatcher(
      projectDir,
      onFileChange: (path, changeType) async {
        perfTracer.onSourceChange(path);

        // Content-only hot reload: markdown/yaml changes skip build_runner entirely
        if (path.contains('/content/') &&
            (path.endsWith('.md') || path.endsWith('.mdx') ||
             path.endsWith('.yaml') || path.endsWith('.json'))) {
          final relativePath = p.relative(path, from: projectDir);
          print('\x1B[36m↻\x1B[0m Content updated: $relativePath');
          devTools.broadcast('reload', 'Content Updated', details: relativePath);
          return;
        }

        if (_shouldRegenerateRoutes(path, changeType)) {
          print('\x1B[33m↻\x1B[0m Route change: $path');
          final routeGenStopwatch = Stopwatch()..start();
          await RouterGenerator.generate(projectDir);
          routeGenStopwatch.stop();
          perfTracer.onRouteGenerationComplete(
            path,
            routeGenStopwatch.elapsed,
          );
        }
      },
    );
    await watcher.start();

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

    }

    // Start Tailwind in watch mode
    if (tailwindOk) {
      print('\x1B[90m→\x1B[0m Starting Tailwind watcher...');
      tailwindProcess = await DuxtTailwind.watch(projectDir, verbose: verbose);
    }

    // Start jaspr serve on internal port
    print('\x1B[90m→\x1B[0m Starting Jaspr server on port $jasprPort...');
    print(
      '  \x1B[90mJaspr mode: $jasprMode${reload ? ' (module reload)' : ' (full refresh)'}\x1B[0m',
    );

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
    final localJasprBin = p.join(
      p.dirname(projectDir),
      'jaspr',
      'packages',
      'jaspr_cli',
      'bin',
      'jaspr.dart',
    );
    final globalJasprPath = JasprCli.globalPath();
    var globalJasprSnapshot = JasprCli.globalSnapshotPath();

    String jasprCmd;
    List<String> jasprArgs;

    if (File(localJasprBin).existsSync()) {
      // Use local jaspr via dart run
      print('  \x1B[90mUsing local jaspr\x1B[0m');
      jasprCmd = 'dart';
      jasprArgs = [
        'run',
        localJasprBin,
        'serve',
        '--mode',
        jasprMode,
        '--port',
        jasprPort.toString(),
        '--web-port',
        webdevPort,
        '--proxy-port',
        jasprProxyPort,
      ];
    } else {
      // Use global jaspr
      if (!File(globalJasprPath).existsSync() && globalJasprSnapshot == null) {
        print('\x1B[33m!\x1B[0m jaspr_cli not found, installing...');
        await Process.run('dart', ['pub', 'global', 'activate', 'jaspr_cli']);
        globalJasprSnapshot = JasprCli.globalSnapshotPath();
      }

      if (globalJasprSnapshot != null) {
        print('  \x1B[90mUsing global jaspr snapshot\x1B[0m');
        jasprCmd = 'dart';
        jasprArgs = [
          globalJasprSnapshot,
          'serve',
          '--mode',
          jasprMode,
          '--port',
          jasprPort.toString(),
          '--web-port',
          webdevPort,
          '--proxy-port',
          jasprProxyPort,
        ];
      } else {
        jasprCmd = JasprCli.resolveCommand();
        jasprArgs = [
          'serve',
          '--mode',
          jasprMode,
          '--port',
          jasprPort.toString(),
          '--web-port',
          webdevPort,
          '--proxy-port',
          jasprProxyPort,
        ];
      }
    }

    jasprProcess = await Process.start(
      jasprCmd,
      jasprArgs,
      workingDirectory: projectDir,
      runInShell: JasprCli.shouldRunInShell(jasprCmd),
    );

    // Track build state for spinner and ready state
    var isBuilding = false;
    var buildSpinner = _Spinner('Building');
    final jasprReady = Completer<void>();
    var useDaemonEvents = false; // Once daemon connects, skip stdout parsing for builds
    Stopwatch? rebuildTimer;
    BuildEventClient? buildEventClient;

    void handleJasprLine(String rawLine, {required bool fromStderr}) {
      final line = rawLine.trim();
      if (line.isEmpty) return;

      final isBuildStartMarker = !fromStderr &&
          (line.contains('Rebuilding web assets') ||
              line.contains('Building web assets') ||
              line.contains('About to build'));
      final isCompileDoneMarker =
          !fromStderr && line.contains('Built with build_runner/jit');
      final isReloadDoneMarker = !fromStderr &&
          (line.contains('Rebuilt web assets') ||
              line.contains('Done building web assets') ||
              line.contains('Server application reloaded'));

      if (!fromStderr && verbose) {
        print('\x1B[34m[web]\x1B[0m $line');
      }

      // Once daemon events are active, only handle errors and ready signal from stdout
      if (!useDaemonEvents) {
        if (isBuildStartMarker) {
          if (!isBuilding) {
            isBuilding = true;
            rebuildTimer = Stopwatch()..start();
            perfTracer.onBuildStarted(line);
            if (!verbose) buildSpinner.start();
            devTools.broadcast(
              'building',
              'Building...',
              details: 'Compiling web assets',
            );
          }
        } else if (isReloadDoneMarker) {
          perfTracer.onReloadCompleted(line);
          if (isBuilding) {
            rebuildTimer?.stop();
            final ms = rebuildTimer?.elapsedMilliseconds ?? 0;
            if (!verbose) buildSpinner.stop();
            isBuilding = false;
            print('\x1B[32m↻\x1B[0m Rebuilt in \x1B[1m${ms}ms\x1B[0m');
            devTools.broadcast('reload', 'Hot Reloaded', details: '${ms}ms');
          }
        }
      }

      if (isCompileDoneMarker) {
        perfTracer.onCompileCompleted(line);
      }

      if (line.contains('[ERROR]') ||
          (line.contains('Error') && !line.contains('no-op'))) {
        perfTracer.onBuildError(line);
        if (!verbose) buildSpinner.stop();
        isBuilding = false;
        print('\x1B[31m[web]\x1B[0m $line');
        devTools.broadcast(
          'error',
          fromStderr ? 'Error' : 'Build Error',
          details: line.length > 80 ? '${line.substring(0, 80)}...' : line,
        );
      } else if (fromStderr && verbose) {
        print('\x1B[31m[web]\x1B[0m $line');
      }

      // Signal ready when server is serving
      if (!jasprReady.isCompleted &&
          (line.contains('Serving at') ||
              line.contains('✓ [CLI] Server started.') ||
              line.contains('✓ Ready!') ||
              line == 'Ready!')) {
        totalTimer.stop();
        print('\x1B[32m✓\x1B[0m Server ready in \x1B[1m${(totalTimer.elapsedMilliseconds / 1000).toStringAsFixed(1)}s\x1B[0m');
        jasprReady.complete();
      }
    }

    // Stream buffering: accumulate partial lines across chunks
    var stdoutBuffer = '';
    var stderrBuffer = '';

    void parseChunk(
      String chunk, {
      required bool fromStderr,
    }) {
      final normalized = chunk.replaceAll('\r', '\n');
      final currentBuffer = fromStderr ? stderrBuffer : stdoutBuffer;
      final combined = '$currentBuffer$normalized';
      final parts = combined.split('\n');
      final trailing = parts.removeLast();

      if (fromStderr) {
        stderrBuffer = trailing;
      } else {
        stdoutBuffer = trailing;
      }

      for (final line in parts) {
        handleJasprLine(line, fromStderr: fromStderr);
      }
    }

    jasprProcess.stdout
        .transform(utf8.decoder)
        .listen((chunk) => parseChunk(chunk, fromStderr: false));
    jasprProcess.stderr
        .transform(utf8.decoder)
        .listen((chunk) => parseChunk(chunk, fromStderr: true));

    // Wait for Jaspr to actually be ready (with timeout fallback)
    await jasprReady.future.timeout(
      const Duration(seconds: 180),
      onTimeout: () {
        print('\x1B[33m!\x1B[0m Build taking longer than expected...');
        print(
          '  \x1B[90mFirst builds can take 2-3 minutes. Run with --verbose for details.\x1B[0m',
        );
      },
    );

    // Stop spinner and broadcast ready state
    if (isBuilding) {
      buildSpinner.stop();
      isBuilding = false;
    }
    devTools.broadcast('success', 'Ready!', details: 'Development server started');

    // Connect to build daemon for direct build events (replaces stdout parsing)
    buildEventClient = BuildEventClient(
      onBuildEvent: (type, {String? error}) {
        switch (type) {
          case BuildEventType.started:
            if (!isBuilding) {
              isBuilding = true;
              rebuildTimer = Stopwatch()..start();
              perfTracer.onBuildStarted('daemon:started');
              if (!verbose) buildSpinner.start();
              devTools.broadcast('building', 'Building...', details: 'Compiling web assets');
            }
          case BuildEventType.succeeded:
            perfTracer.onReloadCompleted('daemon:succeeded');
            if (isBuilding) {
              rebuildTimer?.stop();
              final ms = rebuildTimer?.elapsedMilliseconds ?? 0;
              if (!verbose) buildSpinner.stop();
              isBuilding = false;
              print('\x1B[32m↻\x1B[0m Rebuilt in \x1B[1m${ms}ms\x1B[0m');
              devTools.broadcast('reload', 'Hot Reloaded', details: '${ms}ms');
            }
          case BuildEventType.failed:
            perfTracer.onBuildError(error ?? 'Build failed');
            rebuildTimer?.stop();
            if (!verbose) buildSpinner.stop();
            isBuilding = false;
            final msg = error ?? 'Build failed';
            print('\x1B[31m[build]\x1B[0m $msg');
            devTools.broadcast('error', 'Build Error', details: msg.length > 80 ? '${msg.substring(0, 80)}...' : msg);
        }
      },
      onLog: (message, {bool isError = false}) {
        if (verbose || isError) {
          print('\x1B[${isError ? '31' : '90'}m[build]\x1B[0m $message');
        }
      },
    );

    final connected = await buildEventClient.connect(projectDir);
    if (connected) {
      useDaemonEvents = true;
      if (verbose) print('\x1B[90m[build]\x1B[0m Connected to build daemon (direct events)');
    } else {
      if (verbose) print('\x1B[90m[build]\x1B[0m Falling back to stdout parsing for build events');
    }

    // Start proxy server on main port (also serves DevTools WebSocket at /_duxt/ws)
    final wsHandler = webSocketHandler((
      WebSocketChannel webSocket,
      String? subprotocol,
    ) {
      devTools.addClient(webSocket);
    });

    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler((request) {
      if (request.url.path == '_duxt/ws') {
        return wsHandler(request);
      }
      return _proxyHandler(request, apiPort, jasprPort, hasApi, port);
    });

    proxyServer = await shelf_io.serve(handler, 'localhost', port);

    // Detect project mode
    final mode = _detectMode(projectDir);
    final modeLabel = _getModeLabel(mode);
    final modeColor = _getModeColor(mode);

    print('\x1B[32m✓\x1B[0m Ready!');
    print('');
    print('  \x1B[1mApp:\x1B[0m    \x1B[36mhttp://localhost:$port\x1B[0m');
    if (hasApi) {
      print(
        '  \x1B[1mAPI:\x1B[0m    \x1B[36mhttp://localhost:$port/api\x1B[0m',
      );
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
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Launch Tauri dev window if --desktop
    Process? tauriProcess;
    if (desktop) {
      tauriProcess = await _launchTauriDev(projectDir, port, verbose: verbose);
    }

    // Keep running until interrupted (Ctrl+C) or terminated externally.
    await _waitForShutdownSignal();

    print('');
    print('\x1B[90mShutting down...\x1B[0m');

    await buildEventClient.close();
    await _terminateProcess(tauriProcess);
    await proxyServer.close();
    devTools.close();
    await watcher.stop();
    await _terminateProcess(tailwindProcess);
    await _terminateProcess(apiProcess);
    await _terminateProcess(jasprProcess);

    return 0;
  }

  Future<void> _waitForShutdownSignal() async {
    final signalFutures = <Future<ProcessSignal>>[
      ProcessSignal.sigint.watch().first,
    ];

    if (Platform.isMacOS || Platform.isLinux) {
      signalFutures.add(ProcessSignal.sigterm.watch().first);
      signalFutures.add(ProcessSignal.sighup.watch().first);
    }

    await Future.any(signalFutures);
  }

  Future<void> _terminateProcess(
    Process? process, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (process == null) return;

    if (Platform.isWindows) {
      process.kill();
      try {
        await process.exitCode.timeout(timeout);
      } on TimeoutException {
        process.kill();
      }
      return;
    }

    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Best effort shutdown.
      }
    }
  }

  /// Launch Tauri in dev mode, pointing at the jaspr dev server
  Future<Process?> _launchTauriDev(
    String projectDir,
    int port, {
    bool verbose = false,
  }) async {
    // Scaffold src-tauri/ if missing
    final tauriDir = Directory(p.join(projectDir, 'src-tauri'));
    if (!tauriDir.existsSync()) {
      print('\x1B[90m→\x1B[0m Scaffolding Tauri project...');
      final pubspec = File(p.join(projectDir, 'pubspec.yaml'));
      final content = await pubspec.readAsString();
      final nameMatch = RegExp(
        r'^name:\s*(.+)$',
        multiLine: true,
      ).firstMatch(content);
      final projectName = nameMatch?.group(1)?.trim() ?? 'duxt_app';
      await TauriScaffold.scaffold(projectDir, projectName);
    }

    // Set devUrl in tauri.conf.json so Tauri points at the dev server
    final confFile = File(p.join(projectDir, 'src-tauri', 'tauri.conf.json'));
    final conf =
        jsonDecode(await confFile.readAsString()) as Map<String, dynamic>;
    final build = (conf['build'] as Map<String, dynamic>?) ?? {};
    build['devUrl'] = 'http://localhost:$port';
    conf['build'] = build;
    await confFile.writeAsString(jsonEncode(conf));

    // Wait for web assets to be ready before opening the window
    print('\x1B[90m→\x1B[0m Waiting for web assets to compile...');
    final client = HttpClient();
    for (var i = 0; i < 120; i++) {
      try {
        final jsReq = await client.getUrl(
          Uri.parse('http://localhost:$port/main.client.dart.js'),
        );
        final jsRes = await jsReq.close();
        await jsRes.drain();

        if (jsRes.statusCode == 200) {
          print('  Web assets ready');
          break;
        }

        // Some SSR pages can be served without a client bundle.
        final htmlReq =
            await client.getUrl(Uri.parse('http://localhost:$port/'));
        final htmlRes = await htmlReq.close();
        final html = await utf8.decoder.bind(htmlRes).join();
        final isLoadingPage = html.contains('name="duxt-loading" content="1"');
        if (htmlRes.statusCode == 200 && !isLoadingPage) {
          print('  App server ready');
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    client.close();

    print('\x1B[90m→\x1B[0m Launching Tauri desktop window...');

    final process = await Process.start(
        'cargo', ['tauri', 'dev'],
        workingDirectory: projectDir);

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
        if (line.contains('Compiling') ||
            line.contains('Downloading') ||
            line.contains('Updating')) {
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
      'Access-Control-Allow-Headers':
          'Origin, Content-Type, Accept, Authorization',
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

  bool _shouldRegenerateRoutes(String path, DuxtWatchChangeType changeType) {
    if (path.contains('/.generated/')) return false;

    final inPages = path.contains('/pages/');
    final inContent = path.contains('/content/');
    final inLayouts = path.contains('/layouts/');
    if (!inPages && !inContent && !inLayouts) return false;

    // Route shape only changes on add/remove/rename (rename is remove+add).
    return changeType == DuxtWatchChangeType.add ||
        changeType == DuxtWatchChangeType.remove;
  }

  Future<void> _cleanupStaleBuildRunners(
    String projectDir, {
    bool verbose = false,
  }) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    try {
      final result = await Process.run('pkill', [
        '-f',
        'build_runner.*${projectDir.replaceAll('/', '\\/')}',
      ]);

      // Give the OS a short window to release resources when a process was killed.
      if (result.exitCode == 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      } else if (verbose && result.exitCode > 1) {
        print('  \x1B[90mUnable to clean stale build_runner processes\x1B[0m');
      }
    } on ProcessException {
      if (verbose) {
        print('  \x1B[90mpkill not available, skipping process cleanup\x1B[0m');
      }
    }
  }

  /// Proxy handler that routes /api/* to API server and rest to Jaspr
  Future<shelf.Response> _proxyHandler(
    shelf.Request request,
    int apiPort,
    int jasprPort,
    bool hasApi,
    int proxyPort,
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

      // Intercept 404 for client JS — in DDC dev mode, Jaspr's SSR injects
      // a <script src="main.client.dart.js"> tag but DDC uses module loading
      // instead of standalone JS. Return a stub so the browser doesn't show
      // console errors. SSR renders the full page; client hydration works in
      // production builds (dart2js).
      if (proxyResponse.statusCode == 404 && path.endsWith('.client.dart.js')) {
        proxyResponse.drain<void>();
        return shelf.Response.ok(
          '// [Duxt] SSR mode — client JS served via DDC modules in dev\n',
          headers: {'Content-Type': 'application/javascript'},
        );
      }

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

      // Inject dev tools script and clean up HTML responses
      final contentType = headers['content-type'] ?? '';
      if (contentType.contains('text/html')) {
        var html = utf8.decode(responseBytes);
        // Remove Jaspr's client JS script tag — DDC dev mode uses modules,
        // not standalone JS. This prevents a useless 404 network request.
        html = html.replaceAll(RegExp(r'<script[^>]+src="[^"]*\.client\.dart\.js"[^>]*>\s*</script>'), '');
        final script = _DevTools.overlayScript.replaceAll(
          '__PROXY_PORT__',
          proxyPort.toString(),
        );
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

      // For asset requests (.js, .css, etc.), return 503 with correct MIME type
      // so the browser doesn't reject them due to strict MIME checking
      final ext = p.extension(path).toLowerCase();
      const mimeTypes = {
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.map': 'application/json',
        '.json': 'application/json',
        '.woff': 'font/woff',
        '.woff2': 'font/woff2',
        '.ttf': 'font/ttf',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon',
      };
      if (mimeTypes.containsKey(ext)) {
        return shelf.Response(
          503,
          body: ext == '.css' ? '/* Server starting... */' : ext == '.js' ? '// Server starting...' : '',
          headers: {
            'Content-Type': mimeTypes[ext]!,
            'Retry-After': '2',
          },
        );
      }

      // For HTML document requests, return a nice loading page
      return shelf.Response.ok(
        _loadingPageHtml(proxyPort),
        headers: {'Content-Type': 'text/html'},
      );
    }
  }

  /// Loading page HTML shown while Jaspr is building
  String _loadingPageHtml(int proxyPort) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="duxt-loading" content="1">
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
    let connected = false;

    function checkReady() {
      fetch('/', { cache: 'no-store' })
        .then(r => r.text())
        .then(html => {
          const stillLoading = html.includes('name="duxt-loading" content="1"');
          if (!stillLoading) {
            statusEl.textContent = 'Build complete! Reloading...';
            location.reload();
            return;
          }
          statusEl.textContent = 'Waiting for app server...';
          setTimeout(checkReady, 1200);
        })
        .catch(() => setTimeout(checkReady, 2000));
    }

    function tryConnect() {
      const ws = new WebSocket('ws://localhost:$proxyPort/_duxt/ws');
      ws.onopen = () => {
        connected = true;
        statusEl.textContent = 'Connected - waiting for build...';
      };
      ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.type === 'success' || data.type === 'reload') {
            statusEl.textContent = 'Build complete! Verifying...';
            checkReady();
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
    setTimeout(checkReady, 3000);
  </script>
</body>
</html>
''';
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

class _PendingSourceChange {
  final String path;
  final DateTime changedAt;
  Duration? routeGenerationDuration;

  _PendingSourceChange({
    required this.path,
    required this.changedAt,
  });
}

class _ActiveRebuildCycle {
  final int id;
  final DateTime buildStartedAt;
  _PendingSourceChange? sourceChange;
  DateTime? compileCompletedAt;

  _ActiveRebuildCycle({
    required this.id,
    required this.buildStartedAt,
    required this.sourceChange,
  });
}

/// Captures per-rebuild timings:
/// save -> build start -> compile complete -> reload complete.
class _RebuildPerfTracer {
  final bool enabled;
  final String projectDir;

  int _nextCycleId = 1;
  _PendingSourceChange? _pendingSourceChange;
  _ActiveRebuildCycle? _activeCycle;

  _RebuildPerfTracer({
    required this.enabled,
    required this.projectDir,
  });

  void onSourceChange(String path) {
    final sourceChange = _PendingSourceChange(
      path: path,
      changedAt: _estimateChangedAt(path),
    );

    final active = _activeCycle;
    if (active != null && active.sourceChange == null) {
      final saveToBuildMs = active.buildStartedAt
          .difference(sourceChange.changedAt)
          .inMilliseconds;
      // Route watcher callbacks are debounced; allow short overlap and backfill.
      if (saveToBuildMs >= -500 && saveToBuildMs <= 5000) {
        active.sourceChange = sourceChange;
        _printPerf([
          'rebuild=${active.id}',
          'phase=source_backfill',
          'file=${_relativePath(sourceChange.path)}',
          'save_to_build_ms=$saveToBuildMs',
        ]);
        return;
      }
    }

    _pendingSourceChange = sourceChange;
  }

  void onRouteGenerationComplete(String path, Duration duration) {
    final active = _activeCycle;
    if (active != null &&
        active.sourceChange != null &&
        _normalizePath(path) == _normalizePath(active.sourceChange!.path)) {
      active.sourceChange!.routeGenerationDuration = duration;
      return;
    }

    final pending = _pendingSourceChange;
    if (pending == null) return;
    if (_normalizePath(path) != _normalizePath(pending.path)) return;
    pending.routeGenerationDuration = duration;
  }

  void onBuildStarted(String marker) {
    if (_activeCycle != null && enabled) {
      _printPerf([
        'rebuild=${_activeCycle!.id}',
        'phase=aborted',
        'reason=next_build_started_before_reload',
      ]);
    }

    final cycle = _ActiveRebuildCycle(
      id: _nextCycleId++,
      buildStartedAt: DateTime.now(),
      sourceChange: _pendingSourceChange,
    );
    _activeCycle = cycle;
    _pendingSourceChange = null;

    final source = cycle.sourceChange;
    final saveToBuildMs = source == null
        ? null
        : cycle.buildStartedAt.difference(source.changedAt).inMilliseconds;
    final routeGenMs = source?.routeGenerationDuration?.inMilliseconds;

    _printPerf([
      'rebuild=${cycle.id}',
      'phase=build_start',
      if (source != null) 'file=${_relativePath(source.path)}',
      if (saveToBuildMs != null) 'save_to_build_ms=$saveToBuildMs',
      if (routeGenMs != null) 'route_gen_ms=$routeGenMs',
      'marker=${_sanitizeMarker(marker)}',
    ]);
  }

  void onCompileCompleted(String marker) {
    final cycle = _activeCycle;
    if (cycle == null) return;
    if (cycle.compileCompletedAt != null) return;

    cycle.compileCompletedAt = DateTime.now();
    final buildMs = cycle.compileCompletedAt!
        .difference(cycle.buildStartedAt)
        .inMilliseconds;

    _printPerf([
      'rebuild=${cycle.id}',
      'phase=build_complete',
      'build_ms=$buildMs',
      'marker=${_sanitizeMarker(marker)}',
    ]);
  }

  void onReloadCompleted(String marker) {
    final cycle = _activeCycle;
    if (cycle == null) return;

    final reloadAt = DateTime.now();
    final compileAt = cycle.compileCompletedAt ?? reloadAt;
    final source = cycle.sourceChange;

    final saveToBuildMs = source == null
        ? null
        : cycle.buildStartedAt.difference(source.changedAt).inMilliseconds;
    final routeGenMs = source?.routeGenerationDuration?.inMilliseconds;
    final buildMs = compileAt.difference(cycle.buildStartedAt).inMilliseconds;
    final reloadMs = reloadAt.difference(compileAt).inMilliseconds;
    final totalFromBuildMs =
        reloadAt.difference(cycle.buildStartedAt).inMilliseconds;
    final totalFromSaveMs = source == null
        ? null
        : reloadAt.difference(source.changedAt).inMilliseconds;

    _printPerf([
      'rebuild=${cycle.id}',
      'phase=reload_complete',
      if (source != null) 'file=${_relativePath(source.path)}',
      if (saveToBuildMs != null) 'save_to_build_ms=$saveToBuildMs',
      if (routeGenMs != null) 'route_gen_ms=$routeGenMs',
      'build_ms=$buildMs',
      'reload_ms=$reloadMs',
      'total_from_build_ms=$totalFromBuildMs',
      if (totalFromSaveMs != null) 'total_from_save_ms=$totalFromSaveMs',
      'marker=${_sanitizeMarker(marker)}',
    ]);

    _activeCycle = null;
  }

  void onBuildError(String line) {
    final cycle = _activeCycle;
    if (cycle == null) return;
    final elapsedMs =
        DateTime.now().difference(cycle.buildStartedAt).inMilliseconds;
    _printPerf([
      'rebuild=${cycle.id}',
      'phase=error',
      'elapsed_ms=$elapsedMs',
      'line=${_sanitizeMarker(line)}',
    ]);
  }

  String _relativePath(String path) {
    final normalized = _normalizePath(path);
    final relative = p.relative(normalized, from: _normalizePath(projectDir));
    if (relative.startsWith('..')) return normalized;
    return relative;
  }

  String _normalizePath(String path) => p.normalize(path).replaceAll('\\', '/');

  DateTime _estimateChangedAt(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return file.lastModifiedSync();
      }
    } catch (_) {}
    return DateTime.now();
  }

  String _sanitizeMarker(String marker) =>
      marker.replaceAll('|', '/').replaceAll(RegExp(r'\s+'), ' ').trim();

  void _printPerf(List<String> fields) {
    if (!enabled) return;
    print('\x1B[90m[perf]\x1B[0m ${fields.join(' | ')}');
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

/// Dev tools overlay for showing build status toasts.
/// Runs on the same port as the proxy server at /_duxt/ws.
class _DevTools {
  final List<WebSocketChannel> _clients = [];
  String? _lastState;

  /// Add a new WebSocket client (called by the proxy handler).
  void addClient(WebSocketChannel webSocket) {
    _clients.add(webSocket);

    webSocket.sink.add(
      jsonEncode({'type': 'connected', 'message': 'Duxt DevTools connected'}),
    );

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
  }

  /// Broadcast a message to all connected clients.
  void broadcast(String type, String message, {String? details}) {
    final payload = jsonEncode({
      'type': type,
      'message': message,
      if (details != null) 'details': details,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Track last state so new clients get the current status.
    // Clear building state on reload/error/success so reconnecting
    // clients don't see a stale "Building..." toast.
    if (type == 'building') {
      _lastState = payload;
    } else if (type == 'reload' || type == 'error' || type == 'success') {
      _lastState = null;
    }

    for (final client in _clients.toList()) {
      try {
        client.sink.add(payload);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  /// Close all connected clients.
  void close() {
    for (final client in _clients.toList()) {
      try {
        client.sink.close();
      } catch (_) {}
    }
    _clients.clear();
  }

  /// JavaScript to inject into HTML for dev overlay (uses inline styles for reliability)
  static String get overlayScript => r'''
<script>
(function() {
  const PROXY_PORT = '__PROXY_PORT__';

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
    ws = new WebSocket('ws://localhost:' + PROXY_PORT + '/_duxt/ws');
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
