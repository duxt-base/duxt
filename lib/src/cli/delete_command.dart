import 'dart:io';
import 'package:args/command_runner.dart';

/// Delete module, page, component, etc.
class DeleteCommand extends Command<int> {
  @override
  final name = 'd';
  @override
  final description = 'Delete module, page, component, or model';

  DeleteCommand() {
    argParser.addFlag('force', abbr: 'f', help: 'Skip confirmation prompt');
  }

  @override
  String get invocation => 'duxt d <type> <name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      print('\x1B[31mError: Missing type argument\x1B[0m');
      print('Usage: duxt d <type> <name>');
      print('');
      print('Types: module, page, component, model, api');
      print('');
      print('Examples:');
      print('  duxt d module posts     # Delete posts module');
      print('  duxt d page posts/new   # Delete posts/new page');
      print('  duxt d component header # Delete header component');
      return 1;
    }

    final type = argResults!.rest[0];
    final name = argResults!.rest.length > 1 ? argResults!.rest[1] : null;
    final force = argResults!['force'] as bool;

    if (name == null) {
      print('\x1B[31mError: Missing name argument\x1B[0m');
      print('Usage: duxt d $type <name>');
      return 1;
    }

    switch (type) {
      case 'module':
        await _deleteModule(name, force);
        break;
      case 'page':
        await _deletePage(name, force);
        break;
      case 'component':
        await _deleteComponent(name, force);
        break;
      case 'model':
        await _deleteModel(name, force);
        break;
      case 'api':
        await _deleteApi(name, force);
        break;
      default:
        print('\x1B[31mError: Unknown type "$type"\x1B[0m');
        print('Valid types: module, page, component, model, api');
        return 1;
    }
    return 0;
  }

  Future<void> _deleteModule(String name, bool force) async {
    final dir = Directory('lib/$name');

    if (!dir.existsSync()) {
      print('\x1B[31mError: Module "$name" not found\x1B[0m');
      return;
    }

    if (!force) {
      print('This will delete the entire module: lib/$name/');
      stdout.write('Are you sure? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response != 'y' && response != 'yes') {
        print('Aborted.');
        return;
      }
    }

    await dir.delete(recursive: true);
    print('\x1B[32m✓\x1B[0m Deleted module: $name/');
    print('');
    print('Remember to remove the route from lib/app.dart');
  }

  Future<void> _deletePage(String name, bool force) async {
    // name could be "module/page" or just "page" in shared
    final parts = name.split('/');
    String filePath;

    if (parts.length > 1) {
      // Module-specific page
      filePath = 'lib/${parts[0]}/pages/${parts.sublist(1).join('/')}.dart';
    } else {
      // Shared page
      filePath = 'lib/shared/pages/$name.dart';
    }

    final file = File(filePath);

    if (!file.existsSync()) {
      // Try with index.dart
      final indexPath = filePath.replaceAll('.dart', '/index.dart');
      final indexFile = File(indexPath);
      if (indexFile.existsSync()) {
        final dir = indexFile.parent;
        if (!force) {
          stdout.write('Delete $indexPath? (y/N): ');
          final response = stdin.readLineSync()?.toLowerCase();
          if (response != 'y' && response != 'yes') {
            print('Aborted.');
            return;
          }
        }
        await dir.delete(recursive: true);
        print('\x1B[32m✓\x1B[0m Deleted page: $indexPath');
        return;
      }
      print('\x1B[31mError: Page "$name" not found\x1B[0m');
      print('Tried: $filePath');
      return;
    }

    if (!force) {
      stdout.write('Delete $filePath? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response != 'y' && response != 'yes') {
        print('Aborted.');
        return;
      }
    }

    await file.delete();
    print('\x1B[32m✓\x1B[0m Deleted page: $filePath');
    print('');
    print('Remember to remove the route from lib/app.dart');
  }

  Future<void> _deleteComponent(String name, bool force) async {
    final parts = name.split('/');
    String filePath;

    if (parts.length > 1) {
      // Module-specific component
      filePath = 'lib/${parts[0]}/components/${parts.sublist(1).join('/')}.dart';
    } else {
      // Shared component
      filePath = 'lib/shared/components/$name.dart';
    }

    final file = File(filePath);

    if (!file.existsSync()) {
      print('\x1B[31mError: Component "$name" not found\x1B[0m');
      print('Tried: $filePath');
      return;
    }

    if (!force) {
      stdout.write('Delete $filePath? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response != 'y' && response != 'yes') {
        print('Aborted.');
        return;
      }
    }

    await file.delete();
    print('\x1B[32m✓\x1B[0m Deleted component: $filePath');
  }

  Future<void> _deleteModel(String name, bool force) async {
    final filePath = 'lib/$name/model.dart';
    final file = File(filePath);

    if (!file.existsSync()) {
      print('\x1B[31mError: Model "$name/model.dart" not found\x1B[0m');
      return;
    }

    if (!force) {
      stdout.write('Delete $filePath? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response != 'y' && response != 'yes') {
        print('Aborted.');
        return;
      }
    }

    await file.delete();
    print('\x1B[32m✓\x1B[0m Deleted model: $filePath');
  }

  Future<void> _deleteApi(String name, bool force) async {
    final filePath = 'lib/$name/api.dart';
    final file = File(filePath);

    if (!file.existsSync()) {
      print('\x1B[31mError: API "$name/api.dart" not found\x1B[0m');
      return;
    }

    if (!force) {
      stdout.write('Delete $filePath? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response != 'y' && response != 'yes') {
        print('Aborted.');
        return;
      }
    }

    await file.delete();
    print('\x1B[32m✓\x1B[0m Deleted api: $filePath');
  }
}
