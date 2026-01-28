import 'dart:io';
import 'package:path/path.dart' as p;
import 'builder.dart';

/// Generates static site from Duxt project
class StaticGenerator {
  static Future<void> generate(String projectDir, String outputDir) async {
    // First, build the project
    await DuxtBuilder.build(projectDir, outputDir);

    // Copy public directory contents
    final publicDir = Directory(p.join(projectDir, 'public'));
    final targetDir = Directory(p.join(projectDir, outputDir));

    if (publicDir.existsSync()) {
      await _copyDirectory(publicDir, targetDir);
    }

    print('  Static site generated');
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

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
