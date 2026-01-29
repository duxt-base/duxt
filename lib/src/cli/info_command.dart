import 'dart:io';
import 'package:args/command_runner.dart';

/// Show project information
class InfoCommand extends Command<int> {
  @override
  final name = 'info';
  @override
  final description = 'Show project information';

  @override
  Future<int> run() async {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      print('\x1B[31mError: Not in a Duxt project directory\x1B[0m');
      print('Run this command from your project root.');
      return 1;
    }

    final content = await pubspec.readAsString();
    final lines = content.split('\n');

    String? projectName;
    String? version;
    String? description;

    for (final line in lines) {
      if (line.startsWith('name:')) {
        projectName = line.split(':').last.trim();
      } else if (line.startsWith('version:')) {
        version = line.split(':').last.trim();
      } else if (line.startsWith('description:')) {
        description = line.split(':').last.trim();
      }
    }

    print('');
    print('\x1B[36m╭─────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1m${projectName ?? "Duxt Project"}\x1B[0m${" " * (32 - (projectName?.length ?? 12))}\x1B[36m│\x1B[0m');
    print('\x1B[36m╰─────────────────────────────────────╯\x1B[0m');
    print('');

    if (version != null) {
      print('  Version:     $version');
    }
    if (description != null && description.isNotEmpty) {
      print('  Description: $description');
    }

    // Count modules
    final libDir = Directory('lib');
    if (libDir.existsSync()) {
      final modules = libDir.listSync().whereType<Directory>().where((d) {
        final name = d.path.split('/').last;
        return name != 'shared' && !name.startsWith('.');
      }).toList();

      print('');
      print('  \x1B[90mModules:\x1B[0m');
      if (modules.isEmpty) {
        print('    No modules found');
      } else {
        for (final module in modules) {
          final name = module.path.split('/').last;
          final pagesDir = Directory('${module.path}/pages');
          final pageCount = pagesDir.existsSync()
              ? pagesDir.listSync().where((f) => f.path.endsWith('.dart')).length
              : 0;
          print('    • $name ($pageCount pages)');
        }
      }
    }

    // Check for server
    final serverDir = Directory('server');
    if (serverDir.existsSync()) {
      print('');
      print('  \x1B[90mServer:\x1B[0m');
      final apiDir = Directory('server/api');
      if (apiDir.existsSync()) {
        final apis = apiDir.listSync().where((f) => f.path.endsWith('.dart')).length;
        print('    • $apis API endpoints');
      }
      final dbFile = File('server/db.dart');
      if (dbFile.existsSync()) {
        print('    • Database configured');
      }
    }

    // Dependencies
    print('');
    print('  \x1B[90mDependencies:\x1B[0m');

    final hasDuxtUi = content.contains('duxt_ui:');
    final hasJasprRouter = content.contains('jaspr_router:');
    final hasJasprContent = content.contains('jaspr_content:');

    if (hasDuxtUi) print('    • duxt_ui');
    if (hasJasprRouter) print('    • jaspr_router');
    if (hasJasprContent) print('    • jaspr_content');

    print('');
    return 0;
  }
}
