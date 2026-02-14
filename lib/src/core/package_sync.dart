import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Syncs dependency packages to .duxt/packages/ for Tailwind CSS scanning
class PackageSync {
  static const _packagesToSync = ['duxt_ui', 'duxt'];

  /// Sync packages from pub cache to .duxt/packages/
  static Future<void> sync(String projectDir) async {
    final targetDir = Directory(p.join(projectDir, '.duxt', 'packages'));
    final packageConfigFile = File(p.join(projectDir, '.dart_tool', 'package_config.json'));
    if (!packageConfigFile.existsSync()) return;

    final packageConfig = jsonDecode(await packageConfigFile.readAsString());
    final packages = packageConfig['packages'] as List<dynamic>;

    for (final pkgName in _packagesToSync) {
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

  static Future<void> _copyDirectory(Directory source, Directory target) async {
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
