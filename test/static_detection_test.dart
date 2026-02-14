import 'package:test/test.dart';
import 'package:duxt/src/compiler/manifest.dart';
import 'package:duxt/src/compiler/plugins/static_detection.dart';

void main() {
  group('StaticDetectionPlugin', () {
    late StaticDetectionPlugin plugin;

    setUp(() {
      plugin = StaticDetectionPlugin();
    });

    test('name is static-detection', () {
      expect(plugin.name, equals('static-detection'));
    });

    test('marks route as static when component and all deps are static', () {
      final manifest = DuxtManifest(
        components: [
          ComponentInfo(
            name: 'AboutPage',
            import_: 'package:app/pages/about.dart',
            kind: ComponentKind.static_,
          ),
          ComponentInfo(
            name: 'Footer',
            import_: 'package:app/components/footer.dart',
            kind: ComponentKind.static_,
          ),
        ],
        routes: [
          RouteEntry(
            path: '/about',
            componentImport: 'package:app/pages/about.dart',
            componentName: 'AboutPage',
            moduleName: 'main',
            renderMode: RenderMode.ssr, // starts as SSR
          ),
        ],
        dependencyGraph: {
          'AboutPage': {'Footer'},
          'Footer': <String>{},
        },
      );

      plugin.processManifest(manifest);

      expect(manifest.routes.first.renderMode, equals(RenderMode.static_));
    });

    test('does not mark route as static when component is interactive', () {
      final manifest = DuxtManifest(
        components: [
          ComponentInfo(
            name: 'DashboardPage',
            import_: 'package:app/pages/dashboard.dart',
            kind: ComponentKind.interactive,
          ),
        ],
        routes: [
          RouteEntry(
            path: '/dashboard',
            componentImport: 'package:app/pages/dashboard.dart',
            componentName: 'DashboardPage',
            moduleName: 'main',
            renderMode: RenderMode.ssr,
          ),
        ],
        dependencyGraph: {
          'DashboardPage': <String>{},
        },
      );

      plugin.processManifest(manifest);

      expect(manifest.routes.first.renderMode, equals(RenderMode.ssr));
    });

    test('does not mark route as static when dependency is interactive', () {
      final manifest = DuxtManifest(
        components: [
          ComponentInfo(
            name: 'ContactPage',
            import_: 'package:app/pages/contact.dart',
            kind: ComponentKind.static_,
          ),
          ComponentInfo(
            name: 'ContactForm',
            import_: 'package:app/components/contact_form.dart',
            kind: ComponentKind.interactive,
          ),
        ],
        routes: [
          RouteEntry(
            path: '/contact',
            componentImport: 'package:app/pages/contact.dart',
            componentName: 'ContactPage',
            moduleName: 'main',
            renderMode: RenderMode.ssr,
          ),
        ],
        dependencyGraph: {
          'ContactPage': {'ContactForm'},
          'ContactForm': <String>{},
        },
      );

      plugin.processManifest(manifest);

      // Should remain SSR because ContactForm is interactive
      expect(manifest.routes.first.renderMode, equals(RenderMode.ssr));
    });

    test('does not mark route as static when dependency is island', () {
      final manifest = DuxtManifest(
        components: [
          ComponentInfo(
            name: 'ProductPage',
            import_: 'package:app/pages/product.dart',
            kind: ComponentKind.static_,
          ),
          ComponentInfo(
            name: 'AddToCart',
            import_: 'package:app/components/add_to_cart.dart',
            kind: ComponentKind.island,
          ),
        ],
        routes: [
          RouteEntry(
            path: '/product',
            componentImport: 'package:app/pages/product.dart',
            componentName: 'ProductPage',
            moduleName: 'main',
            renderMode: RenderMode.ssr,
          ),
        ],
        dependencyGraph: {
          'ProductPage': {'AddToCart'},
          'AddToCart': <String>{},
        },
      );

      plugin.processManifest(manifest);

      expect(manifest.routes.first.renderMode, equals(RenderMode.ssr));
    });

    test('handles route with no matching component gracefully', () {
      final manifest = DuxtManifest(
        components: [],
        routes: [
          RouteEntry(
            path: '/missing',
            componentImport: 'missing.dart',
            componentName: 'MissingComponent',
            moduleName: 'main',
            renderMode: RenderMode.ssr,
          ),
        ],
      );

      // Should not throw
      plugin.processManifest(manifest);
      expect(manifest.routes.first.renderMode, equals(RenderMode.ssr));
    });

    test('handles multiple routes with mixed static/dynamic', () {
      final manifest = DuxtManifest(
        components: [
          ComponentInfo(
            name: 'HomePage',
            import_: 'package:app/pages/index.dart',
            kind: ComponentKind.static_,
          ),
          ComponentInfo(
            name: 'BlogPage',
            import_: 'package:app/blog/pages/index.dart',
            kind: ComponentKind.interactive,
          ),
          ComponentInfo(
            name: 'AboutPage',
            import_: 'package:app/pages/about.dart',
            kind: ComponentKind.static_,
          ),
        ],
        routes: [
          RouteEntry(
            path: '/',
            componentImport: 'package:app/pages/index.dart',
            componentName: 'HomePage',
            moduleName: 'main',
            renderMode: RenderMode.ssr,
          ),
          RouteEntry(
            path: '/blog',
            componentImport: 'package:app/blog/pages/index.dart',
            componentName: 'BlogPage',
            moduleName: 'blog',
            renderMode: RenderMode.ssr,
          ),
          RouteEntry(
            path: '/about',
            componentImport: 'package:app/pages/about.dart',
            componentName: 'AboutPage',
            moduleName: 'main',
            renderMode: RenderMode.ssr,
          ),
        ],
        dependencyGraph: {
          'HomePage': <String>{},
          'BlogPage': <String>{},
          'AboutPage': <String>{},
        },
      );

      plugin.processManifest(manifest);

      expect(manifest.routes[0].renderMode, equals(RenderMode.static_)); // HomePage
      expect(manifest.routes[1].renderMode, equals(RenderMode.ssr));     // BlogPage
      expect(manifest.routes[2].renderMode, equals(RenderMode.static_)); // AboutPage
    });
  });
}
