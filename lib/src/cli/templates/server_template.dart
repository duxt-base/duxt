import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'server.dart';
import 'web.dart';

/// Server template (SSR) - Dynamic apps, blog, content sites.
/// Server-rendered with ORM + API.
class ServerTemplate {
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
      'lib/shared/layouts',
      'server',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _serverPubspec(projectName));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, 'duxt.config.dart', _serverConfig(projectName));
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _serverAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    await _write(dir, 'lib/main.server.dart', _mainServerDartTemplate(projectName));

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _serverLayoutTemplate(projectName));

    // Home page
    await _write(dir, 'lib/home/pages/index.dart', _serverHomeTemplate(projectName));

    // Server
    await _write(dir, 'server/main.dart', _serverMainTemplate(projectName));

    // Web
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));

    // Environment sample
    await _write(dir, '.env.sample', envSampleTemplate);

    // Docker
    await _write(dir, 'Dockerfile', dockerfileTemplate);
    await _write(dir, '.dockerignore', dockerignoreTemplate);
    await _write(dir, 'docker-compose.yml', dockerComposeTemplate);
  }

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created server project');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart       → /');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart      (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  server/');
    print('    └── main.dart                   API server');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                        Start dev server');
    print('');
    print('  \x1B[36mProduction:\x1B[0m');
    print('    duxt build && docker build -t $projectName .');
    print('');
  }
}

/// Server pubspec - includes ORM + sqlite
String _serverPubspec(String projectName) => '''
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
  duxt_orm:
  sqlite3:

dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: server
''';

/// Server config
String _serverConfig(String projectName) => '''
/// Duxt application configuration.
///
/// Central config file for your Duxt project. All application settings
/// live here: app metadata, rendering mode, API base, server port, and
/// database connection. Values use String.fromEnvironment so you can
/// set defaults for development and override via environment variables
/// in production.
///
/// Usage: import this file and access DuxtConfig.* anywhere in your app.
/// Docs: https://duxt.dev/duxt/configuration
class DuxtConfig {
  static const app = (
    name: '$projectName',
    description: 'A Duxt application',
  );

  /// Rendering mode: 'static', 'server', 'client'
  static const String mode = 'server';

  /// API base URL
  static const String apiBase = '/api';

  /// Development server port
  static const int port = 3000;

  /// Database configuration — passed to DuxtOrm.init(DuxtConfig.database).
  /// Defaults to SQLite. Set environment variables to switch:
  ///
  /// MySQL:
  ///   DB_DRIVER=mysql DB_HOST=localhost DB_PORT=3306 DB_NAME=$projectName DB_USER=root DB_PASS=secret duxt dev
  ///
  /// PostgreSQL:
  ///   DB_DRIVER=postgres DB_HOST=localhost DB_PORT=5432 DB_NAME=$projectName DB_USER=postgres DB_PASS=secret duxt dev
  static const database = (
    driver: String.fromEnvironment('DB_DRIVER', defaultValue: 'sqlite'),
    host: String.fromEnvironment('DB_HOST', defaultValue: 'localhost'),
    port: int.fromEnvironment('DB_PORT', defaultValue: 5432),
    database: String.fromEnvironment('DB_NAME', defaultValue: '$projectName'),
    username: String.fromEnvironment('DB_USER', defaultValue: ''),
    password: String.fromEnvironment('DB_PASS', defaultValue: ''),
    path: String.fromEnvironment('DB_PATH', defaultValue: 'data/$projectName.db'),
    ssl: bool.fromEnvironment('DB_SSL', defaultValue: false),
  );
}
''';

/// Server app template
const _serverAppTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt/duxt.dart';

import '.generated/routes.dart' as generated;
import 'shared/layouts/default.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Router(
      routes: generated.generatedRoutes.map((route) => Route(
        path: route.path,
        builder: (context, state) => DefaultLayout(
          child: Builder(builder: (ctx) => route.builder!(ctx, state)),
        ),
      )).toList(),
      errorBuilder: DuxtErrorPage.routerErrorBuilder,
    );
  }
}
''';

/// Server layout using duxt_html
String _serverLayoutTemplate(String projectName) => '''
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

/// Server home page
String _serverHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return Div(
      className: 'py-20 px-4',
      child: Div(
        className: 'max-w-3xl mx-auto text-center',
        children: [
          H1(
            className: 'text-5xl font-bold text-white mb-6',
            child: Text('$projectName'),
          ),
          P(
            className: 'text-xl text-gray-400',
            child: Text('Server-rendered with Duxt'),
          ),
        ],
      ),
    );
  }
}
''';

/// Server main.dart — API server with DuxtServer
String _serverMainTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt/server.dart';

void main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3001;

  final server = DuxtServer(
    port: port,
    middleware: [securityHeaders(), cors(origins: [\'http://localhost:4000\']), jsonBody(), logger()],
  );

  server.get('/api/health', (req) async {
    return json({\'status\': \'ok\'});
  });

  server.start();
}
''';

/// main.server.dart — Jaspr SSR entry point
String _mainServerDartTemplate(String projectName) => '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:duxt/duxt.dart';
import 'app.dart';

import 'main.server.options.dart';

void main() async {
  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: '$projectName',
    head: [
      link(href: '/styles.css', rel: 'stylesheet'),
    ],
    body: App(),
  ));
}
''';
