import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Scaffold command - generates full module with CRUD
/// Usage: duxt scaffold <name> [field:type ...]
///
/// Example: duxt scaffold posts title:String content:String author:String
///
/// Generates:
/// lib/posts/
///   pages/
///     index.dart     (list page)
///     _id_.dart      (detail page)
///     new.dart       (create page)
///   components/
///     post_card.dart
///     post_form.dart
///   model.dart
///   api.dart
class ScaffoldCommand extends Command<int> {
  @override
  final name = 'scaffold';

  @override
  final description = 'Generate full module with CRUD (pages, components, model, api)';

  @override
  String get invocation => 'duxt scaffold <name> [field:type ...]';

  ScaffoldCommand() {
    argParser.addFlag('force', abbr: 'f', help: 'Overwrite existing files');
    argParser.addFlag('api-only', help: 'Only generate model and API');
    argParser.addFlag('orm', help: 'Generate DuxtOrm server model with schema');
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      print('Error: Please specify a module name');
      print('Usage: duxt scaffold <name> [field:type ...]');
      print('');
      print('Example:');
      print('  duxt scaffold posts title:String content:String');
      return 1;
    }

    final moduleName = argResults!.rest[0].toLowerCase();
    final fields = _parseFields(argResults!.rest.skip(1).toList());
    final force = argResults!['force'] as bool;
    final apiOnly = argResults!['api-only'] as bool;
    final useOrm = argResults!['orm'] as bool;
    final projectDir = Directory.current.path;

    print('');
    print('\x1B[36mScaffolding $moduleName module...\x1B[0m');
    print('');

    final className = _toPascalCase(moduleName);
    final singular = _singularize(moduleName);
    final singularClass = _toPascalCase(singular);

    try {
      // Create module directories
      final moduleDir = p.join(projectDir, 'lib', moduleName);

      // Check if module exists
      if (Directory(moduleDir).existsSync() && !force) {
        print('\x1B[31m✗\x1B[0m Module "$moduleName" already exists. Use --force to overwrite.');
        return 1;
      }

      await Directory(p.join(moduleDir, 'pages')).create(recursive: true);
      await Directory(p.join(moduleDir, 'components')).create(recursive: true);

      // 1. Generate Model
      await _generateModel(moduleDir, singularClass, fields);
      print('  \x1B[32m✓\x1B[0m model.dart');

      // 2. Generate API
      await _generateApi(moduleDir, singularClass, moduleName);
      print('  \x1B[32m✓\x1B[0m api.dart');

      // 2b. Generate ORM Model (server-side)
      if (useOrm) {
        final serverDir = p.join(projectDir, 'server', 'models');
        await Directory(serverDir).create(recursive: true);
        await _generateOrmModel(serverDir, singularClass, moduleName, fields);
        print('  \x1B[32m✓\x1B[0m server/models/${singular}.dart (DuxtOrm)');

        // Generate server routes
        final routesDir = p.join(projectDir, 'server', 'api');
        await Directory(routesDir).create(recursive: true);
        await _generateOrmRoutes(routesDir, singularClass, moduleName, singular, fields);
        print('  \x1B[32m✓\x1B[0m server/api/$moduleName.dart (routes)');
      }

      if (!apiOnly) {
        // 3. Generate List Page
        await _generateListPage(moduleDir, moduleName, singularClass, fields);
        print('  \x1B[32m✓\x1B[0m pages/index.dart');

        // 4. Generate Detail Page
        await _generateDetailPage(moduleDir, moduleName, singularClass, fields);
        print('  \x1B[32m✓\x1B[0m pages/_id_.dart');

        // 5. Generate New Page
        await _generateNewPage(moduleDir, moduleName, singularClass, fields);
        print('  \x1B[32m✓\x1B[0m pages/new.dart');

        // 6. Generate Card Component
        await _generateCard(moduleDir, singular, singularClass, fields);
        print('  \x1B[32m✓\x1B[0m components/${singular}_card.dart');

        // 7. Generate Form Component
        await _generateForm(moduleDir, singular, singularClass, fields);
        print('  \x1B[32m✓\x1B[0m components/${singular}_form.dart');
      }

      print('');
      print('\x1B[32m✓ Scaffold complete!\x1B[0m');
      print('');
      print('Add routes to lib/app.dart:');
      print('');
      print('  // $className module');
      print('  Route(');
      print("    path: '/$moduleName',");
      print('    builder: (_, __) => const ${className}ListPage(),');
      print('  ),');
      print('  Route(');
      print("    path: '/$moduleName/new',");
      print('    builder: (_, __) => const ${className}NewPage(),');
      print('  ),');
      print('  Route(');
      print("    path: '/$moduleName/:id',");
      print("    builder: (_, state) => ${className}DetailPage(id: state.params['id']!),");
      print('  ),');

      return 0;
    } catch (e) {
      print('\x1B[31m✗ Error: $e\x1B[0m');
      return 1;
    }
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
      default:
        return type;
    }
  }

  Future<void> _generateModel(String moduleDir, String className, List<FieldDef> fields) async {
    final allFields = [FieldDef(name: 'id', type: 'String'), ...fields];

    final paramFields = allFields.map((f) => '  final ${f.type}${f.name == 'id' ? '' : '?'} ${f.name};').join('\n');
    final constructorParams = allFields.map((f) =>
      f.name == 'id' ? 'required this.id' : 'this.${f.name}').join(', ');
    final fromJsonFields = allFields.map((f) {
      if (f.name == 'id') {
        return "      id: json['id'].toString(),";
      }
      return "      ${f.name}: json['${f.name}'] as ${f.type}?,";
    }).join('\n');
    final toJsonFields = allFields.map((f) =>
      "      '${f.name}': ${f.name},").join('\n');

    final content = '''
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

  $className copyWith({
${allFields.map((f) => '    ${f.type}? ${f.name},').join('\n')}
  }) {
    return $className(
${allFields.map((f) => '      ${f.name}: ${f.name} ?? this.${f.name},').join('\n')}
    );
  }
}
''';
    await File(p.join(moduleDir, 'model.dart')).writeAsString(content);
  }

  Future<void> _generateApi(String moduleDir, String className, String moduleName) async {
    final content = '''
import 'package:duxt/duxt.dart';
import 'model.dart';

/// API calls for $moduleName
class ${className}Api {
  static Future<List<$className>> getAll() async {
    final data = await Api.get('/$moduleName');
    final list = data is Map ? data['$moduleName'] as List : data as List;
    return $className.fromList(list);
  }

  static Future<$className> getOne(String id) async {
    final data = await Api.get('/$moduleName/\$id');
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<$className> create($className item) async {
    final data = await Api.post('/$moduleName', body: item.toJson());
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<$className> update(String id, $className item) async {
    final data = await Api.put('/$moduleName/\$id', body: item.toJson());
    return $className.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await Api.delete('/$moduleName/\$id');
  }
}
''';
    await File(p.join(moduleDir, 'api.dart')).writeAsString(content);
  }

  Future<void> _generateListPage(String moduleDir, String moduleName, String className, List<FieldDef> fields) async {
    final pluralClass = _toPascalCase(moduleName);
    final singular = _singularize(moduleName);

    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt/duxt.dart';
import '../model.dart';
import '../api.dart';
import '../components/${singular}_card.dart';

class ${pluralClass}ListPage extends StatefulComponent {
  const ${pluralClass}ListPage({super.key});

  @override
  State createState() => _${pluralClass}ListPageState();
}

class _${pluralClass}ListPageState extends DuxtState<${pluralClass}ListPage, List<$className>> {
  @override
  Future<List<$className>> load() => ${className}Api.getAll();

  @override
  Component buildLoading() {
    return div(classes: 'flex justify-center py-12', [
      text('Loading...'),
    ]);
  }

  @override
  Component buildError(Object error) {
    return div(classes: 'text-red-600 py-12', [
      text('Error: \$error'),
    ]);
  }

  @override
  Component buildData(List<$className> items) {
    return div(classes: 'space-y-6', [
      // Header
      div(classes: 'flex justify-between items-center', [
        h1(classes: 'text-3xl font-bold text-gray-900', [
          text('$pluralClass'),
        ]),
        a(
          href: '/$moduleName/new',
          classes: 'px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700',
          [Component.text('New $className')],
        ),
      ]),
      // List
      if (items.isEmpty)
        div(classes: 'text-center py-12 text-gray-500', [
          text('No $moduleName yet'),
        ])
      else
        div(classes: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6', [
          for (final item in items)
            ${className}Card(item: item),
        ]),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', 'index.dart')).writeAsString(content);
  }

  Future<void> _generateDetailPage(String moduleDir, String moduleName, String className, List<FieldDef> fields) async {
    final pluralClass = _toPascalCase(moduleName);

    final fieldDisplays = fields.map((f) => '''
          div(classes: 'py-4 border-b', [
            dt(classes: 'text-sm text-gray-500', [Component.text('${_toTitleCase(f.name)}')]),
            dd(classes: 'mt-1 text-gray-900', [Component.text('\${item.${f.name} ?? "-"}')]),
          ]),''').join('\n');

    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt/duxt.dart';
import '../model.dart';
import '../api.dart';

class ${pluralClass}DetailPage extends StatefulComponent {
  final String id;

  const ${pluralClass}DetailPage({super.key, required this.id});

  @override
  State createState() => _${pluralClass}DetailPageState();
}

class _${pluralClass}DetailPageState extends DuxtState<${pluralClass}DetailPage, $className> {
  @override
  Future<$className> load() => ${className}Api.getOne(component.id);

  @override
  Component buildLoading() {
    return div(classes: 'flex justify-center py-12', [Component.text('Loading...')]);
  }

  @override
  Component buildError(Object error) {
    return div(classes: 'text-red-600 py-12', [Component.text('Error: \$error')]);
  }

  @override
  Component buildData($className item) {
    return div(classes: 'max-w-2xl mx-auto', [
      // Header
      div(classes: 'flex justify-between items-center mb-8', [
        h1(classes: 'text-3xl font-bold text-gray-900', [
          text('$className Details'),
        ]),
        div(classes: 'flex gap-2', [
          a(
            href: '/$moduleName',
            classes: 'px-4 py-2 border rounded-lg hover:bg-gray-50',
            [Component.text('Back')],
          ),
        ]),
      ]),
      // Details
      dl(classes: 'divide-y', [
        div(classes: 'py-4 border-b', [
          dt(classes: 'text-sm text-gray-500', [Component.text('ID')]),
          dd(classes: 'mt-1 text-gray-900', [Component.text(item.id)]),
        ]),
$fieldDisplays
      ]),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', '_id_.dart')).writeAsString(content);
  }

  Future<void> _generateNewPage(String moduleDir, String moduleName, String className, List<FieldDef> fields) async {
    final pluralClass = _toPascalCase(moduleName);
    final singular = _singularize(moduleName);

    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../components/${singular}_form.dart';

class ${pluralClass}NewPage extends StatelessComponent {
  const ${pluralClass}NewPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'max-w-2xl mx-auto', [
      // Header
      div(classes: 'flex justify-between items-center mb-8', [
        h1(classes: 'text-3xl font-bold text-gray-900', [
          text('New $className'),
        ]),
        a(
          href: '/$moduleName',
          classes: 'px-4 py-2 border rounded-lg hover:bg-gray-50',
          [Component.text('Cancel')],
        ),
      ]),
      // Form
      ${className}Form(),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', 'new.dart')).writeAsString(content);
  }

  Future<void> _generateCard(String moduleDir, String singular, String className, List<FieldDef> fields) async {
    final displayField = fields.isNotEmpty ? fields.first.name : 'id';

    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../model.dart';

class ${className}Card extends StatelessComponent {
  final $className item;

  const ${className}Card({super.key, required this.item});

  @override
  Component build(BuildContext context) {
    return a(
      href: '/${_pluralize(singular)}/\${item.id}',
      classes: 'block p-6 bg-white rounded-lg shadow-sm border hover:shadow-md transition-shadow',
      [
        h3(classes: 'text-lg font-semibold text-gray-900', [
          text('\${item.$displayField ?? "Untitled"}'),
        ]),
        p(classes: 'text-sm text-gray-500 mt-1', [
          text('ID: \${item.id}'),
        ]),
      ],
    );
  }
}
''';
    await File(p.join(moduleDir, 'components', '${singular}_card.dart')).writeAsString(content);
  }

  Future<void> _generateForm(String moduleDir, String singular, String className, List<FieldDef> fields) async {
    final inputFields = fields.map((f) => '''
        div(classes: 'space-y-1', [
          label(classes: 'block text-sm font-medium text-gray-700', [
            text('${_toTitleCase(f.name)}'),
          ]),
          input(
            type: InputType.text,
            name: '${f.name}',
            classes: 'w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500',
          ),
        ]),''').join('\n');

    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class ${className}Form extends StatelessComponent {
  const ${className}Form({super.key});

  @override
  Component build(BuildContext context) {
    return form(
      classes: 'space-y-6',
      [
$inputFields
        // Submit
        div(classes: 'flex justify-end', [
          button(
            type: ButtonType.submit,
            classes: 'px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700',
            [Component.text('Save')],
          ),
        ]),
      ],
    );
  }
}
''';
    await File(p.join(moduleDir, 'components', '${singular}_form.dart')).writeAsString(content);
  }

  // ==================== ORM Model Generation ====================

  Future<void> _generateOrmModel(String serverDir, String className, String moduleName, List<FieldDef> fields) async {
    final singular = _singularize(moduleName);

    // Build field declarations
    final fieldDeclarations = fields.map((f) =>
      '  ${f.type}? ${f.name};').join('\n');

    // Build constructor params
    final constructorParams = [
      'int? id',
      ...fields.map((f) => 'this.${f.name}'),
      'this.createdAt',
      'this.updatedAt',
    ].join(', ');

    // Build toMap
    final toMapFields = fields.map((f) {
      if (f.type == 'bool') {
        return "      '${_toSnakeCase(f.name)}': ${f.name} == true ? 1 : 0,";
      }
      return "      '${_toSnakeCase(f.name)}': ${f.name},";
    }).join('\n');

    // Build fromRow
    final fromRowFields = fields.map((f) {
      final snakeName = _toSnakeCase(f.name);
      if (f.type == 'bool') {
        return "      ${f.name}: (row['$snakeName'] as int?) == 1,";
      } else if (f.type == 'int') {
        return "      ${f.name}: row['$snakeName'] as int?,";
      } else if (f.type == 'double') {
        return "      ${f.name}: (row['$snakeName'] as num?)?.toDouble(),";
      }
      return "      ${f.name}: row['$snakeName'] as ${f.type}?,";
    }).join('\n');

    // Build schema columns
    final schemaColumns = fields.map((f) {
      final snakeName = _toSnakeCase(f.name);
      final colType = _dartTypeToColumn(f.type);
      return "        '$snakeName': $colType,";
    }).join('\n');

    final content = '''
import 'package:duxt_orm/duxt_orm.dart';

class $className extends Model {
  int? _id;
$fieldDeclarations
  DateTime? createdAt;
  DateTime? updatedAt;

  $className({$constructorParams}) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

  @override
  Map<String, dynamic> toMap() => {
$toMapFields
    };

  factory $className.fromRow(Map<String, dynamic> row) => $className(
      id: row['id'] as int?,
$fromRowFields
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );

  Map<String, dynamic> toJson() => {
      'id': _id,
${fields.map((f) => "      '${f.name}': ${f.name},").join('\n')}
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };

  /// Register this model with DuxtOrm.
  static void register() {
    Model.registerModel<$className>(
      $className.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
$schemaColumns
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );
  }

  @override
  String toString() => '$className(id: \$_id${fields.isNotEmpty ? ', ${fields.first.name}: \$${fields.first.name}' : ''})';
}
''';
    await File(p.join(serverDir, '$singular.dart')).writeAsString(content);
  }

  Future<void> _generateOrmRoutes(String routesDir, String className, String moduleName, String singular, List<FieldDef> fields) async {
    final content = '''
import 'package:duxt/server.dart';
import 'package:duxt_orm/duxt_orm.dart';
import '../models/$singular.dart';

/// Register $moduleName API routes
void register${className}Routes(DuxtServer server) {
  // GET /api/$moduleName - List all
  server.get('/api/$moduleName', (req) async {
    final items = await Model.all<$className>();
    return json({'$moduleName': items.map((e) => e.toJson()).toList()});
  });

  // GET /api/$moduleName/:id - Get one
  server.get('/api/$moduleName/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) {
      return json({'error': 'Invalid ID'}, statusCode: 400);
    }

    final item = await Model.find<$className>(id);
    if (item == null) {
      return json({'error': 'Not found'}, statusCode: 404);
    }

    return json({'$singular': item.toJson()});
  });

  // POST /api/$moduleName - Create
  server.post('/api/$moduleName', (req) async {
    final body = req.body as Map<String, dynamic>?;
    if (body == null) {
      return json({'error': 'Body required'}, statusCode: 400);
    }

    final item = $className.fromRow(body);
    await item.save();

    return json({'$singular': item.toJson()}, statusCode: 201);
  });

  // PUT /api/$moduleName/:id - Update
  server.put('/api/$moduleName/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) {
      return json({'error': 'Invalid ID'}, statusCode: 400);
    }

    final item = await Model.find<$className>(id);
    if (item == null) {
      return json({'error': 'Not found'}, statusCode: 404);
    }

    final body = req.body as Map<String, dynamic>?;
    if (body != null) {
${fields.map((f) => "      if (body.containsKey('${f.name}')) item.${f.name} = body['${f.name}'] as ${f.type}?;").join('\n')}
    }

    await item.save();
    return json({'$singular': item.toJson()});
  });

  // DELETE /api/$moduleName/:id - Delete
  server.delete('/api/$moduleName/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) {
      return json({'error': 'Invalid ID'}, statusCode: 400);
    }

    final item = await Model.find<$className>(id);
    if (item == null) {
      return json({'error': 'Not found'}, statusCode: 404);
    }

    await item.destroy();
    return json({'success': true});
  });
}
''';
    await File(p.join(routesDir, '$moduleName.dart')).writeAsString(content);
  }

  String _dartTypeToColumn(String dartType) {
    switch (dartType) {
      case 'int':
        return 'Column.integer().nullable()';
      case 'double':
        return 'Column.decimal(10, 2).nullable()';
      case 'bool':
        return 'Column.boolean().defaultValue(false)';
      case 'String':
      default:
        return 'Column.string(255).nullable()';
    }
  }

  String _toSnakeCase(String s) {
    return s.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => '_${m.group(1)!.toLowerCase()}',
    );
  }

  // Helpers

  String _toPascalCase(String s) {
    if (s.isEmpty) return s;
    return s.split(RegExp(r'[_-]'))
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join('');
  }

  String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAllMapped(
      RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}');
  }

  String _singularize(String s) {
    if (s.endsWith('ies')) return '${s.substring(0, s.length - 3)}y';
    if (s.endsWith('es')) return s.substring(0, s.length - 2);
    if (s.endsWith('s')) return s.substring(0, s.length - 1);
    return s;
  }

  String _pluralize(String s) {
    if (s.endsWith('y')) return '${s.substring(0, s.length - 1)}ies';
    if (s.endsWith('s') || s.endsWith('x') || s.endsWith('ch') || s.endsWith('sh')) {
      return '${s}es';
    }
    return '${s}s';
  }
}

class FieldDef {
  final String name;
  final String type;
  FieldDef({required this.name, required this.type});
}
