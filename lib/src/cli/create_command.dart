import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'templates/static_template.dart';
import 'templates/server_template.dart';
import 'templates/client_template.dart';
import 'tauri_scaffold.dart';

/// Available project templates — each maps to a rendering mode
enum ProjectTemplate {
  static_('static', 'Static (SSG)', 'Marketing sites, landing pages, docs. Pre-rendered at build time.'),
  server('server', 'Server (SSR)', 'Dynamic apps, blogs, content sites. Server-rendered with ORM + API.'),
  client('client', 'Client (SPA)', 'Interactive single-page apps. Client-side rendering with signals.');

  final String value;
  final String label;
  final String description;
  const ProjectTemplate(this.value, this.label, this.description);

  static ProjectTemplate fromValue(String value) {
    return ProjectTemplate.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ProjectTemplate.static_,
    );
  }
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
/// Usage: `duxt create <project-name>`
class CreateCommand extends Command<int> {
  @override
  final name = 'create';

  @override
  final description = 'Create a new Duxt project';

  @override
  String get invocation => 'duxt create <project-name>';

  CreateCommand() {
    argParser.addOption(
      'template',
      abbr: 't',
      help: 'Project template (static, server, client)',
      allowed: ProjectTemplate.values.map((t) => t.value).toList(),
      defaultsTo: null,
    );
    argParser.addFlag(
      'desktop',
      help: 'Set up as desktop app (forces client template, scaffolds Tauri)',
      defaultsTo: false,
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

    // Template selection (template = mode, single choice)
    final templateArg = argResults!['template'] as String?;
    final isDesktop = argResults!['desktop'] as bool;
    ProjectTemplate selectedTemplate;

    if (isDesktop) {
      // Desktop mode forces client (SPA) template
      selectedTemplate = ProjectTemplate.client;
      print('  \x1B[36mDesktop mode:\x1B[0m using Client (SPA) template');
    } else if (templateArg != null) {
      // Non-interactive mode with --template flag
      selectedTemplate = ProjectTemplate.fromValue(templateArg);
    } else {
      // Interactive template selection
      print('  Select a template:');
      print('');
      for (var i = 0; i < ProjectTemplate.values.length; i++) {
        final t = ProjectTemplate.values[i];
        final marker = i == 0 ? '\x1B[32m>\x1B[0m' : ' ';
        print('  $marker ${i + 1}. ${t.label}');
        print('       ${t.description}');
      }
      print('');

      stdout.write('  Enter choice [1]: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      final choice = int.tryParse(input) ?? 1;

      if (choice < 1 || choice > ProjectTemplate.values.length) {
        print('\x1B[31mInvalid choice. Using Static template.\x1B[0m');
        selectedTemplate = ProjectTemplate.static_;
      } else {
        selectedTemplate = ProjectTemplate.values[choice - 1];
      }
    }

    print('');
    print('  Template: \x1B[36m${selectedTemplate.label}\x1B[0m');
    print('');

    try {
      final dartName = projectName.replaceAll('-', '_').replaceAll(' ', '_');

      switch (selectedTemplate) {
        case ProjectTemplate.static_:
          await StaticTemplate.generate(dartName, projectDir.path);
        case ProjectTemplate.server:
          await ServerTemplate.generate(dartName, projectDir.path);
        case ProjectTemplate.client:
          await ClientTemplate.generate(dartName, projectDir.path);
      }

      // Scaffold Tauri desktop project if --desktop flag
      if (isDesktop) {
        print('');
        print('\x1B[90m→\x1B[0m Scaffolding Tauri desktop project...');
        await TauriScaffold.scaffold(projectDir.path, dartName);
      }

      // Warm build cache — run dart pub get so first `duxt dev` is faster
      print('');
      print('\x1B[90m→\x1B[0m Installing dependencies...');
      final pubGetResult = await Process.run(
        'dart', ['pub', 'get'],
        workingDirectory: projectDir.path,
      );
      if (pubGetResult.exitCode == 0) {
        print('  \x1B[32m✓\x1B[0m Dependencies installed');

        // Warm build cache so first `duxt dev` starts fast
        print('');
        print('\x1B[90m→\x1B[0m Warming build cache (this only happens once)...');
        final buildTimer = Stopwatch()..start();
        final buildResult = await Process.run(
          'dart', ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
          workingDirectory: projectDir.path,
        );
        buildTimer.stop();
        if (buildResult.exitCode == 0) {
          print('  \x1B[32m✓\x1B[0m Build cache warmed in ${(buildTimer.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
        } else {
          print('  \x1B[33m!\x1B[0m Build cache warmup failed (first `duxt dev` will be slower)');
        }
      } else {
        print('  \x1B[33m!\x1B[0m Could not install dependencies automatically');
      }

      print('');
      print('\x1B[32m✓\x1B[0m Project created successfully!');
      print('');
      print('Next steps:');
      print('  cd $projectName');
      if (isDesktop) {
        print('  duxt build desktop');
      } else {
        print('  duxt dev');
      }
      print('');

      return 0;
    } catch (e) {
      print('Error creating project: $e');
      return 1;
    }
  }
}
