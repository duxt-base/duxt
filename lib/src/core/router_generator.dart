import 'dart:io';
import 'package:path/path.dart' as p;

/// Generates Jaspr Router configuration from module-based structure
///
/// Conventions:
/// - lib/<module>/pages/index.dart -> /<module> (or / for "home" module)
/// - lib/<module>/pages/[id].dart -> /<module>/:id
/// - lib/<module>/pages/new.dart -> /<module>/new
/// - lib/<module>/pages/[id]/edit.dart -> /<module>/:id/edit
class RouterGenerator {
  static Future<void> generate(String projectDir) async {
    final libDir = Directory(p.join(projectDir, 'lib'));
    final outputDir = Directory(p.join(projectDir, '.duxt'));
    final outputFile = File(p.join(outputDir.path, 'routes.g.dart'));

    if (!libDir.existsSync()) {
      print('  No lib directory found');
      return;
    }

    // Ensure output directory exists
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Scan all modules
    final routes = <RouteInfo>[];
    await for (final entity in libDir.list()) {
      if (entity is Directory) {
        final moduleName = p.basename(entity.path);

        // Skip shared directory
        if (moduleName == 'shared') continue;

        final pagesDir = Directory(p.join(entity.path, 'pages'));
        if (pagesDir.existsSync()) {
          final moduleRoutes = await _scanModulePages(
            pagesDir,
            pagesDir.path,
            moduleName,
          );
          routes.addAll(moduleRoutes);
        }
      }
    }

    // Also check for old-style lib/pages directory (backwards compat)
    final oldPagesDir = Directory(p.join(projectDir, 'lib', 'pages'));
    if (oldPagesDir.existsSync()) {
      final oldRoutes = await _scanModulePages(oldPagesDir, oldPagesDir.path, '');
      routes.addAll(oldRoutes);
    }

    // Sort routes (static before dynamic, shorter before longer)
    routes.sort(_compareRoutes);

    // Generate code
    final code = _generateRouterCode(routes, projectDir);
    await outputFile.writeAsString(code);

    print('  Generated ${routes.length} routes from ${_countModules(routes)} modules');
  }

  static int _countModules(List<RouteInfo> routes) {
    return routes.map((r) => r.moduleName).toSet().length;
  }

  static Future<List<RouteInfo>> _scanModulePages(
    Directory dir,
    String basePath,
    String moduleName,
  ) async {
    final routes = <RouteInfo>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final route = _fileToRoute(entity.path, basePath, moduleName);
        if (route != null) {
          routes.add(route);
        }
      }
    }

    return routes;
  }

  static RouteInfo? _fileToRoute(String filePath, String basePath, String moduleName) {
    // Get relative path from pages/
    var relativePath = p.relative(filePath, from: basePath);

    // Remove .dart extension
    relativePath = relativePath.replaceAll('.dart', '');

    // Handle index files
    if (relativePath == 'index') {
      relativePath = '';
    } else if (relativePath.endsWith('/index')) {
      relativePath = relativePath.replaceAll('/index', '');
    }

    // Build route path
    String routePath;
    if (moduleName == 'home' || moduleName.isEmpty) {
      // Home module maps to root
      routePath = relativePath.isEmpty ? '/' : '/$relativePath';
    } else {
      // Other modules get prefixed
      routePath = relativePath.isEmpty ? '/$moduleName' : '/$moduleName/$relativePath';
    }

    // Convert [param] to :param (standard to Jaspr style)
    routePath = routePath.replaceAllMapped(
      RegExp(r'\[\.\.\.(\w+)\]'),
      (m) => '*', // Catch-all
    );
    routePath = routePath.replaceAllMapped(
      RegExp(r'\[(\w+)\]'),
      (m) => ':${m.group(1)}',
    );

    // Clean up double slashes
    routePath = routePath.replaceAll('//', '/');
    if (routePath != '/' && routePath.endsWith('/')) {
      routePath = routePath.substring(0, routePath.length - 1);
    }

    // Extract component name from file
    final componentName = _toComponentName(relativePath, moduleName);

    // Detect dynamic parameters
    final params = <String>[];
    final paramRegex = RegExp(r':(\w+)');
    for (final match in paramRegex.allMatches(routePath)) {
      params.add(match.group(1)!);
    }

    return RouteInfo(
      path: routePath,
      filePath: filePath,
      componentName: componentName,
      moduleName: moduleName,
      params: params,
      isCatchAll: routePath.contains('*'),
    );
  }

  static String _toComponentName(String relativePath, String moduleName) {
    // Convert file path to PascalCase component name
    final parts = relativePath
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('...', '')
        .split('/')
        .where((p) => p.isNotEmpty)
        .map(_toPascalCase)
        .toList();

    final modulePrefix = _toPascalCase(moduleName);

    if (parts.isEmpty) {
      return moduleName.isEmpty ? 'IndexPage' : '${modulePrefix}Page';
    }

    return '$modulePrefix${parts.join('')}Page';
  }

  static String _toPascalCase(String s) {
    if (s.isEmpty) return s;
    return s.split(RegExp(r'[_-]'))
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join('');
  }

  static int _compareRoutes(RouteInfo a, RouteInfo b) {
    // Static routes before dynamic
    final aIsDynamic = a.path.contains(':') || a.path.contains('*');
    final bIsDynamic = b.path.contains(':') || b.path.contains('*');

    if (aIsDynamic != bIsDynamic) {
      return aIsDynamic ? 1 : -1;
    }

    // Catch-all routes last
    if (a.isCatchAll != b.isCatchAll) {
      return a.isCatchAll ? 1 : -1;
    }

    // Shorter paths first
    return a.path.length.compareTo(b.path.length);
  }

  static String _generateRouterCode(List<RouteInfo> routes, String projectDir) {
    final buffer = StringBuffer();

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by Duxt');
    buffer.writeln('');
    buffer.writeln("import 'package:jaspr_router/jaspr_router.dart';");
    buffer.writeln('');

    // Import all page files
    for (final route in routes) {
      final importPath = p.relative(route.filePath, from: p.join(projectDir, 'lib'));
      buffer.writeln("import '$importPath' as ${_toImportAlias(route)};");
    }

    buffer.writeln('');
    buffer.writeln('/// Generated routes from modules');
    buffer.writeln('final generatedRoutes = <Route>[');

    for (final route in routes) {
      buffer.writeln('  Route(');
      buffer.writeln("    path: '${route.path}',");
      buffer.writeln('    builder: (context, state) {');

      if (route.params.isNotEmpty) {
        buffer.writeln('      return ${_toImportAlias(route)}.${route.componentName}(');
        for (final param in route.params) {
          buffer.writeln("        $param: state.params['$param']!,");
        }
        buffer.writeln('      );');
      } else {
        buffer.writeln('      return const ${_toImportAlias(route)}.${route.componentName}();');
      }

      buffer.writeln('    },');
      buffer.writeln('  ),');
    }

    buffer.writeln('];');

    return buffer.toString();
  }

  static String _toImportAlias(RouteInfo route) {
    final safeName = route.componentName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'page_$safeName';
  }
}

/// Information about a route
class RouteInfo {
  final String path;
  final String filePath;
  final String componentName;
  final String moduleName;
  final List<String> params;
  final bool isCatchAll;

  RouteInfo({
    required this.path,
    required this.filePath,
    required this.componentName,
    required this.moduleName,
    required this.params,
    required this.isCatchAll,
  });

  @override
  String toString() => 'RouteInfo($path -> $componentName [$moduleName])';
}
