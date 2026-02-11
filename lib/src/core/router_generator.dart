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
///
/// Namespace support:
/// - lib/<namespace>/<module>/pages/index.dart -> /<namespace>/<module>
/// - lib/admin/posts/pages/index.dart -> /admin/posts
/// - lib/theme/blog/pages/index.dart -> /blog (theme/ strips prefix)
/// - lib/theme/home/pages/index.dart -> / (theme/home maps to root)
/// - lib/<namespace>/layouts/default.dart -> wraps all namespace routes
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

    // Discover modules recursively (supports namespaces)
    final (routes, namespaceLayouts) = await _discoverModules(libDir, '', projectDir);

    // Also check for old-style lib/pages directory (backwards compat)
    final oldPagesDir = Directory(p.join(projectDir, 'lib', 'pages'));
    if (oldPagesDir.existsSync()) {
      final oldRoutes = await _scanModulePages(oldPagesDir, oldPagesDir.path, '');
      routes.addAll(oldRoutes);
    }

    // Resolve route conflicts — theme routes win over flat modules for same path
    _resolveRouteConflicts(routes);

    // Sort routes (static before dynamic, shorter before longer)
    routes.sort(_compareRoutes);

    // Generate code
    final code = _generateRouterCode(routes, projectDir, namespaceLayouts);
    await outputFile.writeAsString(code);

    print('  Generated ${routes.length} routes from ${_countModules(routes)} modules');
  }

  /// Recursively discover modules and namespaces under a directory.
  ///
  /// A directory is a **module** if it directly contains pages/ or content/.
  /// A directory is a **namespace** if it contains child directories that have pages/ or content/.
  /// A directory can be both.
  static Future<(List<RouteInfo>, Map<String, String>)> _discoverModules(
    Directory dir,
    String prefix,
    String projectDir,
  ) async {
    final routes = <RouteInfo>[];
    final namespaceLayouts = <String, String>{};

    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);

      // Skip internal directories
      if ({'shared', '.generated', 'models', '.duxt'}.contains(name)) continue;

      final modulePath = prefix.isEmpty ? name : '$prefix/$name';
      final hasPagesDir = Directory(p.join(entity.path, 'pages')).existsSync();
      final hasContentDir = Directory(p.join(entity.path, 'content')).existsSync();

      // Scan as module if it has pages/ or content/
      if (hasPagesDir) {
        final pagesDir = Directory(p.join(entity.path, 'pages'));
        final moduleRoutes = await _scanModulePages(
          pagesDir,
          pagesDir.path,
          modulePath,
        );
        routes.addAll(moduleRoutes);
      }
      if (hasContentDir) {
        final contentDir = Directory(p.join(entity.path, 'content'));
        final contentRoutes = await _scanModuleContent(
          contentDir,
          contentDir.path,
          modulePath,
        );
        routes.addAll(contentRoutes);
      }

      // Check for namespace layout (e.g. lib/admin/layouts/default.dart)
      final layoutFile = File(p.join(entity.path, 'layouts', 'default.dart'));
      if (layoutFile.existsSync()) {
        final nsKey = prefix.isEmpty ? name : '$prefix/$name';
        namespaceLayouts[nsKey] = layoutFile.path;
      }

      // Check if this directory is a namespace (has child dirs with pages/ or content/)
      bool isNamespace = false;
      await for (final child in entity.list()) {
        if (child is Directory) {
          final childName = p.basename(child.path);
          // Skip well-known module subdirectories
          if ({'pages', 'content', 'components', 'layouts', 'models'}.contains(childName)) continue;
          if (Directory(p.join(child.path, 'pages')).existsSync() ||
              Directory(p.join(child.path, 'content')).existsSync()) {
            isNamespace = true;
            break;
          }
        }
      }

      if (isNamespace) {
        final (childRoutes, childLayouts) = await _discoverModules(entity, modulePath, projectDir);
        routes.addAll(childRoutes);
        namespaceLayouts.addAll(childLayouts);
      }
    }

    return (routes, namespaceLayouts);
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

    // Build route path with namespace/theme support
    final routePath = _buildRoutePath(moduleName, relativePath);

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

  /// Build the URL route path from module name and relative file path.
  /// Handles theme/ prefix stripping and home module mapping.
  static String _buildRoutePath(String moduleName, String relativePath) {
    String routePath;

    if (moduleName.startsWith('theme/')) {
      // Theme namespace: strip the 'theme/' prefix
      final inner = moduleName.substring(6); // e.g. 'home', 'blog'
      if (inner == 'home') {
        // theme/home maps to root /
        routePath = relativePath.isEmpty ? '/' : '/$relativePath';
      } else {
        routePath = relativePath.isEmpty ? '/$inner' : '/$inner/$relativePath';
      }
    } else if (moduleName == 'home' || moduleName.isEmpty) {
      // Flat home module maps to root
      routePath = relativePath.isEmpty ? '/' : '/$relativePath';
    } else {
      // Standard: module path becomes route prefix
      // e.g. 'admin/posts' -> '/admin/posts'
      routePath = relativePath.isEmpty ? '/$moduleName' : '/$moduleName/$relativePath';
    }

    // Clean up double slashes
    routePath = routePath.replaceAll('//', '/');
    if (routePath != '/' && routePath.endsWith('/')) {
      routePath = routePath.substring(0, routePath.length - 1);
    }

    return routePath;
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

    // Build route path with namespace/theme support
    var routePath = _buildRoutePath(moduleName, relativePath);

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

  /// Resolve route conflicts: theme routes win over flat modules for same path.
  static void _resolveRouteConflicts(List<RouteInfo> routes) {
    final pathMap = <String, List<RouteInfo>>{};
    for (final route in routes) {
      pathMap.putIfAbsent(route.path, () => []).add(route);
    }

    for (final entry in pathMap.entries) {
      if (entry.value.length > 1) {
        // Find theme routes vs non-theme routes
        final themeRoutes = entry.value.where((r) => r.moduleName.startsWith('theme/')).toList();
        final otherRoutes = entry.value.where((r) => !r.moduleName.startsWith('theme/')).toList();

        if (themeRoutes.isNotEmpty && otherRoutes.isNotEmpty) {
          // Theme wins — remove others and warn
          for (final other in otherRoutes) {
            print('  \x1B[33m!\x1B[0m Route conflict: ${entry.key} — theme/${themeRoutes.first.moduleName.substring(6)} wins over ${other.moduleName}');
            routes.remove(other);
          }
        }
      }
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

  static String _generateRouterCode(
    List<RouteInfo> routes,
    String projectDir,
    Map<String, String> namespaceLayouts,
  ) {
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

    // Import namespace layout files
    final usedNamespaces = <String>{};
    for (final route in dartRoutes) {
      final ns = _getNamespaceForRoute(route.moduleName, namespaceLayouts);
      if (ns != null && !usedNamespaces.contains(ns)) {
        usedNamespaces.add(ns);
        final layoutPath = namespaceLayouts[ns]!;
        final importPath =
            p.relative(layoutPath, from: p.join(projectDir, 'lib', '.generated'));
        buffer.writeln("import '$importPath' as ${_toLayoutAlias(ns)};");
      }
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
      final ns = _getNamespaceForRoute(route.moduleName, namespaceLayouts);
      final layoutAlias = ns != null ? _toLayoutAlias(ns) : null;
      final layoutClassName = ns != null ? _extractLayoutClassName(namespaceLayouts[ns]!) : null;

      buffer.writeln('  Route(');
      buffer.writeln("    path: '${route.path}',");
      buffer.writeln('    builder: (context, state) {');

      // Build the page component expression
      String pageExpr;
      if (route.params.isNotEmpty) {
        final paramLines = route.params.map((param) =>
            "        $param: state.params['$param']!,").join('\n');
        pageExpr = '${_toImportAlias(route)}.${route.componentName}(\n$paramLines\n      )';
      } else {
        pageExpr = 'const ${_toImportAlias(route)}.${route.componentName}()';
      }

      // Wrap in namespace layout if available
      if (layoutAlias != null && layoutClassName != null) {
        buffer.writeln('      return $layoutAlias.$layoutClassName(');
        buffer.writeln('        child: $pageExpr,');
        buffer.writeln('      );');
      } else {
        buffer.writeln('      return $pageExpr;');
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

  /// Get the namespace key that applies to a module, if any.
  /// e.g. moduleName='admin/posts' checks for 'admin' in namespaceLayouts.
  static String? _getNamespaceForRoute(String moduleName, Map<String, String> namespaceLayouts) {
    if (moduleName.isEmpty) return null;

    // Check for exact match first (e.g. 'admin' namespace)
    final parts = moduleName.split('/');
    // Walk up from the full path to find a matching namespace
    for (var i = parts.length - 1; i >= 0; i--) {
      final candidate = parts.sublist(0, i + 1).join('/');
      if (namespaceLayouts.containsKey(candidate)) {
        // Only match if moduleName is nested under the candidate
        // (i.e. candidate != moduleName, or candidate == moduleName if it's a direct namespace module)
        if (candidate != moduleName || i < parts.length - 1) {
          return candidate;
        }
      }
    }

    // Check prefix matches: if moduleName is 'admin/posts', check if 'admin' has a layout
    for (var i = parts.length - 1; i >= 1; i--) {
      final candidate = parts.sublist(0, i).join('/');
      if (namespaceLayouts.containsKey(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  /// Extract the layout class name from a layout file.
  static String? _extractLayoutClassName(String filePath) {
    try {
      final content = File(filePath).readAsStringSync();
      final pattern = RegExp(r'class\s+(\w+Layout)\s+extends');
      final match = pattern.firstMatch(content);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Generate a unique import alias that includes the module path.
  static String _toImportAlias(RouteInfo route) {
    final modulePrefix = route.moduleName.replaceAll(RegExp(r'[^a-z0-9]'), '_').toLowerCase();
    final safeName = route.componentName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    if (modulePrefix.isEmpty) {
      return 'page_$safeName';
    }
    return 'page_${modulePrefix}_$safeName';
  }

  /// Generate a layout import alias from namespace key.
  static String _toLayoutAlias(String namespace) {
    final safe = namespace.replaceAll(RegExp(r'[^a-z0-9]'), '_').toLowerCase();
    return 'layout_$safe';
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
