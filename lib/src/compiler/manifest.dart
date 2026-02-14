import 'dart:convert';

/// How a component should be rendered
enum ComponentKind {
  /// No client JS needed — pure static HTML
  static_,

  /// @island — isolated hydration boundary, separate JS chunk
  island,

  /// @client or has stateful behavior — Jaspr's existing hydration
  interactive,

  /// Has asyncData — needs SSR data injection
  dynamicData,
}

/// How a route should be rendered
enum RenderMode {
  /// Pure static HTML, zero JS
  static_,

  /// Server-side rendered with client hydration
  ssr,

  /// Client-side rendered
  client,
}

/// Analysis results for a single source file
class ComponentAnalysis {
  /// Asset ID of the analyzed file (package:path format)
  final String assetPath;

  /// All components found in this file
  final List<ComponentInfo> components;

  ComponentAnalysis({
    required this.assetPath,
    List<ComponentInfo>? components,
  }) : components = components ?? [];

  Map<String, dynamic> serialize() => {
    'assetPath': assetPath,
    'components': components.map((c) => c.serialize()).toList(),
  };

  factory ComponentAnalysis.deserialize(Map<String, dynamic> map) {
    return ComponentAnalysis(
      assetPath: map['assetPath'] as String,
      components: (map['components'] as List)
          .map((c) => ComponentInfo.deserialize(c as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => jsonEncode(serialize());
  factory ComponentAnalysis.fromJson(String json) =>
      ComponentAnalysis.deserialize(jsonDecode(json) as Map<String, dynamic>);
}

/// Metadata about a single component discovered during analysis
class ComponentInfo {
  /// Class name (e.g. 'HomePage')
  final String name;

  /// Import path (e.g. 'package:my_app/home/pages/index.dart')
  final String import_;

  /// Classification of this component
  ComponentKind kind;

  /// Constructor parameters
  final List<ParamInfo> params;

  /// Annotations found on the class
  final Set<String> annotations;

  /// Whether the component has stateful behavior
  final bool hasState;

  /// Whether the component uses AsyncDataMixin
  final bool hasAsyncData;

  /// Whether the component imports browser-only APIs
  final bool usesBrowserAPIs;

  /// Plugin-contributed metadata
  final Map<String, dynamic> extra;

  ComponentInfo({
    required this.name,
    required this.import_,
    required this.kind,
    List<ParamInfo>? params,
    Set<String>? annotations,
    this.hasState = false,
    this.hasAsyncData = false,
    this.usesBrowserAPIs = false,
    Map<String, dynamic>? extra,
  })  : params = params ?? [],
        annotations = annotations ?? {},
        extra = extra ?? {};

  Map<String, dynamic> serialize() => {
    'name': name,
    'import': import_,
    'kind': kind.name,
    'params': params.map((p) => p.serialize()).toList(),
    'annotations': annotations.toList(),
    'hasState': hasState,
    'hasAsyncData': hasAsyncData,
    'usesBrowserAPIs': usesBrowserAPIs,
    'extra': extra,
  };

  factory ComponentInfo.deserialize(Map<String, dynamic> map) {
    return ComponentInfo(
      name: map['name'] as String,
      import_: map['import'] as String,
      kind: ComponentKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => ComponentKind.interactive,
      ),
      params: (map['params'] as List?)
              ?.map((p) => ParamInfo.deserialize(p as Map<String, dynamic>))
              .toList() ??
          [],
      annotations: (map['annotations'] as List?)?.cast<String>().toSet() ?? {},
      hasState: map['hasState'] as bool? ?? false,
      hasAsyncData: map['hasAsyncData'] as bool? ?? false,
      usesBrowserAPIs: map['usesBrowserAPIs'] as bool? ?? false,
      extra: Map<String, dynamic>.from(map['extra'] as Map? ?? {}),
    );
  }
}

/// Information about a constructor parameter
class ParamInfo {
  final String name;
  final String type;
  final bool isRequired;
  final bool isNamed;

  const ParamInfo({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.isNamed = false,
  });

  Map<String, dynamic> serialize() => {
    'name': name,
    'type': type,
    'isRequired': isRequired,
    'isNamed': isNamed,
  };

  factory ParamInfo.deserialize(Map<String, dynamic> map) {
    return ParamInfo(
      name: map['name'] as String,
      type: map['type'] as String,
      isRequired: map['isRequired'] as bool? ?? false,
      isNamed: map['isNamed'] as bool? ?? false,
    );
  }
}

/// Route entry in the manifest
class RouteEntry {
  /// URL path (e.g. '/blog/:slug')
  final String path;

  /// Import path of the component
  final String componentImport;

  /// Component class name
  final String componentName;

  /// Module name (e.g. 'blog')
  final String moduleName;

  /// How this route should be rendered
  RenderMode renderMode;

  RouteEntry({
    required this.path,
    required this.componentImport,
    required this.componentName,
    required this.moduleName,
    this.renderMode = RenderMode.ssr,
  });

  Map<String, dynamic> serialize() => {
    'path': path,
    'componentImport': componentImport,
    'componentName': componentName,
    'moduleName': moduleName,
    'renderMode': renderMode.name,
  };

  factory RouteEntry.deserialize(Map<String, dynamic> map) {
    return RouteEntry(
      path: map['path'] as String,
      componentImport: map['componentImport'] as String,
      componentName: map['componentName'] as String,
      moduleName: map['moduleName'] as String,
      renderMode: RenderMode.values.firstWhere(
        (m) => m.name == map['renderMode'],
        orElse: () => RenderMode.ssr,
      ),
    );
  }
}

/// The full project manifest — aggregated from all file analyses.
/// Built during Phase 2 and consumed by Phase 3 and 4.
class DuxtManifest {
  /// All analyzed components in the project
  final List<ComponentInfo> components;

  /// Route table — path to component mapping
  final List<RouteEntry> routes;

  /// Dependency graph — componentName -> set of imported component names
  final Map<String, Set<String>> dependencyGraph;

  /// Plugin-contributed metadata
  final Map<String, dynamic> metadata;

  DuxtManifest({
    List<ComponentInfo>? components,
    List<RouteEntry>? routes,
    Map<String, Set<String>>? dependencyGraph,
    Map<String, dynamic>? metadata,
  })  : components = components ?? [],
        routes = routes ?? [],
        dependencyGraph = dependencyGraph ?? {},
        metadata = metadata ?? {};

  /// Components classified as static (no client JS needed)
  List<ComponentInfo> get staticComponents =>
      components.where((c) => c.kind == ComponentKind.static_).toList();

  /// Components marked as islands
  List<ComponentInfo> get islands =>
      components.where((c) => c.kind == ComponentKind.island).toList();

  /// Routes that can be fully static (zero JS)
  List<RouteEntry> get staticRoutes =>
      routes.where((r) => r.renderMode == RenderMode.static_).toList();

  /// Routes that need client JS
  List<RouteEntry> get dynamicRoutes =>
      routes.where((r) => r.renderMode != RenderMode.static_).toList();

  /// Find the component info for a route
  ComponentInfo? componentFor(RouteEntry route) {
    try {
      return components.firstWhere((c) => c.name == route.componentName);
    } catch (_) {
      return null;
    }
  }

  /// Get all transitive dependencies of a component
  Set<ComponentInfo> allDependenciesOf(String componentName) {
    final result = <ComponentInfo>{};
    final visited = <String>{};

    void walk(String name) {
      if (visited.contains(name)) return;
      visited.add(name);
      final deps = dependencyGraph[name] ?? {};
      for (final dep in deps) {
        try {
          final info = components.firstWhere((c) => c.name == dep);
          result.add(info);
          walk(dep);
        } catch (_) {}
      }
    }

    walk(componentName);
    return result;
  }

  Map<String, dynamic> serialize() => {
    'components': components.map((c) => c.serialize()).toList(),
    'routes': routes.map((r) => r.serialize()).toList(),
    'dependencyGraph': dependencyGraph.map(
      (k, v) => MapEntry(k, v.toList()),
    ),
    'metadata': metadata,
  };

  factory DuxtManifest.deserialize(Map<String, dynamic> map) {
    return DuxtManifest(
      components: (map['components'] as List?)
              ?.map((c) => ComponentInfo.deserialize(c as Map<String, dynamic>))
              .toList() ??
          [],
      routes: (map['routes'] as List?)
              ?.map((r) => RouteEntry.deserialize(r as Map<String, dynamic>))
              .toList() ??
          [],
      dependencyGraph: (map['dependencyGraph'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as List).cast<String>().toSet()),
          ) ??
          {},
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  String toJson() => jsonEncode(serialize());
  factory DuxtManifest.fromJson(String json) =>
      DuxtManifest.deserialize(jsonDecode(json) as Map<String, dynamic>);
}
