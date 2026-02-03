import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'web.dart';

/// Minimal template - clean starting point
class MinimalTemplate {
  static Future<void> generate(String projectName, String targetDir, {String mode = 'static'}) async {
    await _createDirectories(targetDir);
    await _writeFiles(projectName, targetDir, mode: mode);
    _printSuccess(projectName);
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/.generated',
      'lib/home/pages',
      'lib/shared/layouts',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir, {required String mode}) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _minimalPubspec(projectName, mode: mode));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _minimalAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    if (mode == 'static' || mode == 'server') {
      await _write(dir, 'lib/main.server.dart', mainServerTemplate(projectName));
    }

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _minimalLayoutTemplate);

    // Home module
    await _write(dir, 'lib/home/pages/index.dart', _minimalHomeTemplate(projectName));

    // Web
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));
  }

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created minimal project');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart    → /');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart   (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                     Start dev server');
    print('');
    print('  \x1B[36mAdd a new page:\x1B[0m');
    print('    duxt g page about/index      Creates /about');
    print('');
  }
}

/// Minimal pubspec without server dependencies
String _minimalPubspec(String projectName, {String mode = 'static'}) => '''
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
  duxt_ui:

dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: $mode
''';

/// Minimal app without content routing
const _minimalAppTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

// Generated routes
import '.generated/routes.dart' as generated;

// Shared
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

    return Router(routes: wrappedRoutes);
  }
}
''';

/// Minimal layout
const _minimalLayoutTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gray-950 flex flex-col', [
      header(classes: 'bg-gray-900 border-b border-gray-800', [
        div(classes: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8', [
          div(classes: 'flex h-16 items-center justify-between', [
            Link(to: '/', child: span(classes: 'text-xl font-bold text-white', [Component.text('My App')])),
            nav(classes: 'flex items-center gap-6', [
              Link(to: '/', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Home')])),
              // Add more nav items as needed
            ]),
          ]),
        ]),
      ]),
      div(classes: 'flex-1', [child]),
      footer(classes: 'bg-gray-900 border-t border-gray-800 py-6', [
        div(classes: 'max-w-7xl mx-auto px-4 text-center text-gray-400 text-sm', [
          Component.text('Built with Duxt'),
        ]),
      ]),
    ]);
  }
}
''';

/// Minimal home page
String _minimalHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'py-20 px-4', [
      div(classes: 'max-w-3xl mx-auto text-center', [
        h1(classes: 'text-5xl font-bold text-white mb-6', [
          Component.text('Welcome to $projectName'),
        ]),
        p(classes: 'text-xl text-gray-400 mb-8', [
          Component.text('Your minimal Duxt project is ready. Start building!'),
        ]),
        div(classes: 'flex justify-center gap-4', [
          a(
            href: 'https://duxt.dev/docs',
            classes: 'px-6 py-3 bg-cyan-600 text-white rounded-lg hover:bg-cyan-700 transition-colors',
            [Component.text('Read the Docs')],
          ),
        ]),
      ]),
    ]);
  }
}
''';
