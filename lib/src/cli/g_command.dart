import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Generate command - Short generator for modules, pages, components
/// Usage: duxt g <type> <module>/<name> [field:type ...]
///
/// Examples:
///   duxt g module posts
///   duxt g page posts/_id_
///   duxt g component posts/card title:String
///   duxt g model posts title:String content:String
///   duxt g api posts
///
/// Namespace examples:
///   duxt g module Admin/Post        → lib/admin/post/pages/
///   duxt g page Admin/Post/edit     → lib/admin/post/pages/edit.dart
///   duxt g layout Admin             → lib/admin/layouts/default.dart
///   duxt g module Theme/Blog        → lib/theme/blog/pages/
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
    print('  layout, l    - Generate a layout (shared or namespace)');
    print('');
    print('Examples:');
    print('  duxt g module posts                     # Create posts module');
    print('  duxt g page posts/_id_                  # Create posts/pages/_id_.dart');
    print('  duxt g component posts/card title:String');
    print('  duxt g model posts title:String content:String');
    print('  duxt g api posts                        # Create server/api/posts.dart');
    print('  duxt g layout admin                     # Create shared/layouts/admin.dart');
    print('');
    print('Namespace examples (uppercase first letter = namespace):');
    print('  duxt g module Admin/Post                # Create lib/admin/post/');
    print('  duxt g page Admin/Post/edit             # Create lib/admin/post/pages/edit.dart');
    print('  duxt g layout Admin                     # Create lib/admin/layouts/default.dart');
    print('  duxt g module Theme/Blog                # Create lib/theme/blog/');
    print('  duxt g module Theme/Home                # Create lib/theme/home/ (maps to /)');
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

  /// Parse target into namespace, module, and name.
  ///
  /// Convention: Uppercase first letter = namespace.
  ///   'Admin/Post'      → namespace=admin, module=post, name=index
  ///   'Admin/Post/edit' → namespace=admin, module=post, name=edit
  ///   'posts'           → namespace='', module=posts, name=index
  ///   'posts/_id_'      → namespace='', module=posts, name=_id_
  ({String namespace, String module, String name}) _parseTarget(String target) {
    final parts = target.split('/');

    if (parts.length == 1) {
      return (namespace: '', module: parts[0].toLowerCase(), name: 'index');
    }

    if (parts.length == 2) {
      // Check if first part is a namespace (starts with uppercase)
      if (_isNamespace(parts[0])) {
        return (
          namespace: parts[0].toLowerCase(),
          module: parts[1].toLowerCase(),
          name: 'index',
        );
      }
      // Flat module/name
      return (namespace: '', module: parts[0].toLowerCase(), name: parts[1]);
    }

    // 3+ parts: check if first part is namespace
    if (_isNamespace(parts[0])) {
      return (
        namespace: parts[0].toLowerCase(),
        module: parts[1].toLowerCase(),
        name: parts.sublist(2).join('/'),
      );
    }

    // No namespace, first part is module, rest is nested page name
    return (
      namespace: '',
      module: parts[0].toLowerCase(),
      name: parts.sublist(1).join('/'),
    );
  }

  /// Check if a string starts with an uppercase letter (namespace convention).
  bool _isNamespace(String s) => s.isNotEmpty && s[0] == s[0].toUpperCase() && s[0] != s[0].toLowerCase();

  /// Get the base directory path for a module, respecting namespace.
  String _modulePath(String projectDir, String namespace, String module) {
    if (namespace.isEmpty) {
      return p.join(projectDir, 'lib', module);
    }
    return p.join(projectDir, 'lib', namespace, module);
  }

  /// Get the display path (for print messages) like 'admin/post' or 'posts'.
  String _displayPath(String namespace, String module) {
    if (namespace.isEmpty) return module;
    return '$namespace/$module';
  }

  Future<int> _generateModule(String projectDir, String moduleName, bool force) async {
    if (moduleName.isEmpty) {
      print('Error: Please specify a module name');
      return 1;
    }

    final parsed = _parseTarget(moduleName);
    final moduleDir = _modulePath(projectDir, parsed.namespace, parsed.module);
    final display = _displayPath(parsed.namespace, parsed.module);

    if (Directory(moduleDir).existsSync() && !force) {
      print('Error: Module "$display" already exists. Use --force to overwrite.');
      return 1;
    }

    // Create directories
    await Directory(p.join(moduleDir, 'pages')).create(recursive: true);
    await Directory(p.join(moduleDir, 'components')).create(recursive: true);

    // Create index page
    final className = _toPascalCase(parsed.module);
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
        text('Welcome to the ${parsed.module} module'),
      ]),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', 'index.dart')).writeAsString(pageContent);

    // Build expected route path
    String routePath;
    if (parsed.namespace == 'theme') {
      routePath = parsed.module == 'home' ? '/' : '/${parsed.module}';
    } else if (parsed.namespace.isNotEmpty) {
      routePath = '/${parsed.namespace}/${parsed.module}';
    } else {
      routePath = '/${parsed.module}';
    }

    print('\x1B[32m✓\x1B[0m Generated module: $display/');
    print('    pages/index.dart');
    print('    components/');
    print('');
    print('Route: $routePath → ${className}Page');
    return 0;
  }

  Future<int> _generatePage(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final parsed = _parseTarget(target);
    final moduleDir = _modulePath(projectDir, parsed.namespace, parsed.module);
    final display = _displayPath(parsed.namespace, parsed.module);
    final filePath = p.join(moduleDir, 'pages', '${parsed.name}.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Page already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _pathToClassName(parsed.name);
    final isDynamic = parsed.name.contains('[');
    final routeParams = _extractRouteParams(parsed.name);

    final content = _buildPageContent(className, fields, routeParams, isDynamic);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated page: lib/$display/pages/${parsed.name}.dart');
    _printRouteHint(parsed.namespace, parsed.module, parsed.name, className, routeParams);
    return 0;
  }

  Future<int> _generateComponent(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final parsed = _parseTarget(target);
    final moduleDir = _modulePath(projectDir, parsed.namespace, parsed.module);
    final display = _displayPath(parsed.namespace, parsed.module);
    final name = parsed.name == 'index' ? parsed.module : parsed.name;
    final filePath = p.join(moduleDir, 'components', '$name.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Component already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(name);
    final content = _buildComponentContent(className, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated component: lib/$display/components/$name.dart');
    return 0;
  }

  Future<int> _generateModel(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final parsed = _parseTarget(target);
    final moduleDir = _modulePath(projectDir, parsed.namespace, parsed.module);
    final display = _displayPath(parsed.namespace, parsed.module);
    final filePath = p.join(moduleDir, 'model.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Model already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(parsed.module);
    final content = _buildModelContent(className, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated model: lib/$display/model.dart');
    return 0;
  }

  Future<int> _generateApi(String projectDir, String target, List<FieldDef> fields, bool force) async {
    final parsed = _parseTarget(target);
    final moduleDir = _modulePath(projectDir, parsed.namespace, parsed.module);
    final display = _displayPath(parsed.namespace, parsed.module);
    final filePath = p.join(moduleDir, 'api.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: API already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = _toPascalCase(parsed.module);
    // API path includes namespace prefix
    final apiPath = parsed.namespace.isEmpty ? parsed.module : '${parsed.namespace}/${parsed.module}';
    final content = _buildApiContent(className, apiPath, fields);
    await file.writeAsString(content);

    print('\x1B[32m✓\x1B[0m Generated API: lib/$display/api.dart');
    print('  Endpoint: /api/$apiPath');
    return 0;
  }

  Future<int> _generateLayout(String projectDir, String name, bool force) async {
    // Check if name looks like a namespace (uppercase first letter)
    if (_isNamespace(name)) {
      return _generateNamespaceLayout(projectDir, name.toLowerCase(), force);
    }

    // Standard shared layout
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

  /// Generate a namespace layout (e.g. lib/admin/layouts/default.dart).
  /// This layout auto-wraps all routes in the namespace.
  Future<int> _generateNamespaceLayout(String projectDir, String namespace, bool force) async {
    final filePath = p.join(projectDir, 'lib', namespace, 'layouts', 'default.dart');
    final file = File(filePath);

    if (file.existsSync() && !force) {
      print('Error: Namespace layout already exists. Use --force to overwrite.');
      return 1;
    }

    await file.parent.create(recursive: true);

    final className = '${_toPascalCase(namespace)}Layout';
    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

/// Layout for the $namespace namespace.
/// All routes under /$namespace/* are automatically wrapped with this layout.
class $className extends StatelessComponent {
  final Component child;

  const $className({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen', [
      // ${_toPascalCase(namespace)} Header
      header(classes: 'bg-gray-900 border-b border-gray-700', [
        div(classes: 'max-w-7xl mx-auto px-4 py-3 flex items-center justify-between', [
          a(href: '/$namespace', classes: 'text-white font-semibold text-lg', [
            text('${_toPascalCase(namespace)}'),
          ]),
          nav(classes: 'flex gap-4', [
            // Add navigation links here
          ]),
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

    print('\x1B[32m✓\x1B[0m Generated namespace layout: lib/$namespace/layouts/default.dart');
    print('  All /$namespace/* routes will be wrapped with ${className}.');
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

  String _buildApiContent(String className, String apiPath, List<FieldDef> fields) {
    return '''
import 'package:duxt/duxt.dart';
import 'model.dart';

/// API calls for $apiPath
class ${className}Api {
  static Future<List<$className>> getAll() async {
    final data = await Api.get('/$apiPath');
    return $className.fromList(data as List);
  }

  static Future<$className> getOne(String id) async {
    final data = await Api.get('/$apiPath/\$id');
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<$className> create($className item) async {
    final data = await Api.post('/$apiPath', body: item.toJson());
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<$className> update(String id, $className item) async {
    final data = await Api.put('/$apiPath/\$id', body: item.toJson());
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await Api.delete('/$apiPath/\$id');
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

  void _printRouteHint(String namespace, String module, String name, String className, List<String> routeParams) {
    print('');

    // Build route path
    String routePrefix;
    if (namespace == 'theme') {
      routePrefix = module == 'home' ? '' : '/$module';
    } else if (namespace.isNotEmpty) {
      routePrefix = '/$namespace/$module';
    } else {
      routePrefix = '/$module';
    }

    final routePath = '$routePrefix${name == 'index' ? '' : '/$name'}'
        .replaceAllMapped(RegExp(r'\[\.\.\.(\w+)\]'), (m) => '*')
        .replaceAllMapped(RegExp(r'\[(\w+)\]'), (m) => ':${m.group(1)}');

    final effectivePath = routePath.isEmpty ? '/' : routePath;

    print('Route: $effectivePath → $className');
    if (routeParams.isNotEmpty) {
      print('  Params: ${routeParams.join(', ')}');
    }
  }
}

class FieldDef {
  final String name;
  final String type;
  FieldDef({required this.name, required this.type});
}
