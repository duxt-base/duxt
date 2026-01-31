import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'templates/generator.dart';

/// Available rendering modes
enum ProjectMode {
  static('static', 'Static (SSG)', 'Pre-renders pages at build time. Best for blogs, docs, marketing sites.'),
  server('server', 'Server (SSR)', 'Renders pages on each request. Best for dynamic content. (Coming Soon)'),
  client('client', 'Client (SPA)', 'Client-side only. Best for web apps. (Coming Soon)');

  final String value;
  final String label;
  final String description;
  const ProjectMode(this.value, this.label, this.description);
}

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

  CreateCommand() {
    argParser.addOption(
      'mode',
      abbr: 'm',
      help: 'Rendering mode (static, server, client)',
      defaultsTo: null,
    );
  }

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

    // Show ASCII logo
    print('');
    print('\x1B[36m               88\x1B[0m');
    print('\x1B[36m               88\x1B[0m');
    print('\x1B[36m      .d88888b 88  db       db  db        db d88888888b\x1B[0m');
    print('\x1B[36m    .8P       Y88  88       88   `8b    d8\'      88\x1B[0m');
    print('\x1B[36m    88         88  88       88     `8bd8\'        88\x1B[0m');
    print('\x1B[36m    88         88  88       88     .dPYb.        88\x1B[0m');
    print('\x1B[36m    `8L       d89  88b     d88   .8P    Y8.      88\x1B[0m');
    print('\x1B[36m     `Y888888P8J    ~Y88888\'88  dP        Yb     `Y88P\x1B[0m');
    print('');
    print('\x1B[36m                     oooooooooooooooooooo\x1B[0m');
    print('');
    print('  Creating project: \x1B[1m$projectName\x1B[0m');
    print('');

    // Mode selection
    final modeArg = argResults!['mode'] as String?;
    String mode;

    if (modeArg != null) {
      // Non-interactive mode with --mode flag
      mode = 'static'; // Only static is supported for now
      print('  Mode: \x1B[36m${ProjectMode.static.label}\x1B[0m');
      print('');
    } else {
      // Interactive mode selection
      print('  Select rendering mode:');
      print('');
      for (var i = 0; i < ProjectMode.values.length; i++) {
        final m = ProjectMode.values[i];
        final isDisabled = m != ProjectMode.static;
        final marker = i == 0 ? '\x1B[32m>\x1B[0m' : ' ';
        final color = isDisabled ? '\x1B[90m' : '';
        final reset = isDisabled ? '\x1B[0m' : '';
        print('  $marker ${i + 1}. $color${m.label}$reset');
        print('       $color${m.description}$reset');
      }
      print('');

      stdout.write('  Enter choice [1]: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      final choice = int.tryParse(input) ?? 1;

      if (choice < 1 || choice > ProjectMode.values.length) {
        print('\x1B[31mInvalid choice. Using Static mode.\x1B[0m');
      }

      final selectedMode = ProjectMode.values[choice.clamp(1, ProjectMode.values.length) - 1];

      // Only allow static mode for now
      if (selectedMode != ProjectMode.static) {
        print('');
        print('\x1B[33m!\x1B[0m ${selectedMode.label} is coming soon. Using Static mode instead.');
      }

      mode = ProjectMode.static.value;
      print('');
      print('  Mode: \x1B[36m${ProjectMode.static.label}\x1B[0m');
      print('');
    }

    try {
      await TemplateGenerator.generate(projectName, projectDir.path, mode: mode);

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
