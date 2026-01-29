import 'dart:io';
import 'package:args/command_runner.dart';

/// Clean build artifacts
class CleanCommand extends Command<int> {
  @override
  final name = 'clean';
  @override
  final description = 'Clean build artifacts and caches';

  CleanCommand() {
    argParser.addFlag('all', abbr: 'a', help: 'Also remove .dart_tool and pubspec.lock');
  }

  @override
  Future<int> run() async {
    final all = argResults!['all'] as bool;

    print('\x1B[90m→\x1B[0m Cleaning build artifacts...');

    // Standard directories to clean
    final dirs = [
      'build',
      '.jaspr',
      'web/.jaspr',
    ];

    // Additional directories if --all
    if (all) {
      dirs.addAll([
        '.dart_tool',
      ]);
    }

    var cleaned = 0;

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        print('  Deleted: $dirPath/');
        cleaned++;
      }
    }

    // Clean pubspec.lock if --all
    if (all) {
      final lockFile = File('pubspec.lock');
      if (lockFile.existsSync()) {
        await lockFile.delete();
        print('  Deleted: pubspec.lock');
        cleaned++;
      }
    }

    // Clean database file if exists
    final dbFile = File('blog.db');
    if (dbFile.existsSync()) {
      stdout.write('  Delete blog.db? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response == 'y' || response == 'yes') {
        await dbFile.delete();
        print('  Deleted: blog.db');
        cleaned++;
      }
    }

    if (cleaned == 0) {
      print('  Nothing to clean.');
    } else {
      print('');
      print('\x1B[32m✓\x1B[0m Cleaned $cleaned item(s)');
    }

    if (all) {
      print('');
      print('\x1B[90mRun "dart pub get" to restore dependencies.\x1B[0m');
    }

    return 0;
  }
}
