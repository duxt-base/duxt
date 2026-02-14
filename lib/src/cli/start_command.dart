import 'dart:io';
import 'package:args/command_runner.dart';
import '../core/router_generator.dart';
import '../core/static_server.dart';

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
    print('\x1B[36m  Duxt\x1B[0m Production Server');
    print('');

    // Generate routes first
    print('\x1B[90m→\x1B[0m Generating routes...');
    await RouterGenerator.generate(projectDir);

    // Check if build exists
    final buildDir = Directory('$projectDir/build/jaspr');
    if (!buildDir.existsSync()) {
      print('\x1B[90m→\x1B[0m No production build found, building...');

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

    // Start server
    final staticServer = StaticFileServer(buildDir.path);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    server.listen((request) => staticServer.handleRequest(request));

    print('');
    print('\x1B[32m✓\x1B[0m Server running at \x1B[36mhttp://localhost:$port\x1B[0m');
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Open browser if requested
    if (openBrowser) {
      await _openBrowser('http://localhost:$port');
    }

    // Handle both SIGINT (Ctrl+C) and SIGTERM (kill)
    void shutdown() {
      print('');
      print('\x1B[90mShutting down...\x1B[0m');
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

  Future<int> _findFreePort() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
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
