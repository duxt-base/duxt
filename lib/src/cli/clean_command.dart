import 'dart:io';
import 'package:args/command_runner.dart';

/// Clean build artifacts
class CleanCommand extends Command<int> {
  @override
  final name = 'clean';
  @override
  final description = 'Clean build artifacts and caches';

  CleanCommand() {
    argParser.addFlag('all', abbr: 'a', help: 'Also remove .dart_tool, pubspec.lock, and database files');
  }

  @override
  Future<int> run() async {
    final all = argResults!['all'] as bool;
    final projectDir = Directory.current.path;

    print('\x1B[90m→\x1B[0m Cleaning build artifacts...');

    // Run jaspr clean first
    print('  Running jaspr clean...');
    final home = Platform.environment['HOME'] ?? '';
    final jasprPath = '$home/.pub-cache/bin/jaspr';

    final jasprClean = await Process.run(
      File(jasprPath).existsSync() ? jasprPath : 'jaspr',
      ['clean'],
      workingDirectory: projectDir,
    );

    if (jasprClean.exitCode == 0) {
      print('  \x1B[32m✓\x1B[0m jaspr clean completed');
    }

    // Standard directories to clean (additional to jaspr clean)
    final dirs = [
      '.jaspr',
      'web/.jaspr',
      '.output',
      '.duxt',
    ];

    // Additional directories if --all
    if (all) {
      dirs.addAll([
        '.dart_tool',
      ]);
    }

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        print('  Deleted: $dirPath/');
      }
    }

    // Clean pubspec.lock if --all
    if (all) {
      final lockFile = File('pubspec.lock');
      if (lockFile.existsSync()) {
        await lockFile.delete();
        print('  Deleted: pubspec.lock');
      }
    }

    // Clean database files only with --all flag
    if (all) {
      final dbFile = File('blog.db');
      if (dbFile.existsSync()) {
        await dbFile.delete();
        print('  Deleted: blog.db');
      }
    }

    print('');
    print('\x1B[32m✓\x1B[0m Clean complete!');

    if (all) {
      print('');
      print('\x1B[90mRun "dart pub get" to restore dependencies.\x1B[0m');
    }

    return 0;
  }
}
