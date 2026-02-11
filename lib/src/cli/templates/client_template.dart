import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'web.dart';

/// Client template (SPA) - Interactive single-page apps.
/// Client-side rendering with signals. No ORM, no server API.
class ClientTemplate {
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
      'lib/demo/pages',
      'lib/shared/layouts',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _clientPubspec(projectName));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, 'duxt.config.dart', _clientConfig(projectName));
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _clientAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    await _write(dir, 'lib/main.server.dart', mainServerTemplate(projectName));

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _clientLayoutTemplate(projectName));

    // Home page with reactive counter
    await _write(dir, 'lib/home/pages/index.dart', _clientHomeTemplate(projectName));

    // Demo page with form validation
    await _write(dir, 'lib/demo/pages/index.dart', _clientDemoTemplate);

    // Web
    await _write(dir, 'web/index.html', indexHtmlTemplate(projectName));
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));
  }

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created client project with duxt_signals');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart     → / (reactive counter)');
    print('    ├── demo/pages/index.dart     → /demo (form validation)');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart    (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  \x1B[36mFeatures:\x1B[0m');
    print('    - Reactive signals (signal, computed, effect)');
    print('    - Auto-tracking with SignalState');
    print('    - Form validation with formField');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                      Start dev server');
    print('');
  }
}

/// Client pubspec - includes duxt_signals, no ORM
String _clientPubspec(String projectName) => '''
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
  duxt_signals:

dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: client
''';

/// Client config
String _clientConfig(String projectName) => '''
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
  static const String mode = 'client';

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

/// Client app template
const _clientAppTemplate = r'''
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

/// Client layout using duxt_html
String _clientLayoutTemplate(String projectName) => '''
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
                      to: '/demo',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('Demo'),
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

/// Client home page with reactive counter
String _clientHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_signals/duxt_signals.dart';

final _count = signal(0);
final _doubleCount = computed(() => _count() * 2);

@client
class HomePage extends StatefulComponent {
  const HomePage({super.key});

  @override
  State createState() => _HomePageState();
}

class _HomePageState extends SignalState<HomePage> {
  @override
  Component buildComponent(BuildContext context) {
    return Div(
      className: 'py-20 px-4',
      child: Div(
        className: 'max-w-3xl mx-auto text-center',
        children: [
          Span(
            className: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-emerald-400 bg-emerald-500/10 rounded-full',
            child: Text('Client-Side Rendering'),
          ),
          H1(
            className: 'text-5xl font-bold text-white mb-6',
            child: Text('$projectName'),
          ),
          P(
            className: 'text-xl text-gray-400 mb-12',
            child: Text('Interactive SPA with reactive signals'),
          ),

          // Counter card
          Div(
            className: 'max-w-md mx-auto rounded-xl p-8 bg-gray-900 border border-gray-800',
            children: [
              H2(
                className: 'text-xl font-bold text-white mb-2',
                child: Text('Reactive Counter'),
              ),
              P(
                className: 'text-sm text-gray-400 mb-6',
                child: Text('Using signal() and computed()'),
              ),
              Div(
                className: 'flex items-center justify-center gap-4 mb-4',
                children: [
                  Button(
                    onClick: () => _count.update((v) => v - 1),
                    className: 'w-12 h-12 rounded-full text-xl font-bold bg-red-600 text-white hover:bg-red-700 transition-colors',
                    child: Text('−'),
                  ),
                  Span(
                    className: 'text-5xl font-bold text-white w-20 text-center',
                    child: Text('\${_count()}'),
                  ),
                  Button(
                    onClick: () => _count.update((v) => v + 1),
                    className: 'w-12 h-12 rounded-full text-xl font-bold bg-emerald-600 text-white hover:bg-emerald-700 transition-colors',
                    child: Text('+'),
                  ),
                ],
              ),
              Div(
                className: 'text-gray-400 mb-4',
                child: Text('Double: \${_doubleCount()}'),
              ),
              Button(
                onClick: () => _count.set(0),
                className: 'text-sm text-gray-500 hover:text-gray-300 transition-colors',
                child: Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
''';

/// Client demo page with form validation
const _clientDemoTemplate = r'''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_signals/duxt_signals.dart';

final _nameField = formField('', validators: [
  required('Name is required'),
]);

final _emailField = formField('', validators: [
  required('Email is required'),
]);

final _messageField = formField('', validators: [
  required('Message is required'),
]);

final _submitted = signal(false);

@client
class DemoPage extends StatefulComponent {
  const DemoPage({super.key});

  @override
  State createState() => _DemoPageState();
}

class _DemoPageState extends SignalState<DemoPage> {
  @override
  Component buildComponent(BuildContext context) {
    return Div(
      className: 'py-12 px-4',
      child: Div(
        className: 'max-w-lg mx-auto',
        children: [
          Div(
            className: 'text-center mb-8',
            children: [
              H1(
                className: 'text-4xl font-bold text-white mb-4',
                child: Text('Form Validation'),
              ),
              P(
                className: 'text-gray-400',
                child: Text('Using formField() with built-in validators'),
              ),
            ],
          ),
          Div(
            className: 'rounded-xl p-6 bg-gray-900 border border-gray-800',
            children: [
              if (_submitted())
                _successMessage()
              else
                _formContent(),
            ],
          ),
        ],
      ),
    );
  }

  Component _successMessage() {
    return Div(
      className: 'text-center py-8',
      children: [
        Div(
          className: 'text-4xl mb-4',
          child: Text('✓'),
        ),
        H2(
          className: 'text-2xl font-bold text-emerald-400 mb-2',
          child: Text('Message Sent!'),
        ),
        P(
          className: 'text-gray-400 mb-6',
          child: Text('Thanks for reaching out.'),
        ),
        Button(
          onClick: () {
            _nameField.reset();
            _emailField.reset();
            _messageField.reset();
            _submitted.set(false);
          },
          className: 'px-4 py-2 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors',
          child: Text('Send Another'),
        ),
      ],
    );
  }

  Component _formContent() {
    return Div(
      className: 'space-y-4',
      children: [
        _field(
          label: 'Name',
          value: _nameField(),
          placeholder: 'Your name',
          onInput: (v) => _nameField.set(v),
          onBlur: () => _nameField.touch(),
          hasError: _nameField.touched && _nameField.hasError,
          errorText: _nameField.error,
        ),
        _field(
          label: 'Email',
          value: _emailField(),
          placeholder: 'your@email.com',
          type: 'email',
          onInput: (v) => _emailField.set(v),
          onBlur: () => _emailField.touch(),
          hasError: _emailField.touched && _emailField.hasError,
          errorText: _emailField.error,
        ),
        Div(
          children: [
            Label(
              className: 'block text-sm font-medium text-gray-300 mb-1',
              child: Text('Message'),
            ),
            Textarea(
              name: 'message',
              placeholder: 'Your message...',
              rows: 4,
              onInput: (v) => _messageField.set(v),
              events: {'blur': (_) => _messageField.touch()},
              className: 'w-full px-3 py-2 bg-gray-800 border ${_messageField.touched && _messageField.hasError ? "border-red-500" : "border-gray-700"} rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
            ),
            if (_messageField.touched && _messageField.hasError)
              Div(
                className: 'mt-1 text-sm text-red-400',
                child: Text(_messageField.error ?? ''),
              ),
          ],
        ),
        Div(
          className: 'flex items-center justify-between pt-2',
          children: [
            Button(
              onClick: () {
                _nameField.touch();
                _emailField.touch();
                _messageField.touch();
                if (_nameField.isValid && _emailField.isValid && _messageField.isValid) {
                  _submitted.set(true);
                }
              },
              className: 'px-6 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors font-medium',
              child: Text('Submit'),
            ),
            Button(
              onClick: () {
                _nameField.reset();
                _emailField.reset();
                _messageField.reset();
              },
              className: 'text-sm text-gray-500 hover:text-gray-300 transition-colors',
              child: Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }

  Component _field({
    required String label,
    required String value,
    required String placeholder,
    String type = 'text',
    required void Function(String) onInput,
    required void Function() onBlur,
    required bool hasError,
    String? errorText,
  }) {
    return Div(
      children: [
        Label(
          className: 'block text-sm font-medium text-gray-300 mb-1',
          child: Text(label),
        ),
        Input(
          type: type,
          value: value,
          placeholder: placeholder,
          onInput: onInput,
          events: {'blur': (_) => onBlur()},
          className: 'w-full px-3 py-2 bg-gray-800 border ${hasError ? "border-red-500" : "border-gray-700"} rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
        ),
        if (hasError)
          Div(
            className: 'mt-1 text-sm text-red-400',
            child: Text(errorText ?? ''),
          ),
      ],
    );
  }
}
''';
