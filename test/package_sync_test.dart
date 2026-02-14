import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:duxt/src/core/package_sync.dart';

void main() {
  group('PackageSync', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duxt_sync_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('skips when no package_config.json exists', () async {
      final result = await PackageSync.sync(tempDir.path);

      expect(result.packageConfigFound, isFalse);
      expect(result.syncedPackages, isEmpty);
      final targetDir = Directory(p.join(tempDir.path, '.duxt', 'packages'));
      expect(targetDir.existsSync(), isFalse);
    });

    test('syncs package with relative rootUri', () async {
      // Create a fake package source
      final pkgSource = Directory(p.join(tempDir.path, 'pkg_source', 'duxt_ui', 'lib'));
      pkgSource.createSync(recursive: true);
      File(p.join(pkgSource.path, 'button.dart')).writeAsStringSync('class Button {}');
      File(p.join(pkgSource.path, 'input.dart')).writeAsStringSync('class Input {}');

      // Create .dart_tool/package_config.json with relative path
      // PackageSync resolves relative URIs from .dart_tool/ directory
      final dartToolDir = Directory(p.join(tempDir.path, '.dart_tool'));
      dartToolDir.createSync();

      // Relative from .dart_tool/ to pkg_source/duxt_ui
      File(p.join(dartToolDir.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'duxt_ui', 'rootUri': '../pkg_source/duxt_ui', 'packageUri': 'lib/'},
          ],
        }),
      );

      final result = await PackageSync.sync(tempDir.path);

      expect(result.packageConfigFound, isTrue);
      expect(result.syncedPackages, contains('duxt_ui'));

      final targetDir = Directory(p.join(tempDir.path, '.duxt', 'packages', 'duxt_ui'));
      expect(targetDir.existsSync(), isTrue);

      final copiedButton = File(p.join(targetDir.path, 'button.dart'));
      expect(copiedButton.existsSync(), isTrue);
      expect(copiedButton.readAsStringSync(), 'class Button {}');

      final copiedInput = File(p.join(targetDir.path, 'input.dart'));
      expect(copiedInput.existsSync(), isTrue);
    });

    test('syncs package with file:// rootUri', () async {
      // Create a fake package source
      final pkgSource = Directory(p.join(tempDir.path, 'cache', 'duxt', 'lib'));
      pkgSource.createSync(recursive: true);
      File(p.join(pkgSource.path, 'duxt.dart')).writeAsStringSync('class Duxt {}');

      // Create .dart_tool/package_config.json with file:// URI
      final dartToolDir = Directory(p.join(tempDir.path, '.dart_tool'));
      dartToolDir.createSync();

      final fileUri = Uri.file(p.join(tempDir.path, 'cache', 'duxt')).toString();

      File(p.join(dartToolDir.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'duxt', 'rootUri': fileUri, 'packageUri': 'lib/'},
          ],
        }),
      );

      final result = await PackageSync.sync(tempDir.path);

      expect(result.packageConfigFound, isTrue);
      expect(result.syncedPackages, contains('duxt'));

      final targetDir = Directory(p.join(tempDir.path, '.duxt', 'packages', 'duxt'));
      expect(targetDir.existsSync(), isTrue);

      final copiedFile = File(p.join(targetDir.path, 'duxt.dart'));
      expect(copiedFile.existsSync(), isTrue);
      expect(copiedFile.readAsStringSync(), 'class Duxt {}');
    });

    test('skips packages not in sync list', () async {
      // Create a fake package source
      final pkgSource = Directory(p.join(tempDir.path, 'cache', 'random_pkg', 'lib'));
      pkgSource.createSync(recursive: true);
      File(p.join(pkgSource.path, 'random.dart')).writeAsStringSync('class Random {}');

      final dartToolDir = Directory(p.join(tempDir.path, '.dart_tool'));
      dartToolDir.createSync();

      File(p.join(dartToolDir.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'random_pkg', 'rootUri': '../../cache/random_pkg', 'packageUri': 'lib/'},
          ],
        }),
      );

      final result = await PackageSync.sync(tempDir.path);

      expect(result.packageConfigFound, isTrue);
      expect(result.syncedPackages, isEmpty);
      final targetDir = Directory(p.join(tempDir.path, '.duxt', 'packages', 'random_pkg'));
      expect(targetDir.existsSync(), isFalse);
    });

    test('replaces existing synced package on re-sync', () async {
      // Create initial package source
      final pkgSource = Directory(p.join(tempDir.path, 'cache', 'duxt_ui', 'lib'));
      pkgSource.createSync(recursive: true);
      File(p.join(pkgSource.path, 'old.dart')).writeAsStringSync('class Old {}');

      final dartToolDir = Directory(p.join(tempDir.path, '.dart_tool'));
      dartToolDir.createSync();

      final fileUri = Uri.file(p.join(tempDir.path, 'cache', 'duxt_ui')).toString();
      File(p.join(dartToolDir.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'duxt_ui', 'rootUri': fileUri, 'packageUri': 'lib/'},
          ],
        }),
      );

      // First sync
      await PackageSync.sync(tempDir.path);
      expect(File(p.join(tempDir.path, '.duxt', 'packages', 'duxt_ui', 'old.dart')).existsSync(), isTrue);

      // Update source: remove old.dart, add new.dart
      File(p.join(pkgSource.path, 'old.dart')).deleteSync();
      File(p.join(pkgSource.path, 'new.dart')).writeAsStringSync('class New {}');

      // Re-sync
      await PackageSync.sync(tempDir.path);
      expect(File(p.join(tempDir.path, '.duxt', 'packages', 'duxt_ui', 'old.dart')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, '.duxt', 'packages', 'duxt_ui', 'new.dart')).existsSync(), isTrue);
    });

    test('copies nested subdirectories', () async {
      // Create package with nested structure
      final pkgSource = Directory(p.join(tempDir.path, 'cache', 'duxt_ui', 'lib'));
      pkgSource.createSync(recursive: true);
      final subDir = Directory(p.join(pkgSource.path, 'src', 'widgets'));
      subDir.createSync(recursive: true);
      File(p.join(subDir.path, 'button.dart')).writeAsStringSync('class Button {}');
      File(p.join(pkgSource.path, 'duxt_ui.dart')).writeAsStringSync("export 'src/widgets/button.dart';");

      final dartToolDir = Directory(p.join(tempDir.path, '.dart_tool'));
      dartToolDir.createSync();

      final fileUri = Uri.file(p.join(tempDir.path, 'cache', 'duxt_ui')).toString();
      File(p.join(dartToolDir.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'duxt_ui', 'rootUri': fileUri, 'packageUri': 'lib/'},
          ],
        }),
      );

      await PackageSync.sync(tempDir.path);

      expect(
        File(p.join(tempDir.path, '.duxt', 'packages', 'duxt_ui', 'src', 'widgets', 'button.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, '.duxt', 'packages', 'duxt_ui', 'duxt_ui.dart')).existsSync(),
        isTrue,
      );
    });
  });
}
