import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:duxt/src/core/layout_system.dart';

void main() {
  group('LayoutSystem', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duxt_layout_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('scanLayouts handles missing layouts directory without crashing', () async {
      // No layouts/ directory — should not crash, returns early
      await LayoutSystem.scanLayouts(tempDir.path);
      // No assertion on layouts content since it's static state;
      // just verifying it doesn't throw
    });

    test('scanLayouts discovers layout files', () async {
      final layoutsDir = Directory(p.join(tempDir.path, 'layouts'));
      layoutsDir.createSync();

      File(p.join(layoutsDir.path, 'default.dart')).writeAsStringSync('''
class DefaultLayout {}
''');
      File(p.join(layoutsDir.path, 'admin.dart')).writeAsStringSync('''
class AdminLayout {}
''');

      await LayoutSystem.scanLayouts(tempDir.path);

      expect(LayoutSystem.layouts, hasLength(2));
      expect(LayoutSystem.hasLayout('default'), isTrue);
      expect(LayoutSystem.hasLayout('admin'), isTrue);
    });

    test('scanLayouts ignores non-dart files', () async {
      final layoutsDir = Directory(p.join(tempDir.path, 'layouts'));
      layoutsDir.createSync();

      File(p.join(layoutsDir.path, 'default.dart')).writeAsStringSync('');
      File(p.join(layoutsDir.path, 'notes.txt')).writeAsStringSync('');
      File(p.join(layoutsDir.path, 'readme.md')).writeAsStringSync('');

      await LayoutSystem.scanLayouts(tempDir.path);

      expect(LayoutSystem.layouts, hasLength(1));
      expect(LayoutSystem.hasLayout('default'), isTrue);
    });

    test('scanLayouts clears previous layouts on rescan', () async {
      final layoutsDir = Directory(p.join(tempDir.path, 'layouts'));
      layoutsDir.createSync();

      File(p.join(layoutsDir.path, 'default.dart')).writeAsStringSync('');
      File(p.join(layoutsDir.path, 'admin.dart')).writeAsStringSync('');

      await LayoutSystem.scanLayouts(tempDir.path);
      expect(LayoutSystem.layouts, hasLength(2));

      // Remove admin layout and rescan
      File(p.join(layoutsDir.path, 'admin.dart')).deleteSync();
      await LayoutSystem.scanLayouts(tempDir.path);
      expect(LayoutSystem.layouts, hasLength(1));
      expect(LayoutSystem.hasLayout('admin'), isFalse);
    });

    test('hasLayout returns false for non-existent layout', () async {
      final layoutsDir = Directory(p.join(tempDir.path, 'layouts'));
      layoutsDir.createSync();
      File(p.join(layoutsDir.path, 'default.dart')).writeAsStringSync('');
      await LayoutSystem.scanLayouts(tempDir.path);

      expect(LayoutSystem.hasLayout('nonexistent'), isFalse);
    });

    test('layouts returns unmodifiable map', () async {
      final layoutsDir = Directory(p.join(tempDir.path, 'layouts'));
      layoutsDir.createSync();
      File(p.join(layoutsDir.path, 'default.dart')).writeAsStringSync('');

      await LayoutSystem.scanLayouts(tempDir.path);

      expect(() => LayoutSystem.layouts['new'] = 'value', throwsUnsupportedError);
    });

    test('generateLayoutsCode produces valid switch-case code', () async {
      final layoutsDir = Directory(p.join(tempDir.path, 'layouts'));
      layoutsDir.createSync();

      File(p.join(layoutsDir.path, 'default.dart')).writeAsStringSync('''
class DefaultLayout {}
''');
      File(p.join(layoutsDir.path, 'admin.dart')).writeAsStringSync('''
class AdminLayout {}
''');

      await LayoutSystem.scanLayouts(tempDir.path);

      final code = LayoutSystem.generateLayoutsCode(tempDir.path);
      expect(code, contains('GENERATED CODE'));
      expect(code, contains('wrapWithLayout'));
      expect(code, contains("case 'default':"));
      expect(code, contains("case 'admin':"));
      expect(code, contains('DefaultLayout'));
      expect(code, contains('AdminLayout'));
      expect(code, contains('default:'));
      expect(code, contains('return child'));
    });
  });
}
