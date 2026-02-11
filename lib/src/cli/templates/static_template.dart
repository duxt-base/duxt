import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'web.dart';

/// Static template (SSG) - Marketing sites, landing pages, docs.
/// Pre-rendered at build time. No ORM, no server API.
class StaticTemplate {
  static Future<void> generate(String projectName, String targetDir) async {
    await _createDirectories(targetDir);
    await _writeFiles(projectName, targetDir);
    _printSuccess(projectName);
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/.generated',
      'lib/home/pages',
      'lib/about/pages',
      'lib/shared/layouts',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _staticPubspec(projectName));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, 'duxt.config.dart', _staticConfig(projectName));
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _staticAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    await _write(dir, 'lib/main.server.dart', mainServerTemplate(projectName));

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _staticLayoutTemplate(projectName));

    // Home page
    await _write(dir, 'lib/home/pages/index.dart', _staticHomeTemplate(projectName));

    // About page
    await _write(dir, 'lib/about/pages/index.dart', _staticAboutTemplate);

    // Web
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));
  }

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created static project');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart     → /');
    print('    ├── about/pages/index.dart    → /about');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart    (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                      Start dev server');
    print('');
    print('  \x1B[36mBuild:\x1B[0m');
    print('    duxt build                    Pre-render all pages');
    print('');
    print('  \x1B[36mAdd a new page:\x1B[0m');
    print('    duxt g page pricing/index     Creates /pricing');
    print('');
  }
}

/// Static pubspec - no ORM, no server deps
String _staticPubspec(String projectName) => '''
name: $projectName
description: A Duxt project
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  jaspr:
  jaspr_router:
  duxt:
  duxt_html:
  duxt_ui:

dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: static
''';

/// Static config
String _staticConfig(String projectName) => '''
/// Duxt application configuration.
///
/// Central config file for your Duxt project. All application settings
/// live here: app metadata, rendering mode, API base, and server port.
/// Values use String.fromEnvironment so you can set defaults for
/// development and override via environment variables in production.
///
/// Usage: import this file and access DuxtConfig.* anywhere in your app.
/// Docs: https://duxt.dev/duxt/configuration
class DuxtConfig {
  static const app = (
    name: '$projectName',
    description: 'A Duxt application',
  );

  /// Rendering mode: 'static', 'server', 'client'
  static const String mode = 'static';

  /// API base URL
  static const String apiBase = '/api';

  /// Development server port
  static const int port = 3000;

  // ── Database (uncomment when adding duxt_orm) ──────────────────────
  // Add duxt_orm to pubspec.yaml, then uncomment below and call:
  //   await DuxtOrm.init(DuxtConfig.database);
  //
  // static const database = (
  //   driver: String.fromEnvironment('DB_DRIVER', defaultValue: 'sqlite'),
  //   host: String.fromEnvironment('DB_HOST', defaultValue: 'localhost'),
  //   port: int.fromEnvironment('DB_PORT', defaultValue: 5432),
  //   database: String.fromEnvironment('DB_NAME', defaultValue: '$projectName'),
  //   username: String.fromEnvironment('DB_USER', defaultValue: ''),
  //   password: String.fromEnvironment('DB_PASS', defaultValue: ''),
  //   path: String.fromEnvironment('DB_PATH', defaultValue: 'data/$projectName.db'),
  //   ssl: bool.fromEnvironment('DB_SSL', defaultValue: false),
  // );
}
''';

/// Static app template
const _staticAppTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt/duxt.dart';

import '.generated/routes.dart' as generated;
import 'shared/layouts/default.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    final routes = generated.generatedRoutes;

    final wrappedRoutes = routes.map((route) => Route(
      path: route.path,
      builder: (context, state) => DefaultLayout(
        child: Builder(builder: (ctx) => route.builder!(ctx, state)),
      ),
    )).toList();

    return Router(
      routes: wrappedRoutes,
      errorBuilder: DuxtErrorPage.routerErrorBuilder,
    );
  }
}
''';

/// Static layout using duxt_html
String _staticLayoutTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_html/duxt_html.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return Div(
      className: 'min-h-screen bg-gray-950 flex flex-col',
      children: [
        Header(
          className: 'sticky top-0 z-50 bg-gray-900/95 backdrop-blur border-b border-gray-800',
          child: Div(
            className: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8',
            child: Div(
              className: 'flex h-16 items-center justify-between',
              children: [
                Link(
                  to: '/',
                  child: Span(
                    className: 'text-xl font-bold text-white',
                    child: Text('$projectName'),
                  ),
                ),
                Nav(
                  className: 'flex items-center gap-6',
                  children: [
                    Link(
                      to: '/',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('Home'),
                      ),
                    ),
                    Link(
                      to: '/about',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('About'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Div(className: 'flex-1', child: child),
        Footer(
          className: 'bg-gray-900 border-t border-gray-800 py-8',
          child: Div(
            className: 'max-w-7xl mx-auto px-4 text-center text-gray-400 text-sm',
            child: Text('Built with Duxt'),
          ),
        ),
      ],
    );
  }
}
''';

/// Static home page with hero, features grid, CTA
String _staticHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_ui/duxt_ui.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return Div(
      children: [
        // Hero section
        Section(
          className: 'pt-24 pb-20 px-4',
          child: Div(
            className: 'max-w-5xl mx-auto text-center',
            children: [
              Span(
                className: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-cyan-400 bg-cyan-500/10 rounded-full',
                child: Text('Welcome to Duxt'),
              ),
              H1(
                className: 'text-5xl md:text-7xl font-bold text-white mb-6 leading-tight',
                children: [
                  Text('Build something '),
                  Span(
                    className: 'text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500',
                    child: Text('amazing'),
                  ),
                ],
              ),
              P(
                className: 'text-xl text-gray-400 mb-10 max-w-2xl mx-auto',
                child: Text('The fullstack Dart framework for building modern web applications. Fast, type-safe, and productive.'),
              ),
              Div(
                className: 'flex flex-col sm:flex-row justify-center gap-4',
                children: [
                  A(
                    href: 'https://duxt.dev/duxt',
                    target: Target.blank,
                    className: 'px-8 py-4 bg-cyan-600 text-white font-medium rounded-lg hover:bg-cyan-700 transition-colors',
                    child: Text('Get Started'),
                  ),
                  A(
                    href: '/about',
                    className: 'px-8 py-4 border border-gray-700 text-white font-medium rounded-lg hover:bg-gray-800 transition-colors',
                    child: Text('Learn More'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Features section
        Section(
          className: 'py-20 px-4 bg-gray-900/50',
          child: Div(
            className: 'max-w-7xl mx-auto',
            children: [
              Div(
                className: 'text-center mb-16',
                children: [
                  H2(
                    className: 'text-4xl font-bold text-white mb-4',
                    child: Text('Everything you need'),
                  ),
                  P(
                    className: 'text-xl text-gray-400',
                    child: Text('Powerful features to help you build faster'),
                  ),
                ],
              ),
              Div(
                className: 'grid md:grid-cols-3 gap-8',
                children: [
                  _featureCard(
                    title: 'File-Based Routing',
                    description: 'Drop a file in pages/ and get a route. Dynamic params, nested layouts, and catch-all routes built in.',
                  ),
                  _featureCard(
                    title: 'Type-Safe ORM',
                    description: 'ActiveRecord-style database operations with relations, migrations, and query building.',
                  ),
                  _featureCard(
                    title: 'Flutter-Style UI',
                    description: 'Build HTML with familiar widget patterns using duxt_html. PascalCase, child/children, className.',
                  ),
                ],
              ),
            ],
          ),
        ),

        // CTA section
        Section(
          className: 'py-20 px-4',
          child: Div(
            className: 'max-w-4xl mx-auto',
            child: Div(
              className: 'p-12 bg-gradient-to-br from-cyan-900/50 to-blue-900/50 rounded-3xl border border-cyan-800/50 text-center',
              children: [
                H2(
                  className: 'text-4xl font-bold text-white mb-4',
                  child: Text('Ready to get started?'),
                ),
                P(
                  className: 'text-xl text-gray-300 mb-8',
                  child: Text('Start building your next project with Duxt.'),
                ),
                A(
                  href: 'https://duxt.dev/duxt',
                  target: Target.blank,
                  className: 'px-8 py-4 bg-white text-gray-900 font-medium rounded-lg hover:bg-gray-100 transition-colors inline-block',
                  child: Text('Read the Docs'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Component _featureCard({required String title, required String description}) {
    return Div(
      className: 'p-8 bg-gray-800/50 rounded-2xl border border-gray-700',
      children: [
        H3(
          className: 'text-xl font-semibold text-white mb-3',
          child: Text(title),
        ),
        P(
          className: 'text-gray-400',
          child: Text(description),
        ),
      ],
    );
  }
}
''';

/// Static about page
const _staticAboutTemplate = r'''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_ui/duxt_ui.dart';

class AboutPage extends StatelessComponent {
  const AboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return Div(
      className: 'min-h-screen flex items-center justify-center px-4',
      child: Div(
        className: 'max-w-2xl mx-auto text-center',
        children: [
          DBadge(label: 'About', color: DBadgeColor.primary),
          H1(
            className: 'text-4xl font-bold text-white mt-6 mb-6',
            child: Text('About this app'),
          ),
          P(
            className: 'text-lg text-gray-400 mb-8',
            child: Text('This is a Duxt application. Edit at lib/about/pages/index.dart'),
          ),
          Div(
            className: 'flex justify-center gap-4',
            children: [
              DButton(label: 'Learn More', color: DButtonColor.primary),
              DButton(label: 'Contact', variant: DButtonVariant.outline, color: DButtonColor.neutral),
            ],
          ),
        ],
      ),
    );
  }
}
''';
