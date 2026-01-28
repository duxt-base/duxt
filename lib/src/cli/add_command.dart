import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Command to add new modules (pages, components, middleware, api routes)
/// Usage: duxt add <type> <name>
class AddCommand extends Command<int> {
  @override
  final name = 'add';

  @override
  final description = 'Add a new page, component, middleware, or API route';

  @override
  String get invocation => 'duxt add <type> <name>';

  AddCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing files',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.length < 2) {
      print('Error: Please specify type and name');
      print('Usage: duxt add <type> <name>');
      print('');
      print('Types:');
      print('  page <name>       - Add a new page (e.g., duxt add page posts/[slug])');
      print('  component <name>  - Add a new component');
      print('  middleware <name> - Add new middleware');
      print('  api <name>        - Add a new API route');
      print('  composable <name> - Add a new composable');
      return 1;
    }

    final type = argResults!.rest[0];
    final name = argResults!.rest[1];
    final force = argResults!['force'] as bool;
    final projectDir = Directory.current.path;

    switch (type) {
      case 'page':
        return _addPage(projectDir, name, force);
      case 'component':
        return _addComponent(projectDir, name, force);
      case 'middleware':
        return _addMiddleware(projectDir, name, force);
      case 'api':
        return _addApiRoute(projectDir, name, force);
      case 'composable':
        return _addComposable(projectDir, name, force);
      default:
        print('Error: Unknown type "$type"');
        print('Valid types: page, component, middleware, api, composable');
        return 1;
    }
  }

  Future<int> _addPage(String projectDir, String name, bool force) async {
    // Handle dynamic routes: posts/[slug] -> posts/[slug].dart
    final filePath = p.join(projectDir, 'lib', 'pages', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Page already exists: $filePath');
      print('Use --force to overwrite');
      return 1;
    }

    // Create parent directories
    await file.parent.create(recursive: true);

    // Generate class name from path
    final className = _pathToClassName(name);

    // Check if it's a dynamic route
    final isDynamic = name.contains('[');
    final params = _extractParams(name);

    String content;
    if (isDynamic && params.isNotEmpty) {
      content = _generateDynamicPage(className, params);
    } else {
      content = _generateStaticPage(className);
    }

    await file.writeAsString(content);
    print('\x1B[32m✓\x1B[0m Created page: lib/pages/$name.dart');

    // Remind user to add route
    print('');
    print('Don\'t forget to add the route to lib/app.dart:');
    if (isDynamic && params.isNotEmpty) {
      final routePath = _nameToRoutePath(name);
      print('  Route(');
      print('    path: \'$routePath\',');
      print('    builder: (context, state) => $className(');
      for (final param in params) {
        print('      $param: state.pathParameters[\'$param\']!,');
      }
      print('    ),');
      print('  ),');
    } else {
      print('  Route(');
      print('    path: \'/${name.replaceAll('index', '').replaceAll('//', '/')}\',');
      print('    builder: (context, state) => const $className(),');
      print('  ),');
    }

    return 0;
  }

  Future<int> _addComponent(String projectDir, String name, bool force) async {
    final filePath = p.join(projectDir, 'lib', 'components', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Component already exists: $filePath');
      print('Use --force to overwrite');
      return 1;
    }

    await file.parent.create(recursive: true);
    final className = _pathToClassName(name);

    final content = '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class $className extends StatelessComponent {
  const $className({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: '', [
      text('$className component'),
    ]);
  }
}
''';

    await file.writeAsString(content);
    print('\x1B[32m✓\x1B[0m Created component: lib/components/$name.dart');
    return 0;
  }

  Future<int> _addMiddleware(String projectDir, String name, bool force) async {
    final filePath = p.join(projectDir, 'middleware', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Middleware already exists: $filePath');
      print('Use --force to overwrite');
      return 1;
    }

    await file.parent.create(recursive: true);
    final className = _toPascalCase(name);

    final content = '''
import 'package:duxt/duxt.dart';

class ${className}Middleware extends DuxtMiddleware {
  @override
  String get name => '$name';

  @override
  Future<bool> handle(DuxtContext context, Future<void> Function() next) async {
    // Add your middleware logic here

    // Continue to the route
    await next();
    return true;
  }
}
''';

    await file.writeAsString(content);
    print('\x1B[32m✓\x1B[0m Created middleware: middleware/$name.dart');
    return 0;
  }

  Future<int> _addApiRoute(String projectDir, String name, bool force) async {
    final filePath = p.join(projectDir, 'server', 'api', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: API route already exists: $filePath');
      print('Use --force to overwrite');
      return 1;
    }

    await file.parent.create(recursive: true);

    final content = r'''
import 'package:duxt/server.dart';

/// API route: /api/''' + name + r'''
final handler = defineEventHandler((request) async {
  switch (request.method) {
    case 'GET':
      return ApiResponse.json({
        'message': 'GET /api/''' + name + r'''',
      });
    case 'POST':
      final body = request.json;
      return ApiResponse.created(body);
    default:
      return ApiResponse.methodNotAllowed();
  }
});
''';

    await file.writeAsString(content);
    print('\x1B[32m✓\x1B[0m Created API route: server/api/$name.dart');
    print('  Accessible at: /api/$name');
    return 0;
  }

  Future<int> _addComposable(String projectDir, String name, bool force) async {
    final filePath = p.join(projectDir, 'composables', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Composable already exists: $filePath');
      print('Use --force to overwrite');
      return 1;
    }

    await file.parent.create(recursive: true);
    final className = 'Use${_toPascalCase(name)}';

    final content = '''
import 'package:duxt/duxt.dart';

/// Composable: $className
class $className {
  final UseState<String> _state;

  $className([String initial = '']) : _state = UseState(initial);

  String get value => _state.value;

  void setValue(String newValue) {
    _state.value = newValue;
  }

  void listen(void Function(String) listener) {
    _state.listen(listener);
  }
}
''';

    await file.writeAsString(content);
    print('\x1B[32m✓\x1B[0m Created composable: composables/$name.dart');
    return 0;
  }

  String _pathToClassName(String path) {
    // posts/[slug] -> PostsSlugPage
    // index -> IndexPage
    final parts = path
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('...', '')
        .split('/')
        .where((p) => p.isNotEmpty)
        .map(_toPascalCase)
        .toList();

    if (parts.isEmpty) {
      return 'IndexPage';
    }
    return '${parts.join('')}Page';
  }

  String _toPascalCase(String s) {
    if (s.isEmpty) return s;
    // Handle snake_case and kebab-case
    return s
        .split(RegExp(r'[_-]'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join('');
  }

  List<String> _extractParams(String path) {
    final params = <String>[];
    final regex = RegExp(r'\[\.\.\.?(\w+)\]');
    for (final match in regex.allMatches(path)) {
      params.add(match.group(1)!);
    }
    return params;
  }

  String _nameToRoutePath(String name) {
    // posts/[slug] -> /posts/:slug
    // posts/[...all] -> /posts/*
    return '/' + name
        .replaceAllMapped(RegExp(r'\[\.\.\.(\w+)\]'), (m) => '*')
        .replaceAllMapped(RegExp(r'\[(\w+)\]'), (m) => ':${m.group(1)}');
  }

  String _generateStaticPage(String className) {
    return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class $className extends StatelessComponent {
  const $className({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-6', [
      h1(classes: 'text-3xl font-bold text-gray-900', [
        text('$className'),
      ]),
      p(classes: 'text-gray-600', [
        text('This is the $className page.'),
      ]),
    ]);
  }
}
''';
  }

  String _generateDynamicPage(String className, List<String> params) {
    final paramFields = params.map((p) => '  final String $p;').join('\n');
    final paramConstructor = params.map((p) => 'required this.$p').join(', ');

    return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class $className extends StatelessComponent {
$paramFields

  const $className({
    super.key,
    $paramConstructor,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-6', [
      h1(classes: 'text-3xl font-bold text-gray-900', [
        text('$className'),
      ]),
      div(classes: 'text-gray-600', [
${params.map((p) => "        p([text('$p: \$$p')]),").join('\n')}
      ]),
    ]);
  }
}
''';
  }
}
