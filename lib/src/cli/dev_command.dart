import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
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
        final output = utf8.decode(data).trim();
        if (output.isNotEmpty) print('\x1B[35m[API]\x1B[0m $output');
      });
      apiProcess.stderr.listen((data) {
        final output = utf8.decode(data).trim();
        if (output.isNotEmpty) print('\x1B[31m[API]\x1B[0m $output');
      });
    }

    // Start Tailwind in watch mode
    if (tailwindOk) {
      print('\x1B[90m→\x1B[0m Starting Tailwind watcher...');
      tailwindProcess = await _startTailwindWatch(projectDir);
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

    var hasShownReady = false;

    jasprProcess.stdout.listen((data) {
      final output = utf8.decode(data).trim();
      if (output.isNotEmpty) {
        print('\x1B[34m[JASPR]\x1B[0m $output');

        // Show ready message only after jaspr reports it's serving
        if (!hasShownReady && output.contains('Serving at')) {
          hasShownReady = true;
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
        }
      }
    });
    jasprProcess.stderr.listen((data) {
      final output = utf8.decode(data).trim();
      if (output.isNotEmpty) print('\x1B[31m[JASPR]\x1B[0m $output');
    });

    // Keep running until interrupted
    await ProcessSignal.sigint.watch().first;

    print('');
    print('\x1B[90mShutting down...\x1B[0m');

    await watcher.stop();
    tailwindProcess?.kill();
    apiProcess?.kill();
    jasprProcess.kill();

    return 0;
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
  Future<Process?> _startTailwindWatch(String projectDir) async {
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
        print('\x1B[35m[TW]\x1B[0m $output');
      }
    });
    process.stderr.listen((data) {
      final output = utf8.decode(data).trim();
      if (output.isNotEmpty) print('\x1B[31m[TW]\x1B[0m $output');
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
}
