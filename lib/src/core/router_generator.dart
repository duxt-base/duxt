import 'dart:io';
import 'package:path/path.dart' as p;

/// Route type: dart component or markdown content
enum RouteType { dart, content }

/// Generates Jaspr Router configuration from module-based structure
///
/// Conventions:
/// - lib/<module>/pages/index.dart -> /<module> (or / for "home" module)
/// - lib/<module>/pages/_id_.dart -> /<module>/:id
/// - lib/<module>/pages/new.dart -> /<module>/new
/// - lib/<module>/pages/_id_/edit.dart -> /<module>/:id/edit
/// - lib/<module>/content/cli.md -> /<module>/cli (content route)
/// - lib/<module>/content/sub/nested.md -> /<module>/sub/nested (content route)
class RouterGenerator {
  static Future<void> generate(String projectDir) async {
    final libDir = Directory(p.join(projectDir, 'lib'));
    final outputDir = Directory(p.join(projectDir, 'lib', '.generated'));
    final outputFile = File(p.join(outputDir.path, 'routes.dart'));

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

        // Scan content directory for markdown files
        final contentDir = Directory(p.join(entity.path, 'content'));
        if (contentDir.existsSync()) {
          final contentRoutes = await _scanModuleContent(
            contentDir,
            contentDir.path,
            moduleName,
          );
          routes.addAll(contentRoutes);
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

  /// Scan module content directory for markdown files
  static Future<List<RouteInfo>> _scanModuleContent(
    Directory dir,
    String basePath,
    String moduleName,
  ) async {
    final routes = <RouteInfo>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('.md') || entity.path.endsWith('.mdx'))) {
        final route = _contentFileToRoute(entity.path, basePath, moduleName);
        if (route != null) {
          routes.add(route);
        }
      }
    }

    return routes;
  }

  /// Convert a content file path to a RouteInfo
  static RouteInfo? _contentFileToRoute(
      String filePath, String basePath, String moduleName) {
    // Get relative path from content/
    var relativePath = p.relative(filePath, from: basePath);

    // Remove .md/.mdx extension
    relativePath = relativePath.replaceAll('.mdx', '').replaceAll('.md', '');

    // Handle index files
    if (relativePath == 'index') {
      relativePath = '';
    } else if (relativePath.endsWith('/index')) {
      relativePath = relativePath.replaceAll('/index', '');
    }

    // Build route path - content is always prefixed with module
    String routePath;
    if (moduleName == 'home' || moduleName.isEmpty) {
      routePath = relativePath.isEmpty ? '/' : '/$relativePath';
    } else {
      routePath =
          relativePath.isEmpty ? '/$moduleName' : '/$moduleName/$relativePath';
    }

    // Clean up double slashes
    routePath = routePath.replaceAll('//', '/');
    if (routePath != '/' && routePath.endsWith('/')) {
      routePath = routePath.substring(0, routePath.length - 1);
    }

    return RouteInfo(
      path: routePath,
      filePath: filePath,
      componentName: '', // Not used for content routes
      moduleName: moduleName,
      params: [],
      isCatchAll: false,
      type: RouteType.content,
    );
  }

  static RouteInfo? _fileToRoute(String filePath, String basePath, String moduleName) {
    // Get relative path from pages/
    var relativePath = p.relative(filePath, from: basePath);

    // Remove .dart extension
    relativePath = relativePath.replaceAll('.dart', '');

    // Handle index files for route path
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

    // Convert dynamic route patterns to :param (Jaspr style)
    // Supports: [param], _param_ conventions
    routePath = routePath.replaceAllMapped(
      RegExp(r'\[\.\.\.(\w+)\]'),
      (m) => '*', // Catch-all
    );
    routePath = routePath.replaceAllMapped(
      RegExp(r'\[(\w+)\]'),
      (m) => ':${m.group(1)}',
    );
    // Support _param_ convention (valid Dart filename)
    routePath = routePath.replaceAllMapped(
      RegExp(r'_(\w+)_'),
      (m) => ':${m.group(1)}',
    );

    // Clean up double slashes
    routePath = routePath.replaceAll('//', '/');
    if (routePath != '/' && routePath.endsWith('/')) {
      routePath = routePath.substring(0, routePath.length - 1);
    }

    // Extract component info from file content
    final componentInfo = _extractComponentInfo(filePath);
    if (componentInfo.name == null) {
      return null; // Skip files without a valid component class
    }

    // Detect dynamic parameters from route path
    final params = <String>[];
    final paramRegex = RegExp(r':(\w+)');
    for (final match in paramRegex.allMatches(routePath)) {
      params.add(match.group(1)!);
    }

    // Also include required params from the component constructor
    // and add them to the route path if not already present
    for (final param in componentInfo.params) {
      if (!params.contains(param)) {
        params.add(param);
        // Append the param to the route path as a dynamic segment
        routePath = '$routePath/:$param';
      }
    }

    return RouteInfo(
      path: routePath,
      filePath: filePath,
      componentName: componentInfo.name!,
      moduleName: moduleName,
      params: params,
      isCatchAll: routePath.contains('*'),
    );
  }

  /// Extract component info (class name and required params) from a Dart file
  static ({String? name, List<String> params}) _extractComponentInfo(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return (name: null, params: []);

      final content = file.readAsStringSync();

      // Look for class that extends StatelessComponent or StatefulComponent
      // Pattern: class ClassName extends [Stateless|Stateful]Component
      final classPattern = RegExp(
        r'class\s+(\w+)\s+extends\s+(?:Stateless|Stateful)Component',
        multiLine: true,
      );

      String? className;
      final match = classPattern.firstMatch(content);
      if (match != null) {
        className = match.group(1);
      } else {
        // Fallback: look for any class ending in Page
        final pagePattern = RegExp(r'class\s+(\w+Page)\s+extends', multiLine: true);
        final pageMatch = pagePattern.firstMatch(content);
        if (pageMatch != null) {
          className = pageMatch.group(1);
        }
      }

      if (className == null) return (name: null, params: []);

      // Extract required parameters from the constructor
      // Pattern: const ClassName({required this.paramName, ...})
      final constructorPattern = RegExp(
        'const\\s+$className\\s*\\(\\s*\\{([^}]*)\\}',
        multiLine: true,
      );
      final constructorMatch = constructorPattern.firstMatch(content);

      final params = <String>[];
      if (constructorMatch != null) {
        final paramsStr = constructorMatch.group(1) ?? '';
        // Find all "required this.paramName" patterns
        final requiredParamPattern = RegExp(r'required\s+this\.(\w+)');
        for (final m in requiredParamPattern.allMatches(paramsStr)) {
          final paramName = m.group(1);
          // Skip super.key and other internal params
          if (paramName != null && paramName != 'key') {
            params.add(paramName);
          }
        }
      }

      return (name: className, params: params);
    } catch (_) {
      return (name: null, params: []);
    }
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
    final dartRoutes = routes.where((r) => r.type == RouteType.dart).toList();
    final contentRoutes =
        routes.where((r) => r.type == RouteType.content).toList();

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by Duxt');
    buffer.writeln('');
    buffer.writeln("import 'package:jaspr_router/jaspr_router.dart';");

    // Only import duxt content if we have content routes
    if (contentRoutes.isNotEmpty) {
      buffer.writeln("import 'package:duxt/content.dart';");
    }

    buffer.writeln('');

    // Import all dart page files
    // Note: routes.dart is in lib/.generated/, so imports are relative to that
    for (final route in dartRoutes) {
      final importPath =
          p.relative(route.filePath, from: p.join(projectDir, 'lib', '.generated'));
      buffer.writeln("import '$importPath' as ${_toImportAlias(route)};");
    }

    // Generate content route info list if we have content routes
    if (contentRoutes.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('/// Content route info for markdown pages');
      buffer.writeln('const _contentRoutes = <ContentRouteInfo>[');
      for (final route in contentRoutes) {
        buffer.writeln('  ContentRouteInfo(');
        buffer.writeln("    path: '${route.path}',");
        buffer.writeln("    filePath: '${route.filePath}',");
        buffer.writeln("    moduleName: '${route.moduleName}',");
        buffer.writeln('  ),');
      }
      buffer.writeln('];');
    }

    buffer.writeln('');
    buffer.writeln('/// Generated routes from modules');

    // If we have content routes, generate a function that takes config
    if (contentRoutes.isNotEmpty) {
      buffer.writeln(
          'List<Route> generatedRoutes({DuxtPageConfig? config}) => [');
    } else {
      buffer.writeln('final generatedRoutes = <Route>[');
    }

    // Dart routes
    for (final route in dartRoutes) {
      buffer.writeln('  Route(');
      buffer.writeln("    path: '${route.path}',");
      buffer.writeln('    builder: (context, state) {');

      if (route.params.isNotEmpty) {
        buffer.writeln(
            '      return ${_toImportAlias(route)}.${route.componentName}(');
        for (final param in route.params) {
          buffer.writeln("        $param: state.params['$param']!,");
        }
        buffer.writeln('      );');
      } else {
        buffer.writeln(
            '      return const ${_toImportAlias(route)}.${route.componentName}();');
      }

      buffer.writeln('    },');
      buffer.writeln('  ),');
    }

    // Content routes
    if (contentRoutes.isNotEmpty) {
      buffer.writeln('  // Content routes');
      buffer.writeln('  for (final info in _contentRoutes)');
      buffer.writeln('    Route(');
      buffer.writeln('      path: info.path,');
      buffer.writeln('      builder: (context, state) => DuxtContentPage(');
      buffer.writeln('        routeInfo: info,');
      buffer.writeln('        config: config,');
      buffer.writeln('      ),');
      buffer.writeln('    ),');
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
  final RouteType type;

  RouteInfo({
    required this.path,
    required this.filePath,
    required this.componentName,
    required this.moduleName,
    required this.params,
    required this.isCatchAll,
    this.type = RouteType.dart,
  });

  @override
  String toString() => 'RouteInfo($path -> ${type == RouteType.dart ? componentName : 'content'} [$moduleName])';
}
