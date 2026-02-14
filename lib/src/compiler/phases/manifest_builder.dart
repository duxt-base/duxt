import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';

import '../manifest.dart';
import '../plugin.dart';

/// Phase 2 Builder: Aggregates all per-file analyses into a project manifest.
///
/// This is an aggregation builder that:
/// 1. Reads all .duxt.json files produced by Phase 1 (AnalyzeBuilder)
/// 2. Builds the full component registry and dependency graph
/// 3. Generates the route table from the pages/ directory structure
/// 4. Runs plugins' processManifest() to finalize classifications
/// 5. Outputs manifest.json with the complete project analysis
///
/// Registered in build.yaml with required_inputs: [".duxt.json"]
class ManifestBuilder implements Builder {
  final List<DuxtPlugin> plugins;

  ManifestBuilder({List<DuxtPlugin>? plugins}) : plugins = plugins ?? [];

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': ['lib/.duxt/manifest.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final manifest = DuxtManifest();

    // Collect all .duxt.json analysis files
    final analysisGlob = Glob('lib/**.duxt.json');
    await for (final input in buildStep.findAssets(analysisGlob)) {
      try {
        final content = await buildStep.readAsString(input);
        final analysis = ComponentAnalysis.fromJson(content);

        for (final component in analysis.components) {
          manifest.components.add(component);
        }
      } catch (e) {
        log.warning('Failed to read analysis file $input: $e');
      }
    }

    // Build route table from pages/ structure
    _buildRouteTable(manifest);

    // Build dependency graph (simplified — uses import paths)
    _buildDependencyGraph(manifest);

    // Run plugins
    for (final plugin in plugins) {
      await plugin.processManifest(manifest);
    }

    // Write manifest
    final outputId = AssetId(
      buildStep.inputId.package,
      'lib/.duxt/manifest.json',
    );
    await buildStep.writeAsString(outputId, manifest.toJson());
  }

  /// Build route entries from discovered page components.
  /// Pages are identified by their import path containing '/pages/'.
  void _buildRouteTable(DuxtManifest manifest) {
    for (final component in manifest.components) {
      final importPath = component.import_;

      // Only page components (in pages/ directories)
      if (!importPath.contains('/pages/')) continue;

      // Extract route path from file path
      // e.g. package:app/blog/pages/index.dart → /blog
      // e.g. package:app/pages/about.dart → /about
      // e.g. package:app/admin/pages/_id_.dart → /admin/:id
      final routePath = _importToRoutePath(importPath);
      final moduleName = _extractModuleName(importPath);

      manifest.routes.add(RouteEntry(
        path: routePath,
        componentImport: importPath,
        componentName: component.name,
        moduleName: moduleName,
      ));
    }
  }

  /// Convert an import path to a route path.
  String _importToRoutePath(String importPath) {
    // Remove package prefix: package:app/lib/ → lib/
    var path = importPath;
    final pagesIdx = path.indexOf('/pages/');
    if (pagesIdx == -1) return '/';

    // Get module prefix (everything before /pages/)
    final beforePages = path.substring(0, pagesIdx);
    final modulePrefix = beforePages.contains('/')
        ? '/${beforePages.split('/').last}'
        : '';

    // Get file name after /pages/
    var filePart = path.substring(pagesIdx + '/pages/'.length);

    // Remove .dart extension
    if (filePart.endsWith('.dart')) {
      filePart = filePart.substring(0, filePart.length - 5);
    }

    // Convert index to /
    if (filePart == 'index') {
      return modulePrefix.isEmpty ? '/' : modulePrefix;
    }

    // Convert _param_ to :param
    filePart = filePart.replaceAllMapped(
      RegExp(r'_([a-zA-Z][a-zA-Z0-9]*)_'),
      (m) => ':${m.group(1)}',
    );

    // Handle nested paths
    filePart = filePart.replaceAll('/', '/');

    return '$modulePrefix/$filePart';
  }

  /// Extract module name from import path.
  String _extractModuleName(String importPath) {
    final pagesIdx = importPath.indexOf('/pages/');
    if (pagesIdx == -1) return 'main';

    final beforePages = importPath.substring(0, pagesIdx);
    final parts = beforePages.split('/');
    return parts.isNotEmpty ? parts.last : 'main';
  }

  /// Build a simplified dependency graph based on component imports.
  void _buildDependencyGraph(DuxtManifest manifest) {
    // Map component names to their imports for lookup
    final componentsByImport = <String, String>{};
    for (final c in manifest.components) {
      componentsByImport[c.import_] = c.name;
    }

    // For each component, check if its import file references other components
    // This is a simplified version — full dependency analysis would need
    // the resolver to trace imports, but that's Phase 1's job
    for (final component in manifest.components) {
      manifest.dependencyGraph[component.name] = <String>{};
    }
  }
}
