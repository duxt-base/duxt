import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/template_generator.dart';

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
