import 'dart:io';
import 'package:path/path.dart' as p;

/// Builds Duxt project for production
class DuxtBuilder {
  static Future<void> build(String projectDir, String outputDir) async {
    // Run dart pub get if needed
    final pubspecLock = File(p.join(projectDir, 'pubspec.lock'));
    if (!pubspecLock.existsSync()) {
      print('  Running dart pub get...');
      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir);
      if (pubGet.exitCode != 0) {
        throw Exception('Failed to run pub get: ${pubGet.stderr}');
      }
    }

    // Check for jaspr CLI
    final jasprPath = _findJasprCli();

    // Run jaspr build
    print('  Running jaspr build...');
    final result = await Process.run(
      jasprPath,
      ['build'],
      workingDirectory: projectDir,
    );

    if (result.exitCode != 0) {
      throw Exception('Jaspr build failed: ${result.stderr}');
    }

    // Move output to specified directory
    final jasprOutput = Directory(p.join(projectDir, 'build', 'jaspr'));
    final targetOutput = Directory(p.join(projectDir, outputDir));

    if (targetOutput.existsSync()) {
      targetOutput.deleteSync(recursive: true);
    }

    await _copyDirectory(jasprOutput, targetOutput);

    print('  Build complete');
  }

  static String _findJasprCli() {
    // Try common locations
    final home = Platform.environment['HOME'] ?? '';
    final pubCachePath = p.join(home, '.pub-cache', 'bin', 'jaspr');

    if (File(pubCachePath).existsSync()) {
      return pubCachePath;
    }

    // Fall back to PATH
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
