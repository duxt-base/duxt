import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/template_generator.dart';

/// Reserved package names that conflict with Dart/Flutter ecosystem packages
const _reservedNames = {
  'web', // conflicts with dart:web
  'test', // conflicts with test package
  'dart', // reserved
  'flutter', // reserved
  'async', // dart:async
  'core', // dart:core
  'io', // dart:io
  'html', // dart:html
  'js', // dart:js
  'meta', // meta package
  'path', // path package
  'http', // http package
  'json', // conflicts with dart:convert json
  'collection', // collection package
  'convert', // dart:convert
  'typed_data', // dart:typed_data
  'isolate', // dart:isolate
  'mirrors', // dart:mirrors
  'ffi', // dart:ffi
};

/// Command to create a new Duxt project
/// Usage: duxt create <project-name>
class CreateCommand extends Command<int> {
  @override
  final name = 'create';

  @override
  final description = 'Create a new Duxt project';

  @override
  String get invocation => 'duxt create <project-name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      print('Error: Please provide a project name');
      print('Usage: duxt create <project-name>');
      return 1;
    }

    final projectName = argResults!.rest.first;

    // Validate project name is not a reserved package name
    if (_reservedNames.contains(projectName.toLowerCase())) {
      print('Error: "$projectName" is a reserved name that conflicts with Dart packages.');
      print('Please choose a different project name.');
      print('');
      print('Reserved names: ${_reservedNames.join(', ')}');
      return 1;
    }

    // Validate project name follows Dart package naming conventions
    final validNameRegex = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!validNameRegex.hasMatch(projectName)) {
      print('Error: "$projectName" is not a valid Dart package name.');
      print('Package names must:');
      print('  - Start with a lowercase letter');
      print('  - Contain only lowercase letters, numbers, and underscores');
      print('');
      print('Example: my_app, hello_world, duxt_project');
      return 1;
    }

    final projectDir = Directory(p.join(Directory.current.path, projectName));

    if (projectDir.existsSync()) {
      print('Error: Directory "$projectName" already exists');
      return 1;
    }

    print('Creating Duxt project: $projectName');
    print('');

    try {
      await TemplateGenerator.generate(projectName, projectDir.path);

      print('');
      print('\x1B[32m✓\x1B[0m Project created successfully!');
      print('');
      print('Next steps:');
      print('  cd $projectName');
      print('  dart pub get');
      print('  duxt dev');
      print('');

      return 0;
    } catch (e) {
      print('Error creating project: $e');
      return 1;
    }
  }
}
