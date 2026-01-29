import 'dart:io';
import 'package:path/path.dart' as p;

/// Generates a new Duxt project from template
class TemplateGenerator {
  /// Generate a new project with module-based structure
  static Future<void> generate(String projectName, String targetDir) async {
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

    // Shared
    await _createDefaultLayout(targetDir);

    // Home module
    await _createHomeModule(dartName, targetDir);

    // About module
    await _createAboutModule(targetDir);

    // Web files
    await _createTailwindStyles(targetDir);
    await _createIndexHtml(dartName, targetDir);

    print('');
    print('  \x1B[32m✓\x1B[0m Created project structure');
    print('');
    print('  lib/');
    print('    ├── home/');
    print('    │   ├── pages/index.dart');
    print('    │   └── components/welcome_card.dart');
    print('    ├── about/');
    print('    │   └── pages/index.dart');
    print('    ├── shared/');
    print('    │   └── layouts/default.dart');
    print('    └── app.dart');
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/home/pages',
      'lib/home/components',
      'lib/about/pages',
      'lib/shared/components',
      'lib/shared/layouts',
      'server/api',
      'web',
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
class DuxtConfig {
  static const app = (
    name: '$projectName',
    description: 'A Duxt application',
  );

  /// Rendering mode: 'spa', 'ssr', 'static'
  static const String mode = 'spa';

  /// API base URL
  static const String apiBase = '/api';

  /// Development server port
  static const int port = 3000;
}
''';
    await File(p.join(targetDir, 'duxt.config.dart')).writeAsString(content);
  }

  static Future<void> _createMainFile(String targetDir) async {
    final content = r'''
import 'package:jaspr/client.dart';
import 'package:duxt/duxt.dart';
import 'app.dart';

void main() {
  // Configure API
  Api.configure(baseUrl: '/api');

  runApp(App());
}
''';
    await File(p.join(targetDir, 'lib', 'main.client.dart')).writeAsString(content);
  }

  static Future<void> _createAppFile(String projectName, String targetDir) async {
    final content = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';

// Modules
import 'home/pages/index.dart';
import 'about/pages/index.dart';

// Shared
import 'shared/layouts/default.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Router(routes: [
      ShellRoute(
        builder: (context, state, child) => DefaultLayout(child: child),
        routes: [
          // Home module
          Route(
            path: '/',
            title: 'Home',
            builder: (context, state) => const HomePage(),
          ),
          // About module
          Route(
            path: '/about',
            title: 'About',
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'app.dart')).writeAsString(content);
  }

  static Future<void> _createDefaultLayout(String targetDir) async {
    final content = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
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
          Link(
            to: '/',
            child: span(classes: 'text-xl font-bold text-indigo-600', [text('Duxt')]),
          ),
          div(classes: 'flex gap-6', [
            Link(
              to: '/',
              child: span(classes: 'text-gray-600 hover:text-indigo-600', [text('Home')]),
            ),
            Link(
              to: '/about',
              child: span(classes: 'text-gray-600 hover:text-indigo-600', [text('About')]),
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
          text('Built with Duxt'),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'shared', 'layouts', 'default.dart')).writeAsString(content);
  }

  static Future<void> _createHomeModule(String projectName, String targetDir) async {
    // Home page
    final pageContent = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../components/welcome_card.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'space-y-12', [
      // Hero
      div(classes: 'text-center py-16', [
        h1(classes: 'text-5xl font-bold text-gray-900 mb-4', [
          text('Welcome to $projectName'),
        ]),
        p(classes: 'text-xl text-gray-600 mb-8', [
          text('Built with Duxt - The modern framework for Jaspr'),
        ]),
        div(classes: 'flex justify-center gap-4', [
          a(
            href: 'https://github.com/base-al/duxt',
            classes: 'px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700',
            [text('Get Started')],
          ),
        ]),
      ]),
      // Features
      div(classes: 'grid grid-cols-1 md:grid-cols-3 gap-6', [
        WelcomeCard(
          title: 'Module-Based',
          description: 'Organize code by feature with pages, components, and api per module',
          icon: '📦',
        ),
        WelcomeCard(
          title: 'Simple API',
          description: 'Static Api class for clean HTTP calls',
          icon: '🔌',
        ),
        WelcomeCard(
          title: 'Opinionated',
          description: 'Conventions over configuration',
          icon: '🛤️',
        ),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'home', 'pages', 'index.dart')).writeAsString(pageContent);

    // Welcome card component
    final componentContent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

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
    await File(p.join(targetDir, 'lib', 'home', 'components', 'welcome_card.dart')).writeAsString(componentContent);
  }

  static Future<void> _createAboutModule(String targetDir) async {
    final content = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

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
            'Duxt is a meta-framework for Jaspr that brings modern conventions '
            'to Dart web development.',
          ),
        ]),
        h2(classes: 'text-2xl font-semibold text-gray-900 mt-8 mb-4', [
          text('Features'),
        ]),
        ul(classes: 'list-disc list-inside space-y-2 text-gray-600', [
          li([text('Module-based architecture')]),
          li([text('Simple static Api class')]),
          li([text('DuxtState mixin for SPA data loading')]),
          li([text('Convention over configuration')]),
          li([text('Tailwind CSS integration')]),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'about', 'pages', 'index.dart')).writeAsString(content);
  }

  static Future<void> _createTailwindStyles(String targetDir) async {
    final content = '''
@import "tailwindcss";

@theme {
  --color-primary: #4f46e5;
}

@layer base {
  html {
    font-family: system-ui, sans-serif;
  }
}

@layer components {
  .btn {
    @apply px-4 py-2 rounded-lg font-medium transition-colors;
  }
  .btn-primary {
    @apply bg-indigo-600 text-white hover:bg-indigo-700;
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
