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
    argParser.addFlag('api', defaultsTo: true,
      help: 'Generate REST API endpoints (use --no-api for SSR-only models)');
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
    final generateApi = argResults!['api'] as bool;
    final projectDir = Directory.current.path;

    // Get package name from pubspec.yaml
    final pubspecFile = File(p.join(projectDir, 'pubspec.yaml'));
    String packageName = 'app';
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
      if (match != null) packageName = match.group(1)!;
    }

    // Extract relation fields
    final belongsToFields = fields.where((f) => f.isBelongsTo).toList();
    final toManyFields = fields.where((f) => f.isToMany).toList();

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
        // Generate model in lib/models/ for SSR access
        final modelsDir = p.join(projectDir, 'lib', 'models');
        await Directory(modelsDir).create(recursive: true);
        await _generateOrmModel(modelsDir, singularClass, moduleName, fields, belongsToFields, toManyFields);
        print('  \x1B[32m✓\x1B[0m lib/models/${singular}.dart (DuxtOrm)');

        // Generate pivot tables for toMany relations
        for (final rel in toManyFields) {
          final pivotTable = '${singular}_${_singularize(rel.name).toLowerCase()}s';
          print('  \x1B[32m✓\x1B[0m Pivot table: $pivotTable');
        }

        // Generate server routes (only if --api is true)
        if (generateApi) {
          final routesDir = p.join(projectDir, 'server', 'api');
          await Directory(routesDir).create(recursive: true);
          await _generateOrmRoutes(routesDir, singularClass, moduleName, singular, fields, packageName);
          print('  \x1B[32m✓\x1B[0m server/api/$moduleName.dart (routes)');
        } else {
          print('  \x1B[90m-\x1B[0m API routes skipped (--no-api)');
        }
      }

      if (!apiOnly) {
        // 3. Generate List Page (with Create modal)
        await _generateListPage(moduleDir, moduleName, singularClass, fields, packageName);
        print('  \x1B[32m✓\x1B[0m pages/index.dart (with create modal)');

        // 4. Generate Detail Page (with Edit modal)
        await _generateDetailPage(moduleDir, moduleName, singularClass, fields, packageName);
        print('  \x1B[32m✓\x1B[0m pages/_id_.dart (with edit modal)');

        // 5. Generate Card Component
        await _generateCard(moduleDir, singular, singularClass, fields, packageName);
        print('  \x1B[32m✓\x1B[0m components/${singular}_card.dart');

        // 6. Generate Form Component
        await _generateForm(moduleDir, singular, singularClass, fields);
        print('  \x1B[32m✓\x1B[0m components/${singular}_form.dart');
      }

      // 8. Try to add nav link
      await _addNavLink(projectDir, moduleName, className);

      print('');
      print('\x1B[32m✓ Scaffold complete!\x1B[0m');
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
        final name = parts[0];
        final typeOrRelation = parts[1].toLowerCase();

        // Check for relation syntax: field:belongsTo:Model or field:toMany:Model
        if (typeOrRelation == 'belongsto' && parts.length >= 3) {
          fields.add(FieldDef(
            name: name,
            type: 'int', // Foreign key is int
            isRelation: true,
            relationType: 'belongsTo',
            relatedModel: parts[2],
          ));
        } else if (typeOrRelation == 'tomany' && parts.length >= 3) {
          fields.add(FieldDef(
            name: name,
            type: 'List<${parts[2]}>',
            isRelation: true,
            relationType: 'toMany',
            relatedModel: parts[2],
          ));
        } else {
          fields.add(FieldDef(name: name, type: _normalizeType(parts[1])));
        }
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
      case 'text':
        return 'String'; // Long text
      case 'email':
        return 'String'; // Email (validated in UI)
      case 'image':
        return 'String?'; // Image URL/path
      case 'attachment':
        return 'String?'; // File attachment URL/path
      case 'datetime':
      case 'date':
        return 'DateTime?';
      default:
        return type;
    }
  }

  Future<void> _generateModel(String moduleDir, String className, List<FieldDef> fields) async {
    final allFields = [FieldDef(name: 'id', type: 'String'), ...fields];

    // Helper to add ? only if not already nullable
    String makeNullable(String type) => type.endsWith('?') ? type : '$type?';

    // Helper to get client-side type (toMany relations use List<dynamic>)
    String getClientType(FieldDef f) {
      if (f.isToMany) return 'List<dynamic>';
      return f.type;
    }

    final paramFields = allFields.map((f) {
      final type = getClientType(f);
      return '  final ${f.name == 'id' ? type : makeNullable(type)} ${f.name};';
    }).join('\n');
    final constructorParams = allFields.map((f) =>
      f.name == 'id' ? 'required this.id' : 'this.${f.name}').join(', ');
    final fromJsonFields = allFields.map((f) {
      if (f.name == 'id') {
        return "      id: json['id'].toString(),";
      }
      final type = getClientType(f);
      return "      ${f.name}: json['${f.name}'] as ${makeNullable(type)},";
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
${allFields.map((f) => '    ${makeNullable(getClientType(f))} ${f.name},').join('\n')}
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

  Future<void> _generateListPage(String moduleDir, String moduleName, String className, List<FieldDef> fields, String packageName) async {
    final pluralClass = _toPascalCase(moduleName);
    final singular = _singularize(moduleName);

    // Build form data object from non-relation fields
    final formFields = fields.where((f) => !f.isRelation).toList();
    final dataFields = formFields.map((f) => '            ${f.name}: form.${f.name}.value').join(',\n');

    final content = '''
import 'package:jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:duxt_ui/duxt_ui.dart';
import 'package:$packageName/models/$singular.dart';
import '../components/${singular}_card.dart';
import '../components/${singular}_form.dart';

/// ${pluralClass} list page - SSR with AsyncStatelessComponent
class ${pluralClass}ListPage extends AsyncStatelessComponent {
  const ${pluralClass}ListPage({super.key});

  @override
  Future<Component> build(BuildContext context) async {
    // Load data from database (SSR)
    final items = await Model<$className>().all();

    return div(classes: 'space-y-6', [
      // Header
      div(classes: 'flex justify-between items-center', [
        h1(classes: 'text-3xl font-bold text-white', [
          Component.text('$pluralClass'),
        ]),
        // Create Modal with DModal component
        DModal(
          trigger: span(
            classes: 'px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700',
            [Component.text('New $className')],
          ),
          title: 'New $className',
          size: DModalSize.lg,
          children: [
            ${className}Form(),
          ],
        ),
      ]),
      // List
      if (items.isEmpty)
        div(classes: 'text-center py-12 text-gray-500', [
          Component.text('No $moduleName yet'),
        ])
      else
        div(classes: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6', [
          for (final item in items)
            ${className}Card(item: item),
        ]),

      // Form submission script
      RawText(\'''<script>
        function submit${className}Form(e) {
          e.preventDefault();
          var form = document.getElementById('$singular-form');
          var data = {
$dataFields
          };
          fetch('/api/$moduleName', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data)
          }).then(function(r) { return r.json(); }).then(function() {
            window.location.reload();
          }).catch(function(err) { alert('Error: ' + err); });
          return false;
        }
      </script>\'''),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', 'index.dart')).writeAsString(content);
  }

  Future<void> _generateDetailPage(String moduleDir, String moduleName, String className, List<FieldDef> fields, String packageName) async {
    final pluralClass = _toPascalCase(moduleName);
    final singular = _singularize(moduleName);

    final fieldDisplays = fields.where((f) => !f.isRelation).map((f) => '''
          div(classes: 'py-4 border-b border-gray-700', [
            dt(classes: 'text-sm text-gray-400', [Component.text('${_toTitleCase(f.name)}')]),
            dd(classes: 'mt-1 text-white', [Component.text('\${item.${f.name} ?? "-"}')]),
          ]),''').join('\n');

    // Build form data object from non-relation fields
    final formFields = fields.where((f) => !f.isRelation).toList();
    final dataFields = formFields.map((f) => '            ${f.name}: form.${f.name}.value').join(',\n');
    final valueSetters = formFields.map((f) => "          form.${f.name}.value = '\${_escapeJs(item.${f.name}?.toString() ?? '')}';").join('\n');

    final content = '''
import 'package:jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:duxt_ui/duxt_ui.dart';
import 'package:$packageName/models/$singular.dart';
import '../components/${singular}_form.dart';

String _escapeJs(String s) => s.replaceAll("'", "\\\\'").replaceAll('\\n', '\\\\n');

/// ${className} detail page - SSR with AsyncStatelessComponent
class ${pluralClass}DetailPage extends AsyncStatelessComponent {
  final String id;

  const ${pluralClass}DetailPage({super.key, required this.id});

  @override
  Future<Component> build(BuildContext context) async {
    final itemId = int.tryParse(id);
    if (itemId == null) {
      return div(classes: 'text-red-400 py-12', [Component.text('Invalid ID')]);
    }

    final item = await Model<$className>().find(itemId);
    if (item == null) {
      return div(classes: 'text-red-400 py-12', [Component.text('$className not found')]);
    }

    return div(classes: 'max-w-2xl mx-auto', [
      // Header
      div(classes: 'flex justify-between items-center mb-8', [
        h1(classes: 'text-3xl font-bold text-white', [
          Component.text('$className Details'),
        ]),
        div(classes: 'flex gap-2', [
          // Edit Modal with DModal component
          DModal(
            trigger: span(
              classes: 'px-4 py-2 bg-cyan-600 rounded-lg hover:bg-cyan-700 text-white cursor-pointer',
              [Component.text('Edit')],
            ),
            title: 'Edit $className',
            size: DModalSize.lg,
            children: [
              ${className}Form(),
            ],
          ),
          button(
            id: 'delete-btn',
            classes: 'px-4 py-2 bg-red-600 rounded-lg hover:bg-red-700 text-white',
            [Component.text('Delete')],
          ),
          a(
            href: '/$moduleName',
            classes: 'px-4 py-2 border border-gray-600 rounded-lg hover:bg-gray-800 text-white',
            [Component.text('Back')],
          ),
        ]),
      ]),
      // Details
      dl(classes: 'divide-y divide-gray-700', [
        div(classes: 'py-4 border-b border-gray-700', [
          dt(classes: 'text-sm text-gray-400', [Component.text('ID')]),
          dd(classes: 'mt-1 text-white', [Component.text('\${item.id}')]),
        ]),
$fieldDisplays
      ]),

      // Scripts
      RawText(\'''<script>
        // Pre-populate form with current values
        (function() {
          var form = document.getElementById('$singular-form');
          if (form) {
$valueSetters
          }
        })();

        // Delete handler
        document.getElementById('delete-btn').addEventListener('click', function() {
          if (confirm('Are you sure you want to delete this $singular?')) {
            fetch('/api/$moduleName/\${item.id}', {
              method: 'DELETE'
            }).then(function() {
              window.location.href = '/$moduleName';
            }).catch(function(err) { alert('Error: ' + err); });
          }
        });

        // Form submission (update)
        function submit${className}Form(e) {
          e.preventDefault();
          var form = document.getElementById('$singular-form');
          var data = {
$dataFields
          };
          fetch('/api/$moduleName/\${item.id}', {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data)
          }).then(function(r) { return r.json(); }).then(function() {
            window.location.reload();
          }).catch(function(err) { alert('Error: ' + err); });
          return false;
        }
      </script>\'''),
    ]);
  }
}
''';
    await File(p.join(moduleDir, 'pages', '_id_.dart')).writeAsString(content);
  }

  Future<void> _generateCard(String moduleDir, String singular, String className, List<FieldDef> fields, String packageName) async {
    final displayField = fields.where((f) => !f.isRelation).isNotEmpty
        ? fields.where((f) => !f.isRelation).first.name
        : 'id';

    final content = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:$packageName/models/$singular.dart';

class ${className}Card extends StatelessComponent {
  final $className item;

  const ${className}Card({super.key, required this.item});

  @override
  Component build(BuildContext context) {
    return a(
      href: '/${_pluralize(singular)}/\${item.id}',
      classes: 'block p-6 bg-gray-800/50 rounded-lg border border-gray-700 hover:border-cyan-500/50 transition-colors',
      [
        h3(classes: 'text-lg font-semibold text-white', [
          Component.text('\${item.$displayField ?? "Untitled"}'),
        ]),
        p(classes: 'text-sm text-gray-400 mt-1', [
          Component.text('ID: \${item.id}'),
        ]),
      ],
    );
  }
}
''';
    await File(p.join(moduleDir, 'components', '${singular}_card.dart')).writeAsString(content);
  }

  Future<void> _generateForm(String moduleDir, String singular, String className, List<FieldDef> fields) async {
    // Only include non-relation fields in form
    final formFields = fields.where((f) => !f.isRelation).toList();
    final inputFields = formFields.map((f) => '''
        div(classes: 'space-y-1', [
          label(classes: 'block text-sm font-medium text-gray-300', [
            Component.text('${_toTitleCase(f.name)}'),
          ]),
          input(
            type: InputType.text,
            name: '${f.name}',
            classes: 'w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500',
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
      id: '${singular}-form',
      classes: 'space-y-6',
      attributes: {'onsubmit': 'return submit${className}Form(event)'},
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

  Future<void> _generateOrmModel(
    String modelsDir,
    String className,
    String moduleName,
    List<FieldDef> allFields,
    List<FieldDef> belongsToFields,
    List<FieldDef> toManyFields,
  ) async {
    final singular = _singularize(moduleName);

    // Filter out relation fields for regular field handling
    final regularFields = allFields.where((f) => !f.isRelation).toList();

    // Build field declarations (regular fields + belongsTo foreign keys)
    final fieldDecls = <String>[];
    for (final f in regularFields) {
      fieldDecls.add('  ${f.type}${f.type.endsWith('?') ? '' : '?'} ${f.name};');
    }
    for (final f in belongsToFields) {
      fieldDecls.add('  int? ${f.foreignKey};'); // Foreign key column
    }
    final fieldDeclarations = fieldDecls.join('\n');

    // Build constructor params
    final constructorParams = <String>['int? id'];
    for (final f in regularFields) {
      constructorParams.add('this.${f.name}');
    }
    for (final f in belongsToFields) {
      constructorParams.add('this.${f.foreignKey}');
    }
    constructorParams.addAll(['this.createdAt', 'this.updatedAt']);

    // Build toMap (regular + foreign keys)
    final toMapLines = <String>[];
    for (final f in regularFields) {
      final snakeName = _toSnakeCase(f.name);
      if (f.type == 'bool') {
        toMapLines.add("      '$snakeName': ${f.name} == true ? 1 : 0,");
      } else {
        toMapLines.add("      '$snakeName': ${f.name},");
      }
    }
    for (final f in belongsToFields) {
      toMapLines.add("      '${f.foreignKey}': ${f.foreignKey},");
    }
    final toMapFields = toMapLines.join('\n');

    // Build fromRow
    final fromRowLines = <String>[];
    for (final f in regularFields) {
      final snakeName = _toSnakeCase(f.name);
      if (f.type == 'bool') {
        fromRowLines.add("      ${f.name}: (row['$snakeName'] as int?) == 1,");
      } else if (f.type == 'int') {
        fromRowLines.add("      ${f.name}: row['$snakeName'] as int?,");
      } else if (f.type == 'double') {
        fromRowLines.add("      ${f.name}: (row['$snakeName'] as num?)?.toDouble(),");
      } else if (f.type == 'DateTime?') {
        fromRowLines.add("      ${f.name}: row['$snakeName'] != null ? DateTime.tryParse(row['$snakeName'] as String) : null,");
      } else {
        final castType = f.type.endsWith('?') ? f.type : '${f.type}?';
        fromRowLines.add("      ${f.name}: row['$snakeName'] as $castType,");
      }
    }
    for (final f in belongsToFields) {
      fromRowLines.add("      ${f.foreignKey}: row['${f.foreignKey}'] as int?,");
    }
    final fromRowFields = fromRowLines.join('\n');

    // Build schema columns
    final schemaLines = <String>[];
    for (final f in regularFields) {
      final snakeName = _toSnakeCase(f.name);
      final colType = _dartTypeToColumn(f.type);
      schemaLines.add("        '$snakeName': $colType,");
    }
    for (final f in belongsToFields) {
      final relatedTable = _pluralize(_singularize(f.relatedModel!).toLowerCase());
      schemaLines.add("        '${f.foreignKey}': Column.integer().nullable().references('$relatedTable'),");
    }
    final schemaColumns = schemaLines.join('\n');

    // Build relation accessors
    final relationAccessors = <String>[];
    for (final f in belongsToFields) {
      relationAccessors.add("  /// Get the related ${f.relatedModel} (use .with_(['${f.name}']) to load)");
      relationAccessors.add("  ${f.relatedModel}? get ${f.name} => getRelation<${f.relatedModel}>('${f.name}');");
    }
    for (final f in toManyFields) {
      relationAccessors.add("  /// Get related ${f.relatedModel} list (use .with_(['${f.name}']) to load)");
      relationAccessors.add("  List<${f.relatedModel}> get ${f.name} => getRelation<List<${f.relatedModel}>>('${f.name}') ?? [];");
    }
    final relationAccessorsCode = relationAccessors.join('\n');

    // Build relation registrations
    final relationRegs = <String>[];
    for (final f in belongsToFields) {
      relationRegs.add('''
    Entity.registerRelation<$className>(
      '${f.name}',
      BelongsTo<${f.relatedModel}>(foreignKey: '${f.foreignKey}'),
    );''');
    }
    for (final f in toManyFields) {
      final pivotTable = '${singular}_${_singularize(f.name).toLowerCase()}s';
      final relatedSingular = _singularize(f.relatedModel!).toLowerCase();
      relationRegs.add('''
    Entity.registerRelation<$className>(
      '${f.name}',
      BelongsToMany<${f.relatedModel}>(
        pivotTable: '$pivotTable',
        foreignPivotKey: '${singular}_id',
        relatedPivotKey: '${relatedSingular}_id',
      ),
    );
    Entity.registerPivotTable('$pivotTable', schema: {
      '${singular}_id': Column.integer().notNull().references('$moduleName'),
      '${relatedSingular}_id': Column.integer().notNull().references('${_pluralize(relatedSingular)}'),
    }, primaryKey: ['${singular}_id', '${relatedSingular}_id']);''');
    }
    final relationRegistrations = relationRegs.join('\n');

    // Build toJson with relations
    final toJsonLines = <String>["      'id': _id,"];
    for (final f in regularFields) {
      toJsonLines.add("      '${f.name}': ${f.name},");
    }
    for (final f in belongsToFields) {
      toJsonLines.add("      '${f.foreignKey}': ${f.foreignKey},");
      toJsonLines.add("      '${f.name}': ${f.name}?.toJson(),");
    }
    for (final f in toManyFields) {
      toJsonLines.add("      '${f.name}': ${f.name}.map((e) => e.toJson()).toList(),");
    }
    toJsonLines.add("      'createdAt': createdAt?.toIso8601String(),");
    toJsonLines.add("      'updatedAt': updatedAt?.toIso8601String(),");
    final toJsonFields = toJsonLines.join('\n');

    // Build imports for related models
    final imports = <String>["import 'package:duxt_orm/duxt_orm.dart';"];
    for (final f in belongsToFields) {
      final relatedFile = _singularize(f.relatedModel!).toLowerCase();
      imports.add("import '$relatedFile.dart';");
    }
    for (final f in toManyFields) {
      final relatedFile = _singularize(f.relatedModel!).toLowerCase();
      imports.add("import '$relatedFile.dart';");
    }
    final importsCode = imports.toSet().join('\n');

    final content = '''
$importsCode

class $className extends Entity {
  int? _id;
$fieldDeclarations
  DateTime? createdAt;
  DateTime? updatedAt;

  $className({${constructorParams.join(', ')}}) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

$relationAccessorsCode

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
$toJsonFields
    };

  /// Register this model with DuxtOrm.
  static void register() {
    Entity.registerModel<$className>(
      $className.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
$schemaColumns
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );
$relationRegistrations
  }

  @override
  String toString() => '$className(id: \$_id${regularFields.isNotEmpty ? ', ${regularFields.first.name}: \$${regularFields.first.name}' : ''})';
}
''';
    await File(p.join(modelsDir, '$singular.dart')).writeAsString(content);
  }

  Future<void> _generateOrmRoutes(String routesDir, String className, String moduleName, String singular, List<FieldDef> fields, String packageName) async {
    // Filter for regular fields only (not relations)
    final regularFields = fields.where((f) => !f.isRelation).toList();

    // Helper to make nullable type (avoid String??)
    String makeNullable(String type) => type.endsWith('?') ? type : '$type?';

    final content = '''
import 'package:duxt/server.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:$packageName/models/$singular.dart';

/// Register $moduleName API routes
void register${className}Routes(DuxtServer server) {
  final ${singular}s = Model<$className>();

  // GET /api/$moduleName - List all
  server.get('/api/$moduleName', (req) async {
    final items = await ${singular}s.all();
    return json({'$moduleName': items.map((e) => e.toJson()).toList()});
  });

  // GET /api/$moduleName/:id - Get one
  server.get('/api/$moduleName/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) {
      return json({'error': 'Invalid ID'}, statusCode: 400);
    }

    final item = await ${singular}s.find(id);
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

    final item = await ${singular}s.find(id);
    if (item == null) {
      return json({'error': 'Not found'}, statusCode: 404);
    }

    final body = req.body as Map<String, dynamic>?;
    if (body != null) {
${regularFields.map((f) => "      if (body.containsKey('${f.name}')) item.${f.name} = body['${f.name}'] as ${makeNullable(f.type)};").join('\n')}
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

    final item = await ${singular}s.find(id);
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

  String _dartTypeToColumn(String dartType, {String? originalType}) {
    // Check original type for more context
    if (originalType != null) {
      switch (originalType.toLowerCase()) {
        case 'text':
          return 'Column.text().nullable()';
        case 'email':
          return 'Column.string(255).nullable()';
        case 'image':
        case 'attachment':
          return 'Column.string(500).nullable()';
        case 'datetime':
        case 'date':
          return 'Column.dateTime().nullable()';
      }
    }

    switch (dartType) {
      case 'int':
        return 'Column.integer().nullable()';
      case 'double':
        return 'Column.decimal(10, 2).nullable()';
      case 'bool':
        return 'Column.boolean().defaultValue(false)';
      case 'DateTime?':
        return 'Column.dateTime().nullable()';
      case 'String?':
        return 'Column.string(500).nullable()';
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

  Future<void> _addNavLink(String projectDir, String moduleName, String className) async {
    // Try to find and update the default layout file
    final layoutPaths = [
      p.join(projectDir, 'lib', 'shared', 'layouts', 'default.dart'),
      p.join(projectDir, 'lib', 'layouts', 'default.dart'),
      p.join(projectDir, 'lib', 'shared', 'layout.dart'),
    ];

    for (final layoutPath in layoutPaths) {
      final file = File(layoutPath);
      if (file.existsSync()) {
        var content = await file.readAsString();

        // Check if link already exists
        if (content.contains("to: '/$moduleName'") || content.contains("href: '/$moduleName'")) {
          return; // Already has link
        }

        // Try to find nav section and add link
        // Look for the last Link in a nav section and add after it
        final linkPattern = RegExp(
          r"(Link\(to: '/[^']+', child: span\(classes: '[^']+', \[Component\.text\('[^']+'\)\]\)\)),?\n(\s*)(\]\),)",
          multiLine: true,
        );

        if (linkPattern.hasMatch(content)) {
          content = content.replaceFirstMapped(linkPattern, (m) {
            final indent = m.group(2) ?? '              ';
            return "${m.group(1)},\n${indent}Link(to: '/$moduleName', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('$className')])),\n${m.group(2)}${m.group(3)}";
          });
          await file.writeAsString(content);
          print('  \x1B[32m✓\x1B[0m Added nav link to ${p.basename(layoutPath)}');
          return;
        }

        // Pattern 2: a(href: '/...', [...])
        final aPattern = RegExp(
          r"(a\(href: '/[^']+',\s*\[[^\]]+\]\)),?\n(\s*)(\]\),)",
          multiLine: true,
        );

        if (aPattern.hasMatch(content)) {
          content = content.replaceFirstMapped(aPattern, (m) {
            final indent = m.group(2) ?? '              ';
            return "${m.group(1)},\n${indent}a(href: '/$moduleName', [Component.text('$className')]),\n${m.group(2)}${m.group(3)}";
          });
          await file.writeAsString(content);
          print('  \x1B[32m✓\x1B[0m Added nav link to ${p.basename(layoutPath)}');
          return;
        }
      }
    }
    // If we couldn't add automatically, don't print error - user can add manually
  }
}

/// Field definition with optional relation info
class FieldDef {
  final String name;
  final String type;
  final bool isRelation;
  final String? relationType; // 'belongsTo' or 'toMany'
  final String? relatedModel;

  FieldDef({
    required this.name,
    required this.type,
    this.isRelation = false,
    this.relationType,
    this.relatedModel,
  });

  /// Check if this is a belongsTo relation
  bool get isBelongsTo => relationType == 'belongsTo';

  /// Check if this is a toMany (many-to-many) relation
  bool get isToMany => relationType == 'toMany';

  /// Get the foreign key column name for belongsTo
  String get foreignKey => '${name}_id';
}
