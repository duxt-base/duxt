import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Scaffold command - generates full CRUD like Rails
/// Usage: duxt scaffold <name> [field:type ...]
///
/// Example: duxt scaffold post title:String content:String author:String
///
/// Generates:
/// - lib/models/<name>.dart         (Model with fields)
/// - lib/pages/<name>/index.dart    (List page)
/// - lib/pages/<name>/[id].dart     (Detail page)
/// - lib/components/<name>_card.dart (Card component)
/// - server/api/<name>.dart         (CRUD API endpoints)
class ScaffoldCommand extends Command<int> {
  @override
  final name = 'scaffold';

  @override
  final description = 'Generate full CRUD scaffold (model, pages, component, API)';

  @override
  String get invocation => 'duxt scaffold <name> [field:type ...]';

  ScaffoldCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing files',
      defaultsTo: false,
    );
    argParser.addFlag(
      'api-only',
      help: 'Only generate model and API (no pages/components)',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      print('Error: Please specify a resource name');
      print('Usage: duxt scaffold <name> [field:type ...]');
      print('');
      print('Example:');
      print('  duxt scaffold post title:String content:String author:String');
      return 1;
    }

    final resourceName = argResults!.rest[0].toLowerCase();
    final fields = _parseFields(argResults!.rest.skip(1).toList());
    final force = argResults!['force'] as bool;
    final apiOnly = argResults!['api-only'] as bool;
    final projectDir = Directory.current.path;

    // Validate we're in a Duxt project
    if (!File('$projectDir/duxt.config.dart').existsSync() &&
        !Directory('$projectDir/lib/pages').existsSync()) {
      print('Error: Not a Duxt project directory');
      return 1;
    }

    print('');
    print('\x1B[36mScaffolding $resourceName...\x1B[0m');
    print('');

    final className = _toPascalCase(resourceName);
    final pluralName = _pluralize(resourceName);

    try {
      // 1. Generate Model
      await _generateModel(projectDir, resourceName, className, fields, force);

      // 2. Generate API
      await _generateApi(projectDir, pluralName, resourceName, className, fields, force);

      if (!apiOnly) {
        // 3. Generate Card Component
        await _generateCard(projectDir, resourceName, className, fields, force);

        // 4. Generate List Page
        await _generateListPage(projectDir, pluralName, resourceName, className, fields, force);

        // 5. Generate Detail Page
        await _generateDetailPage(projectDir, pluralName, resourceName, className, fields, force);
      }

      print('');
      print('\x1B[32m✓ Scaffold complete!\x1B[0m');
      print('');

      if (!apiOnly) {
        print('Add these routes to lib/app.dart:');
        print('');
        print('  Route(');
        print("    path: '/$pluralName',");
        print("    title: '${_toPascalCase(pluralName)}',");
        print('    builder: (context, state) => const ${className}ListPage(),');
        print('  ),');
        print('  Route(');
        print("    path: '/$pluralName/:id',");
        print("    title: '$className Detail',");
        print('    builder: (context, state) => ${className}DetailPage(');
        print("      id: state.params['id']!,");
        print('    ),');
        print('  ),');
        print('');
        print('Add these imports:');
        print("  import 'pages/$pluralName/index.dart';");
        print("  import 'pages/$pluralName/[id].dart';");
      }

      print('');
      print('API endpoints:');
      print('  GET    /api/$pluralName      - List all');
      print('  GET    /api/$pluralName?id=X - Get by ID');
      print('  POST   /api/$pluralName      - Create');
      print('  PUT    /api/$pluralName      - Update');
      print('  DELETE /api/$pluralName      - Delete');

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
      default:
        return type;
    }
  }

  String _toPascalCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'[_-]'))
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join('');
  }

  String _pluralize(String s) {
    if (s.endsWith('y')) {
      return '${s.substring(0, s.length - 1)}ies';
    } else if (s.endsWith('s') || s.endsWith('x') || s.endsWith('ch') || s.endsWith('sh')) {
      return '${s}es';
    }
    return '${s}s';
  }

  Future<void> _generateModel(String projectDir, String name, String className, List<FieldDef> fields, bool force) async {
    final dir = Directory(p.join(projectDir, 'lib', 'models'));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, '$name.dart'));
    if (file.existsSync() && !force) {
      print('  \x1B[33m⚠\x1B[0m Model exists: lib/models/$name.dart (use --force to overwrite)');
      return;
    }

    final content = _buildModelContent(className, fields);
    await file.writeAsString(content);
    print('  \x1B[32m✓\x1B[0m Created model: lib/models/$name.dart');
  }

  Future<void> _generateApi(String projectDir, String pluralName, String name, String className, List<FieldDef> fields, bool force) async {
    final dir = Directory(p.join(projectDir, 'server', 'api'));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, '$pluralName.dart'));
    if (file.existsSync() && !force) {
      print('  \x1B[33m⚠\x1B[0m API exists: server/api/$pluralName.dart (use --force to overwrite)');
      return;
    }

    final content = _buildApiContent(pluralName, name, className, fields);
    await file.writeAsString(content);
    print('  \x1B[32m✓\x1B[0m Created API: server/api/$pluralName.dart');
  }

  Future<void> _generateCard(String projectDir, String name, String className, List<FieldDef> fields, bool force) async {
    final dir = Directory(p.join(projectDir, 'lib', 'components'));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, '${name}_card.dart'));
    if (file.existsSync() && !force) {
      print('  \x1B[33m⚠\x1B[0m Component exists: lib/components/${name}_card.dart (use --force to overwrite)');
      return;
    }

    final content = _buildCardContent(name, className, fields);
    await file.writeAsString(content);
    print('  \x1B[32m✓\x1B[0m Created component: lib/components/${name}_card.dart');
  }

  Future<void> _generateListPage(String projectDir, String pluralName, String name, String className, List<FieldDef> fields, bool force) async {
    final dir = Directory(p.join(projectDir, 'lib', 'pages', pluralName));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, 'index.dart'));
    if (file.existsSync() && !force) {
      print('  \x1B[33m⚠\x1B[0m Page exists: lib/pages/$pluralName/index.dart (use --force to overwrite)');
      return;
    }

    final content = _buildListPageContent(pluralName, name, className, fields);
    await file.writeAsString(content);
    print('  \x1B[32m✓\x1B[0m Created page: lib/pages/$pluralName/index.dart');
  }

  Future<void> _generateDetailPage(String projectDir, String pluralName, String name, String className, List<FieldDef> fields, bool force) async {
    final dir = Directory(p.join(projectDir, 'lib', 'pages', pluralName));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, '[id].dart'));
    if (file.existsSync() && !force) {
      print('  \x1B[33m⚠\x1B[0m Page exists: lib/pages/$pluralName/[id].dart (use --force to overwrite)');
      return;
    }

    final content = _buildDetailPageContent(pluralName, name, className, fields);
    await file.writeAsString(content);
    print('  \x1B[32m✓\x1B[0m Created page: lib/pages/$pluralName/[id].dart');
  }

  // Content builders

  String _buildModelContent(String className, List<FieldDef> fields) {
    final allFields = [
      FieldDef(name: 'id', type: 'String'),
      ...fields,
      FieldDef(name: 'createdAt', type: 'DateTime'),
      FieldDef(name: 'updatedAt', type: 'DateTime'),
    ];

    final fieldDeclarations = allFields.map((f) => '  final ${f.type}? ${f.name};').join('\n');
    final constructorParams = allFields.map((f) => 'this.${f.name}').join(', ');

    final fromJsonFields = allFields.map((f) {
      if (f.type == 'DateTime') {
        return "      ${f.name}: json['${f.name}'] != null ? DateTime.parse(json['${f.name}']) : null,";
      }
      return "      ${f.name}: json['${f.name}'] as ${f.type}?,";
    }).join('\n');

    final toJsonFields = allFields.map((f) {
      if (f.type == 'DateTime') {
        return "      '${f.name}': ${f.name}?.toIso8601String(),";
      }
      return "      '${f.name}': ${f.name},";
    }).join('\n');

    final copyWithParams = allFields.map((f) => '    ${f.type}? ${f.name},').join('\n');
    final copyWithAssignments = allFields.map((f) => '      ${f.name}: ${f.name} ?? this.${f.name},').join('\n');

    return '''
/// $className model
class $className {
$fieldDeclarations

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
$copyWithParams
  }) {
    return $className(
$copyWithAssignments
    );
  }

  @override
  String toString() => '$className(id: \$id)';
}
''';
  }

  String _buildApiContent(String pluralName, String name, String className, List<FieldDef> fields) {
    return '''
import 'package:duxt/server.dart';

/// $className API - /api/$pluralName
///
/// GET    /api/$pluralName      - List all ${pluralName}
/// GET    /api/$pluralName?id=X - Get $name by ID
/// POST   /api/$pluralName      - Create $name
/// PUT    /api/$pluralName      - Update $name
/// DELETE /api/$pluralName?id=X - Delete $name

// In-memory storage (replace with database)
final List<Map<String, dynamic>> _${pluralName}Store = [];
int _nextId = 1;

final handler = defineEventHandler((request) async {
  switch (request.method) {
    case 'GET':
      final id = getQueryParam(request, 'id');
      if (id != null) {
        // Get by ID
        final item = _${pluralName}Store.where((p) => p['id'] == id).firstOrNull;
        if (item == null) {
          return ApiResponse.notFound('$className not found');
        }
        return ApiResponse.json(item);
      }
      // List all
      return ApiResponse.json({
        'items': _${pluralName}Store,
        'total': _${pluralName}Store.length,
      });

    case 'POST':
      final body = request.json as Map<String, dynamic>?;
      if (body == null) {
        return ApiResponse.badRequest('Request body required');
      }
      final newItem = {
        'id': (_nextId++).toString(),
        ...body,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      _${pluralName}Store.add(newItem);
      return ApiResponse.created(newItem);

    case 'PUT':
      final body = request.json as Map<String, dynamic>?;
      if (body == null || body['id'] == null) {
        return ApiResponse.badRequest('Request body with id required');
      }
      final index = _${pluralName}Store.indexWhere((p) => p['id'] == body['id']);
      if (index == -1) {
        return ApiResponse.notFound('$className not found');
      }
      final updated = {
        ..._${pluralName}Store[index],
        ...body,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      _${pluralName}Store[index] = updated;
      return ApiResponse.json(updated);

    case 'DELETE':
      final id = getQueryParam(request, 'id');
      if (id == null) {
        return ApiResponse.badRequest('id query parameter required');
      }
      final index = _${pluralName}Store.indexWhere((p) => p['id'] == id);
      if (index == -1) {
        return ApiResponse.notFound('$className not found');
      }
      _${pluralName}Store.removeAt(index);
      return ApiResponse.noContent();

    default:
      return ApiResponse.methodNotAllowed();
  }
});
''';
  }

  String _buildCardContent(String name, String className, List<FieldDef> fields) {
    final displayField = fields.isNotEmpty ? fields.first.name : 'id';
    final subtitleField = fields.length > 1 ? fields[1].name : null;

    return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../models/$name.dart';

class ${className}Card extends StatelessComponent {
  final $className item;
  final String? linkTo;

  const ${className}Card({
    super.key,
    required this.item,
    this.linkTo,
  });

  @override
  Component build(BuildContext context) {
    final content = div(
      classes: 'p-4 bg-white rounded-lg shadow-sm border hover:shadow-md transition-shadow',
      [
        div(classes: 'flex justify-between items-start', [
          div(classes: 'flex-1', [
            h3(classes: 'text-lg font-semibold text-gray-900', [
              text(item.$displayField ?? 'Untitled'),
            ]),
${subtitleField != null ? '''            p(classes: 'text-gray-600 mt-1', [
              text(item.$subtitleField ?? ''),
            ]),''' : ''}
          ]),
          span(classes: 'text-xs text-gray-400', [
            text('#\${item.id}'),
          ]),
        ]),
        div(classes: 'mt-3 text-xs text-gray-400', [
          text('Created: \${item.createdAt?.toString().split('.').first ?? "N/A"}'),
        ]),
      ],
    );

    if (linkTo != null) {
      return a(href: linkTo, [content]);
    }
    return content;
  }
}
''';
  }

  String _buildListPageContent(String pluralName, String name, String className, List<FieldDef> fields) {
    final pluralClassName = _toPascalCase(pluralName);

    return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../../models/$name.dart';
import '../../components/${name}_card.dart';

class ${className}ListPage extends StatelessComponent {
  const ${className}ListPage({super.key});

  // Sample data - replace with actual data fetching
  List<$className> get _items => [
    $className(
      id: '1',
${fields.map((f) => "      ${f.name}: ${_sampleValue(f.type, f.name)},").join('\n')}
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    $className(
      id: '2',
${fields.map((f) => "      ${f.name}: ${_sampleValue(f.type, f.name, 2)},").join('\n')}
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-6', [
      // Header
      div(classes: 'flex justify-between items-center', [
        h1(classes: 'text-3xl font-bold text-gray-900', [
          text('$pluralClassName'),
        ]),
        a(
          href: '/$pluralName/new',
          classes: 'px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700',
          [text('Add $className')],
        ),
      ]),

      // List
      div(classes: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4', [
        for (final item in _items)
          ${className}Card(
            item: item,
            linkTo: '/$pluralName/\${item.id}',
          ),
      ]),

      // Empty state
      if (_items.isEmpty)
        div(classes: 'text-center py-12', [
          p(classes: 'text-gray-500', [
            text('No $pluralName found'),
          ]),
        ]),
    ]);
  }
}
''';
  }

  String _buildDetailPageContent(String pluralName, String name, String className, List<FieldDef> fields) {
    final fieldDisplays = fields.map((f) => '''
          div(classes: 'border-b pb-3', [
            dt(classes: 'text-sm text-gray-500', [text('${_toTitleCase(f.name)}')]),
            dd(classes: 'mt-1 text-gray-900', [text(item.${f.name}?.toString() ?? 'N/A')]),
          ]),''').join('\n');

    return '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../../models/$name.dart';

class ${className}DetailPage extends StatelessComponent {
  final String id;

  const ${className}DetailPage({
    super.key,
    required this.id,
  });

  // Sample data - replace with actual data fetching
  $className? get item => $className(
    id: id,
${fields.map((f) => "    ${f.name}: ${_sampleValue(f.type, f.name)},").join('\n')}
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Component build(BuildContext context) {
    if (item == null) {
      return div(classes: 'text-center py-12', [
        h1(classes: 'text-2xl font-bold text-gray-900', [text('$className Not Found')]),
        p(classes: 'text-gray-600 mt-2', [text('The $name you\\'re looking for doesn\\'t exist.')]),
        a(
          href: '/$pluralName',
          classes: 'text-indigo-600 hover:underline mt-4 inline-block',
          [text('← Back to $pluralName')],
        ),
      ]);
    }

    return div(classes: 'max-w-2xl mx-auto', [
      // Back link
      a(
        href: '/$pluralName',
        classes: 'text-indigo-600 hover:underline mb-4 inline-block',
        [text('← Back to $pluralName')],
      ),

      // Header
      div(classes: 'flex justify-between items-start mb-6', [
        h1(classes: 'text-3xl font-bold text-gray-900', [
          text('$className #\$id'),
        ]),
        div(classes: 'flex gap-2', [
          a(
            href: '/$pluralName/\$id/edit',
            classes: 'px-3 py-1 border rounded hover:bg-gray-50',
            [text('Edit')],
          ),
          button(
            classes: 'px-3 py-1 border border-red-300 text-red-600 rounded hover:bg-red-50',
            [text('Delete')],
          ),
        ]),
      ]),

      // Details
      div(classes: 'bg-white rounded-lg shadow-sm border p-6', [
        dl(classes: 'space-y-4', [
$fieldDisplays
          div(classes: 'border-b pb-3', [
            dt(classes: 'text-sm text-gray-500', [text('Created')]),
            dd(classes: 'mt-1 text-gray-900', [
              text(item!.createdAt?.toString().split('.').first ?? 'N/A'),
            ]),
          ]),
          div([
            dt(classes: 'text-sm text-gray-500', [text('Updated')]),
            dd(classes: 'mt-1 text-gray-900', [
              text(item!.updatedAt?.toString().split('.').first ?? 'N/A'),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
''';
  }

  String _sampleValue(String type, String fieldName, [int index = 1]) {
    switch (type) {
      case 'String':
        return "'Sample ${_toTitleCase(fieldName)} $index'";
      case 'int':
        return '$index';
      case 'double':
        return '${index}.0';
      case 'bool':
        return 'true';
      default:
        return 'null';
    }
  }

  String _toTitleCase(String s) {
    return s.replaceAllMapped(
      RegExp(r'([A-Z])|^([a-z])'),
      (m) => m.group(1) != null ? ' ${m.group(1)}' : m.group(2)!.toUpperCase(),
    ).trim();
  }
}

class FieldDef {
  final String name;
  final String type;

  FieldDef({required this.name, required this.type});
}
