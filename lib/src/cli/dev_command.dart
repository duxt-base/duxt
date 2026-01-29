import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../core/router_generator.dart';
import '../core/watcher.dart';

/// Command to start development server
/// Usage: duxt dev [--port=4000] [--api-port=3001]
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
      help: 'Port for Jaspr server',
    );
    argParser.addOption(
      'api-port',
      defaultsTo: '3001',
      help: 'Port for API server',
    );
    argParser.addFlag(
      'no-api',
      defaultsTo: false,
      help: 'Skip starting the API server',
    );
  }

  @override
  Future<int> run() async {
    final port = argResults!['port'] as String;
    final apiPort = argResults!['api-port'] as String;
    final noApi = argResults!['no-api'] as bool;
    final projectDir = Directory.current.path;

    // Check if this is a Duxt project
    if (!File('$projectDir/duxt.config.dart').existsSync() &&
        !Directory('$projectDir/lib').existsSync()) {
      print('Error: Not a Duxt project. Run this command in a Duxt project directory.');
      return 1;
    }

    print('');
    print('\x1B[36m╭─────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1mDuxt\x1B[0m Development Server          \x1B[36m│\x1B[0m');
    print('\x1B[36m╰─────────────────────────────────────╯\x1B[0m');
    print('');

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

    // Start API server if server/main.dart exists
    if (!noApi && File('$projectDir/server/main.dart').existsSync()) {
      print('\x1B[90m→\x1B[0m Starting API server...');
      apiProcess = await Process.start(
        'dart',
        ['run', 'server/main.dart'],
        workingDirectory: projectDir,
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

    // Start jaspr serve
    print('\x1B[90m→\x1B[0m Starting Jaspr server...');

    final home = Platform.environment['HOME'] ?? '';
    final jasprPath = '$home/.pub-cache/bin/jaspr';

    if (!File(jasprPath).existsSync()) {
      print('\x1B[33m!\x1B[0m jaspr_cli not found, installing...');
      await Process.run('dart', ['pub', 'global', 'activate', 'jaspr_cli']);
    }

    jasprProcess = await Process.start(
      jasprPath,
      ['serve', '--port', port],
      workingDirectory: projectDir,
    );

    jasprProcess.stdout.listen((data) {
      final output = String.fromCharCodes(data).trim();
      if (output.isNotEmpty) {
        print('\x1B[34m[JASPR]\x1B[0m $output');
      }
    });
    jasprProcess.stderr.listen((data) {
      final output = String.fromCharCodes(data).trim();
      if (output.isNotEmpty) print('\x1B[31m[JASPR]\x1B[0m $output');
    });

    // Wait for servers to start
    await Future.delayed(Duration(seconds: 2));

    print('');
    print('\x1B[32m✓\x1B[0m Ready!');
    print('');
    print('  \x1B[1mApp:\x1B[0m  \x1B[36mhttp://localhost:$port\x1B[0m');
    if (apiProcess != null) {
      print('  \x1B[1mAPI:\x1B[0m  \x1B[36mhttp://localhost:$apiPort\x1B[0m');
    }
    print('');
    print('\x1B[90mPress Ctrl+C to stop\x1B[0m');
    print('');

    // Keep running until interrupted
    await ProcessSignal.sigint.watch().first;

    print('');
    print('\x1B[90mShutting down...\x1B[0m');

    await watcher.stop();
    apiProcess?.kill();
    jasprProcess.kill();

    return 0;
  }
}
