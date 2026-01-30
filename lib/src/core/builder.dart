import 'dart:io';
import 'package:path/path.dart' as p;

/// Builds Duxt project for production
class DuxtBuilder {
  static Future<void> build(String projectDir, String outputDir, {String? target}) async {
    final targetOutput = Directory(p.join(projectDir, outputDir));

    // Create output directory if it doesn't exist
    if (!targetOutput.existsSync()) {
      targetOutput.createSync(recursive: true);
    }

    // Run dart pub get if needed
    final pubspecLock = File(p.join(projectDir, 'pubspec.lock'));
    if (!pubspecLock.existsSync()) {
      print('  Running dart pub get...');
      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir);
      if (pubGet.exitCode != 0) {
        throw Exception('Failed to run pub get: ${pubGet.stderr}');
      }
    }

    // Build frontend (only once, not per target)
    final publicDir = Directory(p.join(projectDir, outputDir, 'public'));
    if (!publicDir.existsSync()) {
      await _buildFrontend(projectDir, outputDir);
    }

    // Build server if exists
    final serverMain = File(p.join(projectDir, 'server', 'main.dart'));
    if (serverMain.existsSync()) {
      await _buildServer(projectDir, outputDir, target: target);
    }
  }

  static Future<void> _buildFrontend(String projectDir, String outputDir) async {
    final jasprPath = _findJasprCli();

    print('  Building frontend...');
    final result = await Process.run(
      jasprPath,
      ['build'],
      workingDirectory: projectDir,
    );

    if (result.exitCode != 0) {
      throw Exception('Jaspr build failed: ${result.stderr}');
    }

    // Move jaspr output to public/
    final jasprOutput = Directory(p.join(projectDir, 'build', 'jaspr'));
    final publicDir = Directory(p.join(projectDir, outputDir, 'public'));

    await _copyDirectory(jasprOutput, publicDir);
  }

  static Future<void> _buildServer(String projectDir, String outputDir, {String? target}) async {
    final currentTarget = _getCurrentTarget();
    final buildTarget = target ?? currentTarget;

    print('  Compiling server for $buildTarget...');

    final serverMain = p.join(projectDir, 'server', 'main.dart');
    final serverBinary = p.join(projectDir, outputDir, 'server-$buildTarget');

    // Check if cross-compiling
    if (buildTarget != currentTarget) {
      print('  \x1B[33m!\x1B[0m Cross-compilation: building for $buildTarget on $currentTarget');
      print('    Note: Cross-compilation requires Docker or building on target platform');

      // Try Docker-based cross-compilation
      final dockerResult = await _crossCompileWithDocker(
        projectDir,
        serverMain,
        serverBinary,
        buildTarget,
      );

      if (!dockerResult) {
        print('  \x1B[33m!\x1B[0m Skipping $buildTarget (Docker not available or failed)');
        return;
      }
    } else {
      // Try dart compile exe first (traditional method)
      var result = await Process.run(
        'dart',
        ['compile', 'exe', serverMain, '-o', serverBinary],
        workingDirectory: projectDir,
      );

      // If it fails due to build hooks (native assets), try dart build cli
      if (result.exitCode != 0 && result.stderr.toString().contains('build hooks')) {
        print('  Using dart build cli (native assets detected)...');

        // dart build cli creates a bundle directory structure
        // Output directly to .output/ so structure is: .output/bundle/bin/main and .output/bundle/lib/
        result = await Process.run(
          'dart',
          ['build', 'cli', '-t', serverMain, '-o', p.join(projectDir, outputDir)],
          workingDirectory: projectDir,
        );

        if (result.exitCode == 0) {
          // Rename the binary to include target suffix
          final binDir = Directory(p.join(projectDir, outputDir, 'bundle', 'bin'));
          if (binDir.existsSync()) {
            final files = binDir.listSync().whereType<File>().toList();
            if (files.isNotEmpty) {
              final newName = 'server-$buildTarget';
              await files.first.rename(p.join(binDir.path, newName));
            }
          }
        }
      }

      if (result.exitCode != 0) {
        throw Exception('Server compilation failed: ${result.stderr}');
      }
    }

    print('  Binary: $outputDir/server-$buildTarget');
  }

  static Future<bool> _crossCompileWithDocker(
    String projectDir,
    String serverMain,
    String serverBinary,
    String target,
  ) async {
    // Check if Docker is available
    final dockerCheck = await Process.run('docker', ['--version']);
    if (dockerCheck.exitCode != 0) {
      return false;
    }

    // Parse target
    final parts = target.split('-');
    if (parts.length != 2) return false;

    final os = parts[0];
    final arch = parts[1];

    if (os != 'linux') {
      print('    Docker cross-compilation only supports Linux targets');
      return false;
    }

    // Use official Dart image for Linux compilation
    final dockerArch = arch == 'arm64' ? 'linux/arm64' : 'linux/amd64';

    print('    Using Docker ($dockerArch)...');

    final result = await Process.run(
      'docker',
      [
        'run',
        '--rm',
        '--platform', dockerArch,
        '-v', '$projectDir:/app',
        '-w', '/app',
        'dart:stable',
        'dart', 'compile', 'exe', 'server/main.dart', '-o', serverBinary,
      ],
      workingDirectory: projectDir,
    );

    return result.exitCode == 0;
  }

  static String _getCurrentTarget() {
    final os = Platform.operatingSystem;
    // Check architecture from Dart version string or use platform info
    final arch = _getArchitecture();
    return '$os-$arch';
  }

  static String _getArchitecture() {
    // Platform.version contains architecture info
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) {
      return 'arm64';
    }
    return 'x64';
  }

  static String _findJasprCli() {
    final home = Platform.environment['HOME'] ?? '';
    final pubCachePath = p.join(home, '.pub-cache', 'bin', 'jaspr');

    if (File(pubCachePath).existsSync()) {
      return pubCachePath;
    }

    return 'jaspr';
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    destination.createSync(recursive: true);

    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));

      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
