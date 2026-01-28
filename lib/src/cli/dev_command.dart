import 'dart:io';
import 'package:args/command_runner.dart';
import '../server/dev_server.dart';
import '../core/router_generator.dart';
import '../core/watcher.dart';

/// Command to start development server
/// Usage: duxt dev [--port=3000]
class DevCommand extends Command<int> {
  @override
  final name = 'dev';

  @override
  final description = 'Start development server with hot reload';

  DevCommand() {
    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '3000',
      help: 'Port to run the dev server on',
    );
  }

  @override
  Future<int> run() async {
    final port = int.parse(argResults!['port'] as String);
    final projectDir = Directory.current.path;

    // Check if this is a Duxt project
    if (!File('$projectDir/duxt.config.dart').existsSync() &&
        !Directory('$projectDir/lib/pages').existsSync()) {
      print('Error: Not a Duxt project. Run this command in a Duxt project directory.');
      return 1;
    }

    print('\x1B[36mDuxt\x1B[0m v0.1.0');
    print('');

    // Generate routes
    print('Generating routes...');
    await RouterGenerator.generate(projectDir);

    // Start file watcher
    print('Starting file watcher...');
    final watcher = DuxtWatcher(projectDir, onFileChange: (path) async {
      print('\x1B[33m→\x1B[0m File changed: $path');
      await RouterGenerator.generate(projectDir);
    });
    await watcher.start();

    // Start dev server
    print('');
    print('\x1B[32m✓\x1B[0m Dev server running at \x1B[36mhttp://localhost:$port\x1B[0m');
    print('');

    final server = DevServer(projectDir, port);
    await server.start();

    // Keep running until interrupted
    await ProcessSignal.sigint.watch().first;

    print('\nShutting down...');
    await watcher.stop();
    await server.stop();

    return 0;
  }
}
