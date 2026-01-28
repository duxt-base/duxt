import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Short generate command (like Rails/Laravel style)
/// Usage: duxt g <type> <name> [field:type ...]
///
/// Examples:
///   duxt g page posts/[slug] title:String content:String
///   duxt g component post_card title:String excerpt:String image:String
///   duxt g model post title:String content:String published:bool
///   duxt g api posts
class GCommand extends Command<int> {
  @override
  final name = 'g';

  @override
  final description = 'Generate a page, component, model, or API route';

  @override
  String get invocation => 'duxt g <type> <name> [field:type ...]';

  GCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing files',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      _printUsage();
      return 1;
    }

    final type = argResults!.rest[0];
    if (argResults!.rest.length < 2) {
      print('Error: Please specify a name');
      _printUsage();
      return 1;
    }

    final name = argResults!.rest[1];
    final fields = _parseFields(argResults!.rest.skip(2).toList());
    final force = argResults!['force'] as bool;
    final projectDir = Directory.current.path;

    switch (type) {
      case 'page':
      case 'p':
        return _generatePage(projectDir, name, fields, force);
      case 'component':
      case 'c':
        return _generateComponent(projectDir, name, fields, force);
      case 'model':
      case 'm':
        return _generateModel(projectDir, name, fields, force);
      case 'api':
      case 'a':
        return _generateApi(projectDir, name, fields, force);
      case 'middleware':
      case 'mw':
        return _generateMiddleware(projectDir, name, force);
      case 'composable':
      case 'co':
        return _generateComposable(projectDir, name, fields, force);
      default:
        print('Error: Unknown type "$type"');
        _printUsage();
        return 1;
    }
  }

  void _printUsage() {
    print('');
    print('Usage: duxt g <type> <name> [field:type ...]');
    print('');
    print('Types:');
    print('  page, p        - Generate a new page');
    print('  component, c   - Generate a new component');
    print('  model, m       - Generate a new model class');
    print('  api, a         - Generate a new API route');
    print('  middleware, mw - Generate new middleware');
    print('  composable, co - Generate a new composable');
    print('');
    print('Examples:');
    print('  duxt g page posts/[slug] title:String content:String');
    print('  duxt g component post_card title:String excerpt:String');
    print('  duxt g model post title:String content:String author:String');
    print('  duxt g api posts');
  }

  List<FieldDef> _parseFields(List<String> args) {
    final fields = <FieldDef>[];
    for (final arg in args) {
      if (arg.contains(':')) {
        final parts = arg.split(':');
        fields.add(FieldDef(
          name: parts[0],
          type: _normalizeType(parts[1]),
        ));
      }
    }
    return fields;
  }

  String _normalizeType(String type) {
    switch (type.toLowerCase()) {
      case 'string':
      case 'str':
      case 'text':
        return 'String';
      case 'int':
      case 'integer':
        return 'int';
      case 'double':
      case 'float':
      case 'number':
        return 'double';
      case 'bool':
      case 'boolean':
        return 'bool';
      case 'date':
      case 'datetime':
        return 'DateTime';
      case 'list':
        return 'List<dynamic>';
      case 'map':
        return 'Map<String, dynamic>';
      default:
        return type;
    }
  }

  Future<int> _generatePage(String projectDir, String name, List<FieldDef> fields, bool force) async {
    final filePath = p.join(projectDir, 'lib', 'pages', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Page already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _pathToClassName(name);
    final isDynamic = name.contains('[');
    final routeParams = _extractRouteParams(name);

    final content = _buildPageContent(className, fields, routeParams, isDynamic);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated page: lib/pages/$name.dart');
    _printRouteHint(name, className, routeParams);

    return 0;
  }

  Future<int> _generateComponent(String projectDir, String name, List<FieldDef> fields, bool force) async {
    final filePath = p.join(projectDir, 'lib', 'components', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Component already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(name);
    final content = _buildComponentContent(className, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated component: lib/components/$name.dart');
    return 0;
  }

  Future<int> _generateModel(String projectDir, String name, List<FieldDef> fields, bool force) async {
    // Create models directory if it doesn't exist
    final modelsDir = Directory(p.join(projectDir, 'lib', 'models'));
    if (!modelsDir.existsSync()) {
      await modelsDir.create(recursive: true);
    }

    final filePath = p.join(projectDir, 'lib', 'models', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Model already exists. Use --force to overwrite.');
      return 1;
    }

    final className = _toPascalCase(name);
    final content = _buildModelContent(className, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated model: lib/models/$name.dart');
    return 0;
  }

  Future<int> _generateApi(String projectDir, String name, List<FieldDef> fields, bool force) async {
    final filePath = p.join(projectDir, 'server', 'api', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: API route already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final content = _buildApiContent(name, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated API route: server/api/$name.dart');
    print('  Endpoint: /api/$name');
    return 0;
  }

  Future<int> _generateMiddleware(String projectDir, String name, bool force) async {
    final filePath = p.join(projectDir, 'middleware', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Middleware already exists. Use --force to overwrite.');
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

    await next();
    return true;
  }
}
''';

    await file.writeAsString(content);
    print('\x1B[32m✓\x1B[0m Generated middleware: middleware/$name.dart');
    return 0;
  }

  Future<int> _generateComposable(String projectDir, String name, List<FieldDef> fields, bool force) async {
    final filePath = p.join(projectDir, 'composables', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Composable already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = 'Use${_toPascalCase(name)}';
    final content = _buildComposableContent(className, name, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated composable: composables/$name.dart');
    return 0;
  }

  // Content builders

  String _buildPageContent(String className, List<FieldDef> fields, List<String> routeParams, bool isDynamic) {
    final allParams = <FieldDef>[
      ...routeParams.map((p) => FieldDef(name: p, type: 'String')),
      ...fields,
    ];

    final hasParams = allParams.isNotEmpty;

    final paramFields = allParams.map((f) => '  final ${f.type} ${f.name};').join('\n');
    final constructorParams = allParams.map((f) => 'required this.${f.name}').join(', ');

    final displayFields = allParams.isNotEmpty
        ? allParams.map((f) => "        p(classes: 'text-gray-600', [text('${f.name}: \$${f.name}')]),").join('\n')
        : "        p(classes: 'text-gray-600', [text('Welcome to $className')]),";

    if (hasParams) {
      return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class $className extends StatelessComponent {
$paramFields

  const $className({
    super.key,
    $constructorParams,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-6', [
      h1(classes: 'text-3xl font-bold text-gray-900', [
        text('$className'),
      ]),
      div(classes: 'space-y-2', [
$displayFields
      ]),
    ]);
  }
}
''';
    } else {
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
$displayFields
    ]);
  }
}
''';
    }
  }

  String _buildComponentContent(String className, List<FieldDef> fields) {
    if (fields.isEmpty) {
      return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class $className extends StatelessComponent {
  const $className({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'p-4 bg-white rounded-lg shadow', [
      text('$className'),
    ]);
  }
}
''';
    }

    final paramFields = fields.map((f) => '  final ${f.type} ${f.name};').join('\n');
    final constructorParams = fields.map((f) => 'required this.${f.name}').join(', ');
    final displayFields = fields
        .map((f) => f.type == 'String'
            ? "        text(${f.name}),"
            : "        text('\$${f.name}'),")
        .join('\n');

    return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class $className extends StatelessComponent {
$paramFields

  const $className({
    super.key,
    $constructorParams,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'p-4 bg-white rounded-lg shadow', [
      div(classes: 'space-y-2', [
$displayFields
      ]),
    ]);
  }
}
''';
  }

  String _buildModelContent(String className, List<FieldDef> fields) {
    if (fields.isEmpty) {
      return '''
class $className {
  final String id;

  const $className({required this.id});

  factory $className.fromJson(Map<String, dynamic> json) {
    return $className(
      id: json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
''';
    }

    final paramFields = [
      '  final String id;',
      ...fields.map((f) => '  final ${f.type}${f.type.endsWith('?') ? '' : '?'} ${f.name};'),
    ].join('\n');

    final constructorParams = [
      'required this.id',
      ...fields.map((f) => 'this.${f.name}'),
    ].join(', ');

    final fromJsonFields = [
      "      id: json['id'] as String,",
      ...fields.map((f) => "      ${f.name}: json['${f.name}'] as ${f.type}?,"),
    ].join('\n');

    final toJsonFields = [
      "      'id': id,",
      ...fields.map((f) => "      '${f.name}': ${f.name},"),
    ].join('\n');

    return '''
class $className {
$paramFields

  const $className({
    $constructorParams,
  });

  factory $className.fromJson(Map<String, dynamic> json) {
    return $className(
$fromJsonFields
    );
  }

  Map<String, dynamic> toJson() {
    return {
$toJsonFields
    };
  }

  $className copyWith({
    String? id,
${fields.map((f) => '    ${f.type}? ${f.name},').join('\n')}
  }) {
    return $className(
      id: id ?? this.id,
${fields.map((f) => '      ${f.name}: ${f.name} ?? this.${f.name},').join('\n')}
    );
  }
}
''';
  }

  String _buildApiContent(String name, List<FieldDef> fields) {
    return '''
import 'package:duxt/server.dart';

/// API route: /api/$name
///
/// Supports: GET, POST, PUT, DELETE
final handler = defineEventHandler((request) async {
  switch (request.method) {
    case 'GET':
      // List all or get by ID
      final id = getQueryParam(request, 'id');
      if (id != null) {
        return ApiResponse.json({
          'id': id,
          // Add your fields here
        });
      }
      return ApiResponse.json({
        'items': [],
        'total': 0,
      });

    case 'POST':
      // Create new
      final body = request.json;
      return ApiResponse.created({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        ...body as Map<String, dynamic>,
      });

    case 'PUT':
      // Update
      final body = request.json;
      return ApiResponse.json(body);

    case 'DELETE':
      // Delete
      return ApiResponse.noContent();

    default:
      return ApiResponse.methodNotAllowed();
  }
});
''';
  }

  String _buildComposableContent(String className, String name, List<FieldDef> fields) {
    if (fields.isEmpty) {
      return '''
import 'package:duxt/duxt.dart';

class $className {
  final UseState<dynamic> _state;

  $className([dynamic initial]) : _state = UseState(initial);

  dynamic get value => _state.value;

  void setValue(dynamic newValue) {
    _state.value = newValue;
  }

  void listen(void Function(dynamic) listener) {
    _state.listen(listener);
  }
}
''';
    }

    final stateFields = fields.map((f) => '  final UseState<${f.type}> _${f.name};').join('\n');
    final initFields = fields.map((f) {
      final defaultValue = _getDefaultValue(f.type);
      return '      : _${f.name} = UseState($defaultValue)';
    }).join(',\n');

    final getters = fields.map((f) => '  ${f.type} get ${f.name} => _${f.name}.value;').join('\n');
    final setters = fields.map((f) => '''
  void set${_toPascalCase(f.name)}(${f.type} value) {
    _${f.name}.value = value;
  }''').join('\n\n');

    return '''
import 'package:duxt/duxt.dart';

class $className {
$stateFields

  $className()
$initFields;

$getters

$setters

  void reset() {
${fields.map((f) => '    _${f.name}.value = ${_getDefaultValue(f.type)};').join('\n')}
  }
}
''';
  }

  String _getDefaultValue(String type) {
    switch (type) {
      case 'String':
        return "''";
      case 'int':
        return '0';
      case 'double':
        return '0.0';
      case 'bool':
        return 'false';
      default:
        return 'null';
    }
  }

  // Helpers

  String _pathToClassName(String path) {
    final parts = path
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('...', '')
        .split('/')
        .where((p) => p.isNotEmpty)
        .map(_toPascalCase)
        .toList();

    if (parts.isEmpty) return 'IndexPage';
    return '${parts.join('')}Page';
  }

  String _toPascalCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'[_-]'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join('');
  }

  List<String> _extractRouteParams(String path) {
    final params = <String>[];
    final regex = RegExp(r'\[\.\.\.?(\w+)\]');
    for (final match in regex.allMatches(path)) {
      params.add(match.group(1)!);
    }
    return params;
  }

  void _printRouteHint(String name, String className, List<String> routeParams) {
    print('');
    print('Add to lib/app.dart:');
    print('  Route(');
    final routePath = '/' + name
        .replaceAllMapped(RegExp(r'\[\.\.\.(\w+)\]'), (m) => '*')
        .replaceAllMapped(RegExp(r'\[(\w+)\]'), (m) => ':${m.group(1)}');
    print("    path: '$routePath',");
    if (routeParams.isNotEmpty) {
      print('    builder: (context, state) => $className(');
      for (final param in routeParams) {
        print("      $param: state.pathParameters['$param']!,");
      }
      print('    ),');
    } else {
      print('    builder: (context, state) => const $className(),');
    }
    print('  ),');
  }
}

class FieldDef {
  final String name;
  final String type;

  FieldDef({required this.name, required this.type});
}
