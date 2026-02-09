import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'templates/generator.dart';

/// Available rendering modes
enum ProjectMode {
  static('static', 'Static (SSG)', 'Pre-renders pages at build time. Best for marketing sites, docs.'),
  server('server', 'Server (SSR)', 'Renders pages on each request. Best for dynamic content with database.'),
  client('client', 'Client (SPA)', 'Client-side only. Best for web apps. (Coming Soon)');

  final String value;
  final String label;
  final String description;
  const ProjectMode(this.value, this.label, this.description);

  /// Get default mode for a template
  static ProjectMode defaultForTemplate(ProjectTemplate template) {
    switch (template) {
      case ProjectTemplate.blog:
        return ProjectMode.server; // Blog needs database access for SSR
      case ProjectTemplate.saas:
        return ProjectMode.server; // SaaS needs auth/database
      case ProjectTemplate.marketing:
      case ProjectTemplate.minimal:
      case ProjectTemplate.html:
      case ProjectTemplate.defaultTemplate:
        return ProjectMode.static; // Static content sites
    }
  }
}

/// Available project templates
enum ProjectTemplate {
  defaultTemplate('default', 'Default', 'Full-featured demo with all examples'),
  minimal('minimal', 'Minimal', 'Clean starting point - just home page and layout'),
  saas('saas', 'SaaS', 'SaaS starter with auth, dashboard, and billing'),
  marketing('marketing', 'Marketing', 'Landing page with hero, features, and pricing'),
  blog('blog', 'Blog', 'Professional blog with categories and SEO'),
  html('html', 'HTML', 'Flutter-style HTML components with duxt_html');

  final String value;
  final String label;
  final String description;
  const ProjectTemplate(this.value, this.label, this.description);

  static ProjectTemplate fromValue(String value) {
    return ProjectTemplate.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ProjectTemplate.defaultTemplate,
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
    argParser.addOption(
      'template',
      abbr: 't',
      help: 'Project template',
      allowed: ProjectTemplate.values.map((t) => t.value).toList(),
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

    // Template selection
    final templateArg = argResults!['template'] as String?;
    String template;

    if (templateArg != null) {
      // Non-interactive mode with --template flag
      final selected = ProjectTemplate.fromValue(templateArg);
      if (selected == ProjectTemplate.saas) {
        print('  \x1B[33m!\x1B[0m SaaS template requires duxt_auth (coming soon). Using Default instead.');
        template = 'default';
      } else {
        template = selected.value;
      }
    } else {
      // Interactive template selection
      print('  Select a project template:');
      print('');
      for (var i = 0; i < ProjectTemplate.values.length; i++) {
        final t = ProjectTemplate.values[i];
        final isDisabled = t == ProjectTemplate.saas;
        final marker = i == 0 ? '\x1B[32m>\x1B[0m' : ' ';
        final color = isDisabled ? '\x1B[90m' : '';
        final reset = isDisabled ? '\x1B[0m' : '';
        final suffix = isDisabled ? ' (Coming Soon)' : '';
        print('  $marker ${i + 1}. $color${t.label}$suffix$reset');
        print('       $color${t.description}$reset');
      }
      print('');

      stdout.write('  Enter choice [1]: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      final choice = int.tryParse(input) ?? 1;

      if (choice < 1 || choice > ProjectTemplate.values.length) {
        print('\x1B[31mInvalid choice. Using Default template.\x1B[0m');
      }

      final chosenTemplate = ProjectTemplate.values[choice.clamp(1, ProjectTemplate.values.length) - 1];

      // SaaS template requires duxt_auth
      if (chosenTemplate == ProjectTemplate.saas) {
        print('');
        print('\x1B[33m!\x1B[0m SaaS template requires duxt_auth (coming soon). Using Default instead.');
        template = 'default';
      } else {
        template = chosenTemplate.value;
      }
    }

    // Mode selection
    final modeArg = argResults!['mode'] as String?;
    final finalTemplate = ProjectTemplate.fromValue(template);
    String mode;
    ProjectMode selectedMode;

    if (modeArg != null) {
      // Explicit mode via --mode flag
      selectedMode = ProjectMode.values.firstWhere(
        (m) => m.value == modeArg,
        orElse: () => ProjectMode.static,
      );
      mode = selectedMode.value;
    } else if (templateArg != null) {
      // Template specified via flag - use template's default mode, skip prompt
      selectedMode = ProjectMode.defaultForTemplate(finalTemplate);
      mode = selectedMode.value;
    } else {
      // Interactive mode selection (only when no template flag)
      final defaultMode = ProjectMode.defaultForTemplate(finalTemplate);
      final defaultIndex = ProjectMode.values.indexOf(defaultMode);

      print('');
      print('  Select rendering mode:');
      print('');
      for (var i = 0; i < ProjectMode.values.length; i++) {
        final m = ProjectMode.values[i];
        final isDisabled = m == ProjectMode.client; // Only client mode disabled for now
        final isDefault = i == defaultIndex;
        final marker = isDefault ? '\x1B[32m>\x1B[0m' : ' ';
        final color = isDisabled ? '\x1B[90m' : '';
        final reset = isDisabled ? '\x1B[0m' : '';
        final suffix = isDisabled ? ' (Coming Soon)' : (isDefault ? ' (Recommended)' : '');
        print('  $marker ${i + 1}. $color${m.label}$suffix$reset');
        print('       $color${m.description}$reset');
      }
      print('');

      stdout.write('  Enter choice [${defaultIndex + 1}]: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      final choice = int.tryParse(input) ?? (defaultIndex + 1);

      if (choice < 1 || choice > ProjectMode.values.length) {
        print('\x1B[31mInvalid choice. Using ${defaultMode.label}.\x1B[0m');
        selectedMode = defaultMode;
      } else {
        selectedMode = ProjectMode.values[choice - 1];
      }

      // Only client mode is disabled for now
      if (selectedMode == ProjectMode.client) {
        print('');
        print('\x1B[33m!\x1B[0m ${selectedMode.label} is coming soon. Using ${defaultMode.label} instead.');
        selectedMode = defaultMode;
      }

      mode = selectedMode.value;
    }

    print('');
    print('  Mode: \x1B[36m${selectedMode.label}\x1B[0m');
    print('  Template: \x1B[36m${finalTemplate.label}\x1B[0m');
    print('');

    try {
      await TemplateGenerator.generate(projectName, projectDir.path, mode: mode, template: template);

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
