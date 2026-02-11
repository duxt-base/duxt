import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../core/router_generator.dart';
import '../core/builder.dart';
import 'tauri_scaffold.dart';

/// Command to build a native desktop app using Tauri v2
/// Usage: duxt build desktop [--debug]
class BuildDesktopCommand extends Command<int> {
  @override
  final name = 'desktop';

  @override
  final description = 'Build as native desktop app using Tauri';

  BuildDesktopCommand() {
    argParser.addFlag(
      'debug',
      help: 'Build in debug mode instead of release',
      defaultsTo: false,
    );
  }

  /// Static entry point callable from BuildCommand without argResults.
  static Future<int> buildDesktop({bool debug = false}) async {
    final cmd = BuildDesktopCommand();
    return cmd._runDesktopBuild(debug: debug);
  }

  @override
  Future<int> run() async {
    final debug = argResults!['debug'] as bool;
    return _runDesktopBuild(debug: debug);
  }

  Future<int> _runDesktopBuild({bool debug = false}) async {
    final projectDir = Directory.current.path;

    print('');
    print('\x1B[36m╭─────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1mDuxt\x1B[0m Desktop Build (Tauri)       \x1B[36m│\x1B[0m');
    print('\x1B[36m╰─────────────────────────────────────╯\x1B[0m');
    print('');

    try {
      // 1. Check prerequisites
      print('\x1B[90m→\x1B[0m Checking prerequisites...');
      await _checkPrerequisites();

      // 2. Read project name from pubspec.yaml
      final projectName = await _getProjectName(projectDir);
      print('  Project: $projectName');

      // 3. Run normal Duxt build (frontend only)
      print('');
      print('\x1B[90m→\x1B[0m Building frontend...');
      await _buildFrontend(projectDir);

      // 4. Scaffold src-tauri/ if not present
      final tauriDir = Directory(p.join(projectDir, 'src-tauri'));
      if (!tauriDir.existsSync()) {
        print('');
        print('\x1B[90m→\x1B[0m Scaffolding Tauri project (first run)...');
        await TauriScaffold.scaffold(projectDir, projectName);
      } else {
        print('');
        print('\x1B[90m→\x1B[0m Tauri project found at src-tauri/');
      }

      // 5. Run cargo tauri build
      print('');
      print('\x1B[90m→\x1B[0m Building desktop app${debug ? ' (debug)' : ''}...');
      print('  This may take a few minutes on first build.');
      print('');
      await _tauriBuild(projectDir, debug: debug);

      // 6. Report output
      final bundleDir = p.join(projectDir, 'src-tauri', 'target',
          debug ? 'debug' : 'release', 'bundle');
      print('');
      print('\x1B[32m✓\x1B[0m Desktop build complete!');
      print('');
      print('  Output: \x1B[1m$bundleDir/\x1B[0m');
      _printBundleContents(bundleDir);
      print('');

      return 0;
    } catch (e) {
      print('');
      print('\x1B[31m✗\x1B[0m Desktop build failed: $e');
      return 1;
    }
  }

  /// Check that cargo and cargo-tauri are installed
  Future<void> _checkPrerequisites() async {
    // Check cargo
    final cargoResult = await Process.run('cargo', ['--version']);
    if (cargoResult.exitCode != 0) {
      throw Exception(
        'Rust/Cargo not found. Install from https://rustup.rs/');
    }
    print('  cargo: ${cargoResult.stdout.toString().trim()}');

    // Check cargo-tauri
    final tauriResult = await Process.run('cargo', ['tauri', '--version']);
    if (tauriResult.exitCode != 0) {
      print('  \x1B[33m!\x1B[0m cargo-tauri not found. Installing...');
      final installResult = await Process.run(
        'cargo',
        ['install', 'tauri-cli'],
      );
      if (installResult.exitCode != 0) {
        throw Exception(
          'Failed to install tauri-cli: ${installResult.stderr}');
      }
      print('  \x1B[32m✓\x1B[0m cargo-tauri installed');
    } else {
      print('  tauri-cli: ${tauriResult.stdout.toString().trim()}');
    }
  }

  /// Read project name from pubspec.yaml
  Future<String> _getProjectName(String projectDir) async {
    final pubspec = File(p.join(projectDir, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found in $projectDir');
    }

    final content = await pubspec.readAsString();
    final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
    if (nameMatch == null) {
      throw Exception('Could not find "name:" in pubspec.yaml');
    }
    return nameMatch.group(1)!.trim();
  }

  /// Run the Duxt frontend build pipeline
  Future<void> _buildFrontend(String projectDir) async {
    // Sync packages for Tailwind
    print('  Syncing packages...');
    await _syncPackages(projectDir);

    // Compile Tailwind CSS
    print('  Compiling Tailwind CSS...');
    await _compileTailwind(projectDir);

    // Generate routes
    print('  Generating routes...');
    await RouterGenerator.generate(projectDir);

    // Build via DuxtBuilder
    print('  Running jaspr build...');
    await DuxtBuilder.build(projectDir, '.output');
  }

  /// Run cargo tauri build
  Future<void> _tauriBuild(String projectDir, {bool debug = false}) async {
    final args = ['tauri', 'build'];
    if (debug) args.add('--debug');

    final process = await Process.start(
      'cargo',
      args,
      workingDirectory: projectDir,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('cargo tauri build exited with code $exitCode');
    }
  }

  /// Print the contents of the bundle directory
  void _printBundleContents(String bundleDir) {
    final dir = Directory(bundleDir);
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        final files = entity.listSync().whereType<File>().toList();
        for (final f in files) {
          final size = _formatSize(f.lengthSync());
          print('    ${p.join(name, p.basename(f.path))}  ($size)');
        }
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---------------------------------------------------------------------------
  // Build helpers (shared with BuildCommand)
  // ---------------------------------------------------------------------------

  Future<void> _compileTailwind(String projectDir) async {
    final inputFile = File(p.join(projectDir, 'web', 'styles.tw.css'));
    if (!inputFile.existsSync()) {
      print('    No styles.tw.css found, skipping');
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

    if (result.exitCode != 0) {
      print('    \x1B[31mTailwind error:\x1B[0m ${result.stderr}');
    }
  }

  Future<void> _syncPackages(String projectDir) async {
    final packagesToSync = ['duxt_ui', 'duxt'];
    final targetDir = Directory(p.join(projectDir, '.duxt', 'packages'));

    final packageConfigFile =
        File(p.join(projectDir, '.dart_tool', 'package_config.json'));
    if (!packageConfigFile.existsSync()) {
      print('    \x1B[33m!\x1B[0m Run "dart pub get" first');
      return;
    }

    final packageConfig =
        jsonDecode(await packageConfigFile.readAsString());
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
