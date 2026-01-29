import 'dart:io';
import 'package:args/command_runner.dart';
import '../core/router_generator.dart';
import '../core/builder.dart';

/// Command to build for production
/// Usage: duxt build [--target=linux-x64]
class BuildCommand extends Command<int> {
  @override
  final name = 'build';

  @override
  final description = 'Build the project for production';

  BuildCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      defaultsTo: '.output',
      help: 'Output directory',
    );
    argParser.addOption(
      'target',
      abbr: 't',
      help: 'Target platform (linux-x64, linux-arm64, macos-x64, macos-arm64, windows-x64)',
    );
    argParser.addFlag(
      'all-targets',
      help: 'Build for all supported targets (requires Docker for cross-compilation)',
      defaultsTo: false,
    );
  }

  String get _currentTarget {
    final os = Platform.operatingSystem;
    final arch = Platform.version.contains('arm64') ? 'arm64' : 'x64';
    return '$os-$arch';
  }

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;
    final outputDir = argResults!['output'] as String;
    final target = argResults!['target'] as String? ?? _currentTarget;
    final allTargets = argResults!['all-targets'] as bool;

    print('');
    print('\x1B[36m╭─────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1mDuxt\x1B[0m Production Build            \x1B[36m│\x1B[0m');
    print('\x1B[36m╰─────────────────────────────────────╯\x1B[0m');
    print('');

    try {
      // Generate routes
      print('\x1B[90m→\x1B[0m Generating routes...');
      await RouterGenerator.generate(projectDir);

      if (allTargets) {
        // Build for multiple targets
        final targets = ['linux-x64', 'linux-arm64', 'macos-x64', 'macos-arm64'];
        for (final t in targets) {
          print('');
          print('\x1B[90m→\x1B[0m Building for $t...');
          await DuxtBuilder.build(projectDir, outputDir, target: t);
        }
      } else {
        // Build for single target
        print('\x1B[90m→\x1B[0m Building for $target...');
        await DuxtBuilder.build(projectDir, outputDir, target: target);
      }

      // Check what was built
      final hasServer = File('$projectDir/server/main.dart').existsSync();

      print('');
      print('\x1B[32m✓\x1B[0m Build complete!');
      print('');
      print('  Output: \x1B[1m$outputDir/\x1B[0m');
      print('    ├── public/              Static frontend');
      if (hasServer) {
        if (allTargets) {
          print('    ├── server-linux-x64     Linux x64 binary');
          print('    ├── server-linux-arm64   Linux ARM64 binary');
          print('    ├── server-macos-x64     macOS x64 binary');
          print('    └── server-macos-arm64   macOS ARM64 binary');
        } else {
          print('    └── server-$target    Server binary');
        }
      }
      print('');

      if (hasServer) {
        print('  \x1B[36mTo run:\x1B[0m');
        if (allTargets) {
          print('    ./$outputDir/server-<platform>');
        } else {
          print('    ./$outputDir/server-$target');
        }
        print('');
      }

      return 0;
    } catch (e) {
      print('');
      print('\x1B[31m✗\x1B[0m Build failed: $e');
      return 1;
    }
  }
}
