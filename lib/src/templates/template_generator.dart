import 'dart:io';
import 'package:path/path.dart' as p;

/// Generates a new Duxt project from template
class TemplateGenerator {
  /// Generate a new project
  static Future<void> generate(String projectName, String targetDir) async {
    // Convert project name to valid Dart identifier
    final dartName = projectName.replaceAll('-', '_').replaceAll(' ', '_');

    final dir = Directory(targetDir);
    await dir.create(recursive: true);

    // Create directory structure
    await _createDirectories(targetDir);

    // Create files
    await _createPubspec(dartName, targetDir);
    await _createDuxtConfig(dartName, targetDir);
    await _createMainFile(targetDir);
    await _createAppFile(dartName, targetDir);
    await _createDefaultLayout(targetDir);
    await _createIndexPage(dartName, targetDir);
    await _createAboutPage(targetDir);
    await _createExampleMiddleware(targetDir);
    await _createExampleComposable(targetDir);
    await _createExampleApiRoute(targetDir);
    await _createExampleComponent(targetDir);
    await _createTailwindStyles(targetDir);
    await _createIndexHtml(dartName, targetDir);

    print('  \x1B[32m✓\x1B[0m Created pubspec.yaml');
    print('  \x1B[32m✓\x1B[0m Created duxt.config.dart');
    print('  \x1B[32m✓\x1B[0m Created lib/main.client.dart');
    print('  \x1B[32m✓\x1B[0m Created lib/app.dart');
    print('  \x1B[32m✓\x1B[0m Created pages/index.dart');
    print('  \x1B[32m✓\x1B[0m Created pages/about.dart');
    print('  \x1B[32m✓\x1B[0m Created layouts/default.dart');
    print('  \x1B[32m✓\x1B[0m Created middleware/auth.dart');
    print('  \x1B[32m✓\x1B[0m Created composables/counter.dart');
    print('  \x1B[32m✓\x1B[0m Created components/welcome_card.dart');
    print('  \x1B[32m✓\x1B[0m Created server/api/hello.dart');
    print('  \x1B[32m✓\x1B[0m Created web/styles.tw.css');
    print('  \x1B[32m✓\x1B[0m Created web/index.html');
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/pages',
      'lib/layouts',
      'lib/components',
      'middleware',
      'composables',
      'server/api',
      'public',
      'web',
      '.duxt',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _createPubspec(String projectName, String targetDir) async {
    final content = '''
name: $projectName
description: A Duxt project
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  jaspr: ^0.22.1
  jaspr_router: ^0.8.1
  jaspr_riverpod: ^0.4.3
  duxt:
    path: /Volumes/External/duxt

dev_dependencies:
  build_runner: ^2.4.0
  build_web_compilers: ^4.4.8
  jaspr_builder: ^0.22.1
  jaspr_tailwind: ^0.3.6
  lints: ^4.0.0

jaspr:
  mode: client
''';
    await File(p.join(targetDir, 'pubspec.yaml')).writeAsString(content);
  }

  static Future<void> _createDuxtConfig(String projectName, String targetDir) async {
    final content = '''
/// Duxt configuration
/// Similar to nuxt.config.ts
library;

class DuxtConfig {
  /// App configuration
  static const app = AppConfig(
    name: '$projectName',
    description: 'A Duxt application',
  );

  /// Rendering mode: 'spa', 'ssr', 'static'
  static const String mode = 'spa';

  /// Development server configuration
  static const dev = DevConfig(
    port: 3000,
  );

  /// Build configuration
  static const build = BuildConfig(
    target: 'web',
  );

  /// Route rules
  static const routeRules = <String, RouteRule>{
    // '/api/**': RouteRule(proxy: 'http://localhost:8000'),
  };

  /// Global middleware
  static const List<String> middleware = [];

  /// Head configuration
  static const head = HeadConfig(
    title: '$projectName',
    meta: [
      {'charset': 'utf-8'},
      {'name': 'viewport', 'content': 'width=device-width, initial-scale=1'},
    ],
  );
}

class AppConfig {
  final String name;
  final String description;

  const AppConfig({required this.name, required this.description});
}

class DevConfig {
  final int port;

  const DevConfig({required this.port});
}

class BuildConfig {
  final String target;

  const BuildConfig({required this.target});
}

class RouteRule {
  final String? proxy;
  final bool? prerender;
  final int? cache;

  const RouteRule({this.proxy, this.prerender, this.cache});
}

class HeadConfig {
  final String title;
  final List<Map<String, String>> meta;

  const HeadConfig({required this.title, required this.meta});
}
''';
    await File(p.join(targetDir, 'duxt.config.dart')).writeAsString(content);
  }

  static Future<void> _createMainFile(String targetDir) async {
    final content = r'''
/// The entrypoint for the client app.
///
/// This file is compiled to javascript and executed on the client.
library;

import 'package:jaspr/client.dart';
import 'app.dart';

void main() {
  runApp(App());
}
''';
    await File(p.join(targetDir, 'lib', 'main.client.dart')).writeAsString(content);
  }

  static Future<void> _createAppFile(String projectName, String targetDir) async {
    final content = r'''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'pages/index.dart';
import 'pages/about.dart';
import 'layouts/default.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen flex flex-col', [
      Router(routes: [
        ShellRoute(
          builder: (context, state, child) => DefaultLayout(child: child),
          routes: [
            Route(
              path: '/',
              title: 'Home',
              builder: (context, state) => const IndexPage(),
            ),
            Route(
              path: '/about',
              title: 'About',
              builder: (context, state) => const AboutPage(),
            ),
          ],
        ),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'app.dart')).writeAsString(content);
  }

  static Future<void> _createDefaultLayout(String targetDir) async {
    final content = r'''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gray-50 flex flex-col', [
      // Navigation
      nav(classes: 'bg-white shadow-sm', [
        div(classes: 'max-w-7xl mx-auto px-4 py-4 flex justify-between items-center', [
          a(href: '/', classes: 'text-xl font-bold text-indigo-600', [
            text('Duxt App'),
          ]),
          div(classes: 'flex gap-6', [
            Link(
              to: '/',
              child: span(classes: 'text-gray-600 hover:text-indigo-600 transition-colors', [
                text('Home'),
              ]),
            ),
            Link(
              to: '/about',
              child: span(classes: 'text-gray-600 hover:text-indigo-600 transition-colors', [
                text('About'),
              ]),
            ),
          ]),
        ]),
      ]),
      // Main content
      main_(classes: 'flex-1 max-w-7xl mx-auto px-4 py-8 w-full', [
        child,
      ]),
      // Footer
      footer(classes: 'bg-white border-t mt-auto', [
        div(classes: 'max-w-7xl mx-auto px-4 py-6 text-center text-gray-500', [
          text('Built with Duxt - The Nuxt for Jaspr'),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'layouts', 'default.dart')).writeAsString(content);
  }

  static Future<void> _createIndexPage(String projectName, String targetDir) async {
    final content = '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../components/welcome_card.dart';

class IndexPage extends StatelessComponent {
  const IndexPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-12', [
      // Hero section
      div(classes: 'text-center py-16', [
        h1(classes: 'text-5xl font-bold text-gray-900 mb-4', [
          text('Welcome to $projectName'),
        ]),
        p(classes: 'text-xl text-gray-600 mb-8', [
          text('Built with Duxt - The Nuxt-like framework for Jaspr'),
        ]),
        div(classes: 'flex justify-center gap-4', [
          a(
            href: 'https://github.com/example/duxt',
            classes: 'px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors',
            [text('Get Started')],
          ),
          a(
            href: '/about',
            classes: 'px-6 py-3 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors',
            [text('Learn More')],
          ),
        ]),
      ]),
      // Features
      div(classes: 'grid grid-cols-1 md:grid-cols-3 gap-6', [
        WelcomeCard(
          title: 'File-based Routing',
          description: 'Automatic routes from your pages/ directory',
          icon: '📁',
        ),
        WelcomeCard(
          title: 'Layouts System',
          description: 'Reusable layouts for consistent UI',
          icon: '🎨',
        ),
        WelcomeCard(
          title: 'API Routes',
          description: 'Server endpoints in server/api/',
          icon: '⚡',
        ),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'pages', 'index.dart')).writeAsString(content);
  }

  static Future<void> _createAboutPage(String targetDir) async {
    final content = r'''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class AboutPage extends StatelessComponent {
  const AboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'max-w-3xl mx-auto', [
      h1(classes: 'text-4xl font-bold text-gray-900 mb-6', [
        text('About'),
      ]),
      div(classes: 'prose prose-lg', [
        p(classes: 'text-gray-600 mb-4', [
          text(
            'Duxt is a meta-framework for Jaspr that brings Nuxt-like conventions '
            'to Dart web development. It provides file-based routing, layouts, '
            'middleware, and server API routes out of the box.',
          ),
        ]),
        h2(classes: 'text-2xl font-semibold text-gray-900 mt-8 mb-4', [
          text('Features'),
        ]),
        ul(classes: 'list-disc list-inside space-y-2 text-gray-600', [
          li([text('File-based routing from pages/ directory')]),
          li([text('Layouts system for reusable UI wrappers')]),
          li([text('Middleware for route guards and authentication')]),
          li([text('Server API routes in server/api/')]),
          li([text('Composables for shared reactive logic')]),
          li([text('Auto-imports for components')]),
          li([text('Tailwind CSS integration')]),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'pages', 'about.dart')).writeAsString(content);
  }

  static Future<void> _createExampleMiddleware(String targetDir) async {
    final content = '''
import 'package:duxt/duxt.dart';

/// Example authentication middleware
/// Place in middleware/ directory
class AuthMiddleware extends DuxtMiddleware {
  @override
  String get name => 'auth';

  @override
  Future<bool> handle(DuxtContext context, Future<void> Function() next) async {
    // Check if user is authenticated
    final isAuthenticated = context.state['isAuthenticated'] ?? false;

    if (!isAuthenticated) {
      // Redirect to login page
      context.redirect('/login');
      return false;
    }

    // Continue to the route
    await next();
    return true;
  }
}
''';
    await File(p.join(targetDir, 'middleware', 'auth.dart')).writeAsString(content);
  }

  static Future<void> _createExampleComposable(String targetDir) async {
    final content = '''
import 'package:duxt/duxt.dart';

/// Example counter composable
/// Demonstrates reactive state management
class UseCounter {
  final UseState<int> _count;

  UseCounter([int initial = 0]) : _count = UseState(initial);

  int get count => _count.value;

  void increment() {
    _count.value++;
  }

  void decrement() {
    _count.value--;
  }

  void reset() {
    _count.value = 0;
  }

  void listen(void Function(int) listener) {
    _count.listen(listener);
  }
}

/// Example: Using in a component
/// ```dart
/// final counter = UseCounter();
/// counter.increment();
/// print(counter.count); // 1
/// ```
''';
    await File(p.join(targetDir, 'composables', 'counter.dart')).writeAsString(content);
  }

  static Future<void> _createExampleApiRoute(String targetDir) async {
    final content = r'''
import 'package:duxt/server.dart';

/// Example API route handler
/// Accessible at /api/hello
///
/// Similar to Nuxt's server/api routes

final handler = defineEventHandler((request) async {
  final name = getQueryParam(request, 'name') ?? 'World';

  return ApiResponse.json({
    'message': 'Hello, $name!',
    'timestamp': DateTime.now().toIso8601String(),
  });
});

/// For more complex handlers, extend ApiHandler:
/// ```dart
/// class HelloHandler extends ApiHandler {
///   @override
///   Future<ApiResponse> get(ApiRequest request) async {
///     return ApiResponse.json({'message': 'Hello!'});
///   }
///
///   @override
///   Future<ApiResponse> post(ApiRequest request) async {
///     final body = await readBody(request);
///     return ApiResponse.created(body);
///   }
/// }
/// ```
''';
    await File(p.join(targetDir, 'server', 'api', 'hello.dart')).writeAsString(content);
  }

  static Future<void> _createExampleComponent(String targetDir) async {
    final content = r'''
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Reusable card component
/// Components in components/ are auto-imported (coming soon)
class WelcomeCard extends StatelessComponent {
  final String title;
  final String description;
  final String icon;

  const WelcomeCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = '✨',
  });

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'p-6 bg-white rounded-xl shadow-sm border hover:shadow-md transition-shadow',
      [
        div(classes: 'text-4xl mb-4', [text(icon)]),
        h3(classes: 'text-xl font-semibold text-gray-900 mb-2', [text(title)]),
        p(classes: 'text-gray-600', [text(description)]),
      ],
    );
  }
}
''';
    await File(p.join(targetDir, 'lib', 'components', 'welcome_card.dart')).writeAsString(content);
  }

  static Future<void> _createTailwindStyles(String targetDir) async {
    final content = '''
@import "tailwindcss";

@theme {
  --color-primary: #4f46e5;
  --color-secondary: #7c3aed;
}

/* Custom base styles */
@layer base {
  html {
    font-family: system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
}

/* Custom component styles */
@layer components {
  .btn {
    @apply px-4 py-2 rounded-lg font-medium transition-colors;
  }

  .btn-primary {
    @apply bg-indigo-600 text-white hover:bg-indigo-700;
  }

  .btn-secondary {
    @apply bg-gray-200 text-gray-800 hover:bg-gray-300;
  }
}
''';
    await File(p.join(targetDir, 'web', 'styles.tw.css')).writeAsString(content);
  }

  static Future<void> _createIndexHtml(String projectName, String targetDir) async {
    final content = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$projectName</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <script src="/main.client.dart.js" defer></script>
</body>
</html>
''';
    await File(p.join(targetDir, 'web', 'index.html')).writeAsString(content);
  }
}
