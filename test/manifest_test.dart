import 'package:test/test.dart';
import 'package:duxt/src/compiler/manifest.dart';

void main() {
  group('ComponentKind', () {
    test('has all expected values', () {
      expect(ComponentKind.values, hasLength(4));
      expect(ComponentKind.values, contains(ComponentKind.static_));
      expect(ComponentKind.values, contains(ComponentKind.island));
      expect(ComponentKind.values, contains(ComponentKind.interactive));
      expect(ComponentKind.values, contains(ComponentKind.dynamicData));
    });
  });

  group('RenderMode', () {
    test('has all expected values', () {
      expect(RenderMode.values, hasLength(3));
      expect(RenderMode.values, contains(RenderMode.static_));
      expect(RenderMode.values, contains(RenderMode.ssr));
      expect(RenderMode.values, contains(RenderMode.client));
    });
  });

  group('ComponentInfo', () {
    test('serialize and deserialize round-trip', () {
      final info = ComponentInfo(
        name: 'HomePage',
        import_: 'package:app/pages/index.dart',
        kind: ComponentKind.static_,
        params: [
          ParamInfo(name: 'title', type: 'String', isRequired: true, isNamed: true),
        ],
        annotations: {'client'},
        hasState: false,
        hasAsyncData: false,
        usesBrowserAPIs: false,
        extra: {'custom': 'value'},
      );

      final map = info.serialize();
      final restored = ComponentInfo.deserialize(map);

      expect(restored.name, equals('HomePage'));
      expect(restored.import_, equals('package:app/pages/index.dart'));
      expect(restored.kind, equals(ComponentKind.static_));
      expect(restored.params, hasLength(1));
      expect(restored.params.first.name, equals('title'));
      expect(restored.params.first.type, equals('String'));
      expect(restored.params.first.isRequired, isTrue);
      expect(restored.params.first.isNamed, isTrue);
      expect(restored.annotations, contains('client'));
      expect(restored.hasState, isFalse);
      expect(restored.hasAsyncData, isFalse);
      expect(restored.usesBrowserAPIs, isFalse);
      expect(restored.extra['custom'], equals('value'));
    });

    test('deserialize with missing optional fields', () {
      final map = {
        'name': 'TestComponent',
        'import': 'package:app/test.dart',
        'kind': 'interactive',
      };

      final info = ComponentInfo.deserialize(map);
      expect(info.name, equals('TestComponent'));
      expect(info.kind, equals(ComponentKind.interactive));
      expect(info.params, isEmpty);
      expect(info.annotations, isEmpty);
      expect(info.hasState, isFalse);
      expect(info.extra, isEmpty);
    });

    test('deserialize with unknown kind falls back to interactive', () {
      final map = {
        'name': 'Test',
        'import': 'test.dart',
        'kind': 'unknown_kind',
      };

      final info = ComponentInfo.deserialize(map);
      expect(info.kind, equals(ComponentKind.interactive));
    });
  });

  group('ParamInfo', () {
    test('serialize and deserialize round-trip', () {
      const param = ParamInfo(
        name: 'count',
        type: 'int',
        isRequired: true,
        isNamed: false,
      );

      final map = param.serialize();
      final restored = ParamInfo.deserialize(map);

      expect(restored.name, equals('count'));
      expect(restored.type, equals('int'));
      expect(restored.isRequired, isTrue);
      expect(restored.isNamed, isFalse);
    });
  });

  group('RouteEntry', () {
    test('serialize and deserialize round-trip', () {
      final route = RouteEntry(
        path: '/blog/:slug',
        componentImport: 'package:app/blog/pages/slug.dart',
        componentName: 'BlogPost',
        moduleName: 'blog',
        renderMode: RenderMode.ssr,
      );

      final map = route.serialize();
      final restored = RouteEntry.deserialize(map);

      expect(restored.path, equals('/blog/:slug'));
      expect(restored.componentImport, equals('package:app/blog/pages/slug.dart'));
      expect(restored.componentName, equals('BlogPost'));
      expect(restored.moduleName, equals('blog'));
      expect(restored.renderMode, equals(RenderMode.ssr));
    });

    test('defaults to ssr render mode', () {
      final route = RouteEntry(
        path: '/',
        componentImport: 'test.dart',
        componentName: 'Home',
        moduleName: 'main',
      );
      expect(route.renderMode, equals(RenderMode.ssr));
    });
  });

  group('ComponentAnalysis', () {
    test('toJson and fromJson round-trip', () {
      final analysis = ComponentAnalysis(
        assetPath: 'package:app/pages/index.dart',
        components: [
          ComponentInfo(
            name: 'IndexPage',
            import_: 'package:app/pages/index.dart',
            kind: ComponentKind.static_,
          ),
        ],
      );

      final json = analysis.toJson();
      final restored = ComponentAnalysis.fromJson(json);

      expect(restored.assetPath, equals('package:app/pages/index.dart'));
      expect(restored.components, hasLength(1));
      expect(restored.components.first.name, equals('IndexPage'));
      expect(restored.components.first.kind, equals(ComponentKind.static_));
    });
  });

  group('DuxtManifest', () {
    late DuxtManifest manifest;

    setUp(() {
      manifest = DuxtManifest(
        components: [
          ComponentInfo(
            name: 'HomePage',
            import_: 'package:app/pages/index.dart',
            kind: ComponentKind.static_,
          ),
          ComponentInfo(
            name: 'Counter',
            import_: 'package:app/components/counter.dart',
            kind: ComponentKind.island,
          ),
          ComponentInfo(
            name: 'BlogPage',
            import_: 'package:app/blog/pages/index.dart',
            kind: ComponentKind.interactive,
          ),
          ComponentInfo(
            name: 'Header',
            import_: 'package:app/components/header.dart',
            kind: ComponentKind.static_,
          ),
        ],
        routes: [
          RouteEntry(
            path: '/',
            componentImport: 'package:app/pages/index.dart',
            componentName: 'HomePage',
            moduleName: 'main',
            renderMode: RenderMode.static_,
          ),
          RouteEntry(
            path: '/blog',
            componentImport: 'package:app/blog/pages/index.dart',
            componentName: 'BlogPage',
            moduleName: 'blog',
            renderMode: RenderMode.ssr,
          ),
        ],
        dependencyGraph: {
          'HomePage': {'Header'},
          'BlogPage': {'Counter', 'Header'},
          'Counter': <String>{},
          'Header': <String>{},
        },
      );
    });

    test('staticComponents filters correctly', () {
      final statics = manifest.staticComponents;
      expect(statics, hasLength(2));
      expect(statics.map((c) => c.name), containsAll(['HomePage', 'Header']));
    });

    test('islands filters correctly', () {
      final islands = manifest.islands;
      expect(islands, hasLength(1));
      expect(islands.first.name, equals('Counter'));
    });

    test('staticRoutes filters correctly', () {
      final staticRoutes = manifest.staticRoutes;
      expect(staticRoutes, hasLength(1));
      expect(staticRoutes.first.path, equals('/'));
    });

    test('dynamicRoutes filters correctly', () {
      final dynamicRoutes = manifest.dynamicRoutes;
      expect(dynamicRoutes, hasLength(1));
      expect(dynamicRoutes.first.path, equals('/blog'));
    });

    test('componentFor finds component for route', () {
      final route = manifest.routes.first;
      final component = manifest.componentFor(route);
      expect(component, isNotNull);
      expect(component!.name, equals('HomePage'));
    });

    test('componentFor returns null for unknown route', () {
      final route = RouteEntry(
        path: '/missing',
        componentImport: 'missing.dart',
        componentName: 'Missing',
        moduleName: 'main',
      );
      expect(manifest.componentFor(route), isNull);
    });

    test('allDependenciesOf walks transitive dependencies', () {
      final deps = manifest.allDependenciesOf('BlogPage');
      expect(deps.map((d) => d.name), containsAll(['Counter', 'Header']));
    });

    test('allDependenciesOf returns empty for leaf component', () {
      final deps = manifest.allDependenciesOf('Header');
      expect(deps, isEmpty);
    });

    test('allDependenciesOf handles cycles', () {
      manifest.dependencyGraph['Header'] = {'HomePage'};
      manifest.dependencyGraph['HomePage'] = {'Header'};

      // Should not infinite loop
      final deps = manifest.allDependenciesOf('HomePage');
      expect(deps.map((d) => d.name), contains('Header'));
    });

    test('toJson and fromJson round-trip', () {
      final json = manifest.toJson();
      final restored = DuxtManifest.fromJson(json);

      expect(restored.components, hasLength(4));
      expect(restored.routes, hasLength(2));
      expect(restored.dependencyGraph, hasLength(4));
      expect(restored.components.first.name, equals('HomePage'));
      expect(restored.routes.first.path, equals('/'));
    });
  });
}
