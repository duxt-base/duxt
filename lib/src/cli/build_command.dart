import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../core/router_generator.dart';
import '../core/builder.dart';
import 'build_desktop_command.dart';

/// Command to build for production
/// Usage: duxt build [desktop] [--target=linux-x64]
///
/// Default (no args): builds for web
/// duxt build desktop: builds native desktop app via Tauri
class BuildCommand extends Command<int> {
  @override
  final name = 'build';

  @override
  final description = 'Build for production (web by default, or "desktop" for Tauri)';

  @override
  String get invocation => 'duxt build [desktop] [options]';

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
    argParser.addFlag(
      'debug',
      help: 'Build in debug mode (desktop only)',
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
    // Check for platform target: duxt build desktop
    final rest = argResults!.rest;
    if (rest.isNotEmpty) {
      switch (rest[0]) {
        case 'desktop':
          final debug = argResults!['debug'] as bool;
          return BuildDesktopCommand.buildDesktop(debug: debug);
        default:
          print('Unknown build target: ${rest[0]}');
          print('Available: desktop');
          print('');
          print('Run "duxt build" for web (default)');
          return 1;
      }
    }

    // Default: web build
    return _buildWeb();
  }

  Future<int> _buildWeb() async {
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
      // Sync packages for Tailwind
      print('\x1B[90m→\x1B[0m Syncing packages...');
      await _syncPackages(projectDir);

      // Compile Tailwind CSS
      print('\x1B[90m→\x1B[0m Compiling Tailwind CSS...');
      await _compileTailwind(projectDir);

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

  /// Compile Tailwind CSS
  Future<void> _compileTailwind(String projectDir) async {
    final inputFile = File(p.join(projectDir, 'web', 'styles.tw.css'));
    if (!inputFile.existsSync()) {
      print('  \x1B[33m!\x1B[0m No styles.tw.css found, skipping');
      return;
    }

    final result = await Process.run(
      'tailwindcss',
      [
        '--input', p.join(projectDir, 'web', 'styles.tw.css'),
        '--output', p.join(projectDir, 'web', 'styles.css'),
        '--minify',
      ],
      workingDirectory: projectDir,
    );

    if (result.exitCode == 0) {
      print('  Compiled styles.css');
    } else {
      print('  \x1B[31mTailwind error:\x1B[0m ${result.stderr}');
    }
  }

  /// Sync duxt_ui package to .duxt/packages/
  Future<void> _syncPackages(String projectDir) async {
    final packagesToSync = ['duxt_ui', 'duxt'];
    final targetDir = Directory(p.join(projectDir, '.duxt', 'packages'));

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
      String sourcePath;

      if (rootUri.startsWith('file://')) {
        sourcePath = Uri.parse(rootUri).toFilePath();
      } else if (rootUri.startsWith('../')) {
        sourcePath = p.normalize(p.join(projectDir, '.dart_tool', rootUri));
      } else {
        continue;
      }

      final sourceLib = Directory(p.join(sourcePath, 'lib'));
      if (!sourceLib.existsSync()) continue;

      final targetPkg = Directory(p.join(targetDir.path, pkgName));

      if (targetPkg.existsSync()) {
        await targetPkg.delete(recursive: true);
      }
      await targetPkg.create(recursive: true);

      await _copyDirectory(sourceLib, targetPkg);
      print('  Synced $pkgName');
    }
  }

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
