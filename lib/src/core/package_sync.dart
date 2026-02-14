import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class PackageSyncResult {
  final bool packageConfigFound;
  final List<String> syncedPackages;

  const PackageSyncResult({
    required this.packageConfigFound,
    required this.syncedPackages,
  });
}

/// Sync dependency package sources into `.duxt/packages` for Tailwind scanning.
class PackageSync {
  static const _defaultPackages = ['duxt_ui', 'duxt'];

  static Future<PackageSyncResult> sync(
    String projectDir, {
    List<String> packagesToSync = _defaultPackages,
  }) async {
    final targetDir = Directory(p.join(projectDir, '.duxt', 'packages'));
    final packageConfigFile = File(
      p.join(projectDir, '.dart_tool', 'package_config.json'),
    );
    if (!packageConfigFile.existsSync()) {
      return const PackageSyncResult(
          packageConfigFound: false, syncedPackages: []);
    }

    final packageConfig = jsonDecode(await packageConfigFile.readAsString());
    final packages = packageConfig['packages'] as List<dynamic>;
    final syncedPackages = <String>[];

    for (final pkgName in packagesToSync) {
      final pkg = packages.firstWhere(
        (p) => p['name'] == pkgName,
        orElse: () => null,
      );
      if (pkg == null) continue;

      final sourcePath =
          _resolvePackageRoot(projectDir, pkg['rootUri'] as String?);
      if (sourcePath == null) continue;

      final sourceLib = Directory(p.join(sourcePath, 'lib'));
      if (!sourceLib.existsSync()) continue;

      final targetPkg = Directory(p.join(targetDir.path, pkgName));
      if (targetPkg.existsSync()) {
        await targetPkg.delete(recursive: true);
      }
      await targetPkg.create(recursive: true);
      await _copyDirectory(sourceLib, targetPkg);
      syncedPackages.add(pkgName);
    }

    return PackageSyncResult(
      packageConfigFound: true,
      syncedPackages: syncedPackages,
    );
  }

  static String? _resolvePackageRoot(String projectDir, String? rootUri) {
    if (rootUri == null) return null;
    if (rootUri.startsWith('file://')) {
      return Uri.parse(rootUri).toFilePath();
    }
    if (rootUri.startsWith('../')) {
      return p.normalize(p.join(projectDir, '.dart_tool', rootUri));
    }
    return null;
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
