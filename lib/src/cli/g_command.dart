import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Generate command - Short generator for modules, pages, components
/// Usage: duxt g <type> <module>/<name> [field:type ...]
///
/// Examples:
///   duxt g module posts
///   duxt g page posts/[id]
///   duxt g component posts/card title:String
///   duxt g model posts title:String content:String
///   duxt g api posts
class GCommand extends Command<int> {
  @override
  final name = 'g';

  @override
  final description = 'Generate module, page, component, model, or api';

  @override
  String get invocation => 'duxt g <type> <module/name> [field:type ...]';

  GCommand() {
    argParser.addFlag('force', abbr: 'f', help: 'Overwrite existing files');
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      _printUsage();
      return 1;
    }

    final type = argResults!.rest[0];
    if (argResults!.rest.length < 2 && type != 'module') {
      print('Error: Please specify a name');
      _printUsage();
      return 1;
    }

    final target = argResults!.rest.length > 1 ? argResults!.rest[1] : '';
    final fields = _parseFields(argResults!.rest.skip(2).toList());
    final force = argResults!['force'] as bool;
    final projectDir = Directory.current.path;

    switch (type) {
      case 'module':
      case 'mod':
        return _generateModule(projectDir, target, force);
      case 'page':
      case 'p':
        return _generatePage(projectDir, target, fields, force);
      case 'component':
      case 'c':
        return _generateComponent(projectDir, target, fields, force);
      case 'model':
      case 'm':
        return _generateModel(projectDir, target, fields, force);
      case 'api':
      case 'a':
        return _generateApi(projectDir, target, fields, force);
      case 'layout':
      case 'l':
        return _generateLayout(projectDir, target, force);
      default:
        print('Error: Unknown type "$type"');
        _printUsage();
        return 1;
    }
  }

  void _printUsage() {
    print('');
    print('Usage: duxt g <type> <module/name> [field:type ...]');
    print('');
    print('Types:');
    print('  module, mod  - Generate a new module');
    print('  page, p      - Generate a page in a module');
    print('  component, c - Generate a component in a module');
    print('  model, m     - Generate a model in a module');
    print('  api, a       - Generate an API route in a module');
    print('  layout, l    - Generate a layout in shared/layouts');
    print('');
    print('Examples:');
    print('  duxt g module posts                     # Create posts module');
    print('  duxt g page posts/[id]                  # Create posts/pages/[id].dart');
    print('  duxt g component posts/card title:String');
    print('  duxt g model posts title:String content:String');
    print('  duxt g api posts                        # Create server/api/posts.dart');
    print('  duxt g layout admin                     # Create shared/layouts/admin.dart');
  }

  List<FieldDef> _parseFields(List<String> args) {
    final fields = <FieldDef>[];
    for (final arg in args) {
      if (arg.contains(':')) {
        final parts = arg.split(':');
        fields.add(FieldDef(name: parts[0], type: _normalizeType(parts[1])));
      }
    }
    return fields;
  }

  String _normalizeType(String type) {
    switch (type.toLowerCase()) {
      case 'string':
      case 'str':
        return 'String';
      case 'int':
      case 'integer':
        return 'int';
      case 'double':
      case 'float':
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

  // Parse module/name format
  (String module, String name) _parseTarget(String target) {
    if (target.contains('/')) {
      final parts = target.split('/');
      return (parts[0], parts.sublist(1).join('/'));
    }
    return (target, 'index');
  }

  Future<int> _generateModule(String projectDir, String moduleName, bool force) async {
    if (moduleName.isEmpty) {
      print('Error: Please specify a module name');
      return 1;
    }

    final moduleDir = p.join(projectDir, 'lib', moduleName);
    if (Directory(moduleDir).existsSync() && !force) {
      print('Error: Module "$moduleName" already exists. Use --force to overwrite.');
      return 1;
    }

    // Create directories
    await Directory(p.join(moduleDir, 'pages')).create(recursive: true);
    await Directory(p.join(moduleDir, 'components')).create(recursive: true);

    // Create index page
    final className = _toPascalCase(moduleName);
    final pageContent = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class ${className}Page extends StatelessComponent {
  const ${className}Page({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-6', [
      h1(classes: 'text-3xl font-bold text-gray-900', [
        text('$className'),
      ]),
      p(classes: 'text-gray-600', [
        text('Welcome to the $moduleName module'),
      ]),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', 'index.dart')).writeAsString(pageContent);

    print('\x1B[32m✓\x1B[0m Generated module: $moduleName/');
    print('    pages/index.dart');
    print('    components/');
    print('');
    print('Add route to lib/app.dart:');
    print("  Route(path: '/$moduleName', builder: (_, __) => const ${className}Page()),");
    return 0;
  }

  Future<int> _generatePage(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final (module, name) = _parseTarget(target);
    final filePath = p.join(projectDir, 'lib', module, 'pages', '$name.dart');
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

    print('\x1B[32m✓\x1B[0m Generated page: lib/$module/pages/$name.dart');
    _printRouteHint(module, name, className, routeParams);
    return 0;
  }

  Future<int> _generateComponent(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final (module, name) = _parseTarget(target);
    final filePath = p.join(projectDir, 'lib', module, 'components', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Component already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(name);
    final content = _buildComponentContent(className, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated component: lib/$module/components/$name.dart');
    return 0;
  }

  Future<int> _generateModel(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final (module, _) = _parseTarget(target);
    final filePath = p.join(projectDir, 'lib', module, 'model.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Model already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(module);
    final content = _buildModelContent(className, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated model: lib/$module/model.dart');
    return 0;
  }

  Future<int> _generateApi(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final (module, name) = _parseTarget(target);
    final apiName = name == 'index' ? module : name;
    final filePath = p.join(projectDir, 'lib', module, 'api.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: API already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(module);
    final content = _buildApiContent(className, module, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated API: lib/$module/api.dart');
    print('  Endpoint: /api/$apiName');
    return 0;
  }

  Future<int> _generateLayout(String projectDir, String name, bool force) async {
    final filePath = p.join(projectDir, 'lib', 'shared', 'layouts', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Layout already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = '${_toPascalCase(name)}Layout';
    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class $className extends StatelessComponent {
  final Component child;

  const $className({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen', [
      // Header
      header(classes: 'bg-white shadow-sm', [
        div(classes: 'max-w-7xl mx-auto px-4 py-4', [
          text('$className'),
        ]),
      ]),
      // Content
      main_(classes: 'max-w-7xl mx-auto px-4 py-8', [
        child,
      ]),
    ]);
  }
}
''';
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated layout: lib/shared/layouts/$name.dart');
    return 0;
  }

  // Content builders

  String _buildPageContent(String className, List<FieldDef> fields, List<String> routeParams, bool isDynamic) {
    final allParams = [
      ...routeParams.map((p) => FieldDef(name: p, type: 'String')),
      ...fields,
    ];

    if (allParams.isEmpty) {
      return '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class $className extends StatelessComponent {
  const $className({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-6', [
      h1(classes: 'text-3xl font-bold text-gray-900', [
        text('$className'),
      ]),
    ]);
  }
}
''';
    }

    final paramFields = allParams.map((f) => '  final ${f.type} ${f.name};').join('\n');
    final constructorParams = allParams.map((f) => 'required this.${f.name}').join(', ');
    final displayFields = allParams.map((f) =>
      "        p(classes: 'text-gray-600', [Component.text('${f.name}: \$${f.name}')]),").join('\n');

    return '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

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
  }

  String _buildComponentContent(String className, List<FieldDef> fields) {
    if (fields.isEmpty) {
      return '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

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

    return '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class $className extends StatelessComponent {
$paramFields

  const $className({
    super.key,
    $constructorParams,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'p-4 bg-white rounded-lg shadow', [
${fields.map((f) => "      p([Component.text('\$${f.name}')]),").join('\n')}
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
    return $className(id: json['id'] as String);
  }

  Map<String, dynamic> toJson() => {'id': id};
}
''';
    }

    final allFields = [FieldDef(name: 'id', type: 'String'), ...fields];
    final paramFields = allFields.map((f) => '  final ${f.type} ${f.name};').join('\n');
    final constructorParams = allFields.map((f) =>
      f.name == 'id' ? 'required this.id' : 'this.${f.name}').join(', ');
    final fromJsonFields = allFields.map((f) =>
      "      ${f.name}: json['${f.name}'] as ${f.type}${f.name == 'id' ? '' : '?'},").join('\n');
    final toJsonFields = allFields.map((f) =>
      "      '${f.name}': ${f.name},").join('\n');

    return '''
class $className {
$paramFields

  const $className({$constructorParams});

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

  static List<$className> fromList(List<dynamic> list) {
    return list.map((e) => $className.fromJson(e as Map<String, dynamic>)).toList();
  }
}
''';
  }

  String _buildApiContent(String className, String module, List<FieldDef> fields) {
    return '''
import 'package:duxt/duxt.dart';
import 'model.dart';

/// API calls for $module module
class ${className}Api {
  static Future<List<$className>> getAll() async {
    final data = await Api.get('/$module');
    return $className.fromList(data as List);
  }

  static Future<$className> getOne(String id) async {
    final data = await Api.get('/$module/\$id');
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<$className> create($className item) async {
    final data = await Api.post('/$module', body: item.toJson());
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<$className> update(String id, $className item) async {
    final data = await Api.put('/$module/\$id', body: item.toJson());
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await Api.delete('/$module/\$id');
  }
}
''';
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

  void _printRouteHint(String module, String name, String className, List<String> routeParams) {
    print('');
    print('Add route to lib/app.dart:');
    final routePath = '/$module${name == 'index' ? '' : '/$name'}'
        .replaceAllMapped(RegExp(r'\[\.\.\.(\w+)\]'), (m) => '*')
        .replaceAllMapped(RegExp(r'\[(\w+)\]'), (m) => ':${m.group(1)}');
    print('  Route(');
    print("    path: '$routePath',");
    if (routeParams.isNotEmpty) {
      print('    builder: (context, state) => $className(');
      for (final param in routeParams) {
        print("      $param: state.params['$param']!,");
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
