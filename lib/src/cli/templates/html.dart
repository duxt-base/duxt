import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'web.dart';

/// HTML template - showcases duxt_html Flutter-style components
class HtmlTemplate {
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
      'lib/demo/pages',
      'lib/signals/pages',
      'lib/shared/layouts',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir, {required String mode}) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _htmlPubspec(projectName, mode: mode));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _htmlAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    await _write(dir, 'lib/main.server.dart', mainServerTemplate(projectName));

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _htmlLayoutTemplate);

    // Home page
    await _write(dir, 'lib/home/pages/index.dart', _htmlHomeTemplate(projectName));

    // Demo page - showcases all duxt_html components
    await _write(dir, 'lib/demo/pages/index.dart', _htmlDemoTemplate);

    // Signals page - showcases duxt_signals
    await _write(dir, 'lib/signals/pages/index.dart', _htmlSignalsTemplate);

    // Web
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));
  }

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created html project with duxt_html + duxt_signals');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart    → /');
    print('    ├── demo/pages/index.dart    → /demo (all components)');
    print('    ├── signals/pages/index.dart → /signals (reactive state)');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart   (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  \x1B[36mFeatures:\x1B[0m');
    print('    • Flutter-style HTML components (Div, Span, Button...)');
    print('    • Reactive signals (signal, computed, effect)');
    print('    • Auto-tracking with SignalState');
    print('    • Form validation with formField');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                     Start dev server');
    print('');
  }
}

/// HTML template pubspec with duxt_html
String _htmlPubspec(String projectName, {String mode = 'static'}) => '''
name: $projectName
description: A Duxt project using duxt_html
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  jaspr:
  jaspr_router:
  duxt:
  duxt_html:
  duxt_signals:

dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: $mode
''';

/// HTML app template
const _htmlAppTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt/duxt.dart';

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

    return Router(
      routes: wrappedRoutes,
      errorBuilder: DuxtErrorPage.routerErrorBuilder,
    );
  }
}
''';

/// HTML layout using duxt_html
const _htmlLayoutTemplate = r'''
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
          className: 'bg-gray-900 border-b border-gray-800',
          child: Div(
            className: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8',
            child: Div(
              className: 'flex h-16 items-center justify-between',
              children: [
                Link(
                  to: '/',
                  child: Span(
                    className: 'text-xl font-bold text-white',
                    child: Text('duxt_html'),
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
                    Link(
                      to: '/signals',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('Signals'),
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
          className: 'bg-gray-900 border-t border-gray-800 py-6',
          child: Div(
            className: 'max-w-7xl mx-auto px-4 text-center text-gray-400 text-sm',
            child: Text('Built with duxt_html - Flutter-style HTML for Jaspr'),
          ),
        ),
      ],
    );
  }
}
''';

/// HTML home page
String _htmlHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_html/duxt_html.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return Div(
      className: 'py-20 px-4',
      child: Div(
        className: 'max-w-4xl mx-auto',
        children: [
          // Hero section
          Div(
            className: 'text-center mb-16',
            children: [
              Span(
                className: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-emerald-400 bg-emerald-500/10 rounded-full',
                child: Text('Flutter-style HTML'),
              ),
              H1(
                className: 'text-5xl font-bold text-white mb-6',
                child: Text('Welcome to $projectName'),
              ),
              P(
                className: 'text-xl text-gray-400 mb-8',
                child: Text('Build web UIs with familiar Flutter patterns using duxt_html'),
              ),
              Div(
                className: 'flex justify-center gap-4',
                children: [
                  Link(
                    to: '/demo',
                    child: Span(
                      className: 'px-6 py-3 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors inline-block',
                      child: Text('View Components'),
                    ),
                  ),
                  A(
                    href: 'https://github.com/duxt-dev/duxt_html',
                    target: Target.blank,
                    className: 'px-6 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-800 transition-colors',
                    child: Text('GitHub'),
                  ),
                ],
              ),
            ],
          ),

          // Comparison section
          Div(
            className: 'grid md:grid-cols-2 gap-8 mb-16',
            children: [
              _codeCard('Before (Jaspr)', \'''
div(classes: 'container', [
  p(classes: 'text', [
    text('Hello'),
  ]),
  button(onClick: () {}, [
    text('Click'),
  ]),
])\'''),
              _codeCard('After (duxt_html)', \'''
Div(
  className: 'container',
  children: [
    P(
      className: 'text',
      child: Text('Hello'),
    ),
    Button(
      onClick: () {},
      child: Text('Click'),
    ),
  ],
)\'''),
            ],
          ),

          // Features
          Div(
            className: 'grid md:grid-cols-3 gap-6',
            children: [
              _featureCard('PascalCase', 'Div, Span, Button - familiar naming'),
              _featureCard('child/children', 'Flutter-style composition'),
              _featureCard('className', 'Intuitive prop naming'),
            ],
          ),
        ],
      ),
    );
  }

  Component _codeCard(String title, String code) {
    return Div(
      className: 'bg-gray-900 rounded-lg overflow-hidden',
      children: [
        Div(
          className: 'px-4 py-2 bg-gray-800 border-b border-gray-700',
          child: Span(
            className: 'text-sm font-medium text-gray-300',
            child: Text(title),
          ),
        ),
        Pre(
          className: 'p-4 text-sm text-gray-300 overflow-x-auto',
          child: Code(child: Text(code)),
        ),
      ],
    );
  }

  Component _featureCard(String title, String description) {
    return Div(
      className: 'bg-gray-900 rounded-lg p-6 border border-gray-800',
      children: [
        H3(
          className: 'text-lg font-semibold text-white mb-2',
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

/// HTML demo page - showcases all duxt_html components
const _htmlDemoTemplate = r'''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';

@client
class DemoPage extends StatefulComponent {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  String _activeSection = 'content';

  @override
  Component build(BuildContext context) {
    return Div(
      className: 'py-12 px-4',
      child: Div(
        className: 'max-w-6xl mx-auto',
        children: [
          // Header
          Div(
            className: 'text-center mb-12',
            children: [
              H1(
                className: 'text-4xl font-bold text-white mb-4',
                child: Text('duxt_html Components'),
              ),
              P(
                className: 'text-gray-400',
                child: Text('All 80 Flutter-style HTML components'),
              ),
            ],
          ),

          // Navigation tabs
          Div(
            className: 'flex flex-wrap justify-center gap-2 mb-8',
            children: [
              _tab('content', 'Content'),
              _tab('text', 'Text'),
              _tab('headings', 'Headings'),
              _tab('forms', 'Forms'),
              _tab('table', 'Table'),
              _tab('media', 'Media'),
              _tab('semantic', 'Semantic'),
              _tab('svg', 'SVG'),
            ],
          ),

          // Content sections
          Div(
            className: 'bg-gray-900 rounded-lg p-6 border border-gray-800',
            children: [
              if (_activeSection == 'content') _contentSection(),
              if (_activeSection == 'text') _textSection(),
              if (_activeSection == 'headings') _headingsSection(),
              if (_activeSection == 'forms') _formsSection(),
              if (_activeSection == 'table') _tableSection(),
              if (_activeSection == 'media') _mediaSection(),
              if (_activeSection == 'semantic') _semanticSection(),
              if (_activeSection == 'svg') _svgSection(),
            ],
          ),
        ],
      ),
    );
  }

  Component _tab(String id, String label) {
    final isActive = _activeSection == id;
    return Button(
      onClick: () {
        setState(() {
          _activeSection = id;
        });
      },
      className: isActive
          ? 'px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium'
          : 'px-4 py-2 bg-gray-800 text-gray-300 rounded-lg text-sm font-medium hover:bg-gray-700',
      child: Text(label),
    );
  }

  Component _sectionTitle(String title) {
    return H2(
      className: 'text-2xl font-bold text-white mb-6',
      child: Text(title),
    );
  }

  Component _subsection(String title, Component content) {
    return Div(
      className: 'mb-8',
      children: [
        H3(
          className: 'text-lg font-semibold text-emerald-400 mb-4',
          child: Text(title),
        ),
        content,
      ],
    );
  }

  Component _componentLabel(String name) {
    return Span(
      className: 'inline-block px-2 py-1 bg-gray-800 text-emerald-400 text-xs font-mono rounded mr-2 mb-2',
      child: Text(name),
    );
  }

  // ============ CONTENT SECTION ============
  Component _contentSection() {
    return Div(
      children: [
        _sectionTitle('Content Elements'),

        _subsection('Div - Container', Div(
          className: 'p-4 bg-gray-800 rounded',
          child: Text('This is a Div container'),
        )),

        _subsection('P - Paragraph', P(
          className: 'text-gray-300',
          child: Text('This is a paragraph with some text content.'),
        )),

        _subsection('Ul / Ol / Li - Lists', Div(
          className: 'grid md:grid-cols-2 gap-4',
          children: [
            Div(children: [
              _componentLabel('Ul'),
              Ul(
                className: 'list-disc list-inside text-gray-300',
                children: [
                  Li(child: Text('Unordered item 1')),
                  Li(child: Text('Unordered item 2')),
                  Li(child: Text('Unordered item 3')),
                ],
              ),
            ]),
            Div(children: [
              _componentLabel('Ol'),
              Ol(
                className: 'list-decimal list-inside text-gray-300',
                children: [
                  Li(child: Text('Ordered item 1')),
                  Li(child: Text('Ordered item 2')),
                  Li(child: Text('Ordered item 3')),
                ],
              ),
            ]),
          ],
        )),

        _subsection('Dl / Dt / Dd - Description List', Dl(
          className: 'text-gray-300',
          children: [
            Dt(className: 'font-semibold text-white', child: Text('Term 1')),
            Dd(className: 'ml-4 mb-2', child: Text('Definition for term 1')),
            Dt(className: 'font-semibold text-white', child: Text('Term 2')),
            Dd(className: 'ml-4', child: Text('Definition for term 2')),
          ],
        )),

        _subsection('Blockquote', Blockquote(
          className: 'border-l-4 border-emerald-500 pl-4 italic text-gray-400',
          child: Text('This is a blockquote. It can contain meaningful quotes or citations.'),
        )),

        _subsection('Pre / Code', Pre(
          className: 'bg-gray-800 p-4 rounded text-sm overflow-x-auto',
          child: Code(
            className: 'text-emerald-400',
            child: Text('const greeting = "Hello, duxt_html!";'),
          ),
        )),

        _subsection('Hr - Horizontal Rule', Div(
          children: [
            P(className: 'text-gray-300 mb-4', child: Text('Content above the line')),
            Hr(className: 'border-gray-700'),
            P(className: 'text-gray-300 mt-4', child: Text('Content below the line')),
          ],
        )),
      ],
    );
  }

  // ============ TEXT SECTION ============
  Component _textSection() {
    return Div(
      children: [
        _sectionTitle('Text Elements'),

        _subsection('A - Anchor/Link', A(
          href: 'https://duxt.dev',
          target: Target.blank,
          className: 'text-emerald-400 hover:text-emerald-300 underline',
          child: Text('Visit duxt.dev'),
        )),

        _subsection('Span', Span(
          className: 'text-gray-300',
          child: Text('This is a span element for inline content'),
        )),

        _subsection('Text Formatting', Div(
          className: 'space-y-2 text-gray-300',
          children: [
            Div(children: [_componentLabel('Strong'), Strong(child: Text('Bold/Strong text'))]),
            Div(children: [_componentLabel('B'), B(child: Text('Bold text'))]),
            Div(children: [_componentLabel('Em'), Em(child: Text('Emphasized/Italic text'))]),
            Div(children: [_componentLabel('I'), I(child: Text('Italic text'))]),
            Div(children: [_componentLabel('U'), U(child: Text('Underlined text'))]),
            Div(children: [_componentLabel('S'), S(child: Text('Strikethrough text'))]),
            Div(children: [_componentLabel('Small'), Small(child: Text('Small text'))]),
            Div(children: [_componentLabel('Code'), Code(className: 'bg-gray-800 px-2 py-1 rounded', child: Text('inline code'))]),
          ],
        )),

        _subsection('Br - Line Break', P(
          className: 'text-gray-300',
          children: [
            Text('Line one'),
            Br(),
            Text('Line two after break'),
          ],
        )),
      ],
    );
  }

  // ============ HEADINGS SECTION ============
  Component _headingsSection() {
    return Div(
      children: [
        _sectionTitle('Heading Elements'),

        Div(
          className: 'space-y-4',
          children: [
            Div(children: [_componentLabel('H1'), H1(className: 'text-4xl font-bold text-white', child: Text('Heading 1'))]),
            Div(children: [_componentLabel('H2'), H2(className: 'text-3xl font-bold text-white', child: Text('Heading 2'))]),
            Div(children: [_componentLabel('H3'), H3(className: 'text-2xl font-bold text-white', child: Text('Heading 3'))]),
            Div(children: [_componentLabel('H4'), H4(className: 'text-xl font-bold text-white', child: Text('Heading 4'))]),
            Div(children: [_componentLabel('H5'), H5(className: 'text-lg font-bold text-white', child: Text('Heading 5'))]),
            Div(children: [_componentLabel('H6'), H6(className: 'text-base font-bold text-white', child: Text('Heading 6'))]),
          ],
        ),
      ],
    );
  }

  // ============ FORMS SECTION ============
  Component _formsSection() {
    return Div(
      children: [
        _sectionTitle('Form Elements'),

        _subsection('Form with Inputs', Form(
          className: 'space-y-4 max-w-md',
          children: [
            Div(children: [
              Label(
                htmlFor: 'name',
                className: 'block text-sm font-medium text-gray-300 mb-1',
                child: Text('Name'),
              ),
              Input(
                type: 'text',
                name: 'name',
                id: 'name',
                placeholder: 'Enter your name',
                className: 'w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
              ),
            ]),
            Div(children: [
              Label(
                htmlFor: 'email',
                className: 'block text-sm font-medium text-gray-300 mb-1',
                child: Text('Email'),
              ),
              Input(
                type: 'email',
                name: 'email',
                id: 'email',
                placeholder: 'Enter your email',
                className: 'w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
              ),
            ]),
            Div(children: [
              Label(
                htmlFor: 'message',
                className: 'block text-sm font-medium text-gray-300 mb-1',
                child: Text('Message'),
              ),
              Textarea(
                name: 'message',
                id: 'message',
                placeholder: 'Enter your message',
                rows: 4,
                className: 'w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
              ),
            ]),
          ],
        )),

        _subsection('Select / Option', Div(
          className: 'max-w-md',
          children: [
            Label(
              htmlFor: 'country',
              className: 'block text-sm font-medium text-gray-300 mb-1',
              child: Text('Country'),
            ),
            Select(
              name: 'country',
              id: 'country',
              className: 'w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:border-emerald-500',
              children: [
                Option(value: '', child: Text('Select a country')),
                Option(value: 'us', child: Text('United States')),
                Option(value: 'uk', child: Text('United Kingdom')),
                Option(value: 'de', child: Text('Germany')),
              ],
            ),
          ],
        )),

        _subsection('Button Types', Div(
          className: 'flex flex-wrap gap-3',
          children: [
            Button(
              type: 'button',
              className: 'px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700',
              child: Text('Button'),
            ),
            Button(
              type: 'submit',
              className: 'px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700',
              child: Text('Submit'),
            ),
            Button(
              type: 'reset',
              className: 'px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700',
              child: Text('Reset'),
            ),
          ],
        )),

        _subsection('Checkbox & Radio', Div(
          className: 'space-y-3',
          children: [
            Div(
              className: 'flex items-center gap-2',
              children: [
                Input(type: 'checkbox', name: 'agree', id: 'agree', className: 'w-4 h-4'),
                Label(htmlFor: 'agree', className: 'text-gray-300', child: Text('I agree to the terms')),
              ],
            ),
            Div(
              className: 'flex items-center gap-4',
              children: [
                Div(className: 'flex items-center gap-2', children: [
                  Input(type: 'radio', name: 'choice', id: 'choice1', value: '1', className: 'w-4 h-4'),
                  Label(htmlFor: 'choice1', className: 'text-gray-300', child: Text('Option 1')),
                ]),
                Div(className: 'flex items-center gap-2', children: [
                  Input(type: 'radio', name: 'choice', id: 'choice2', value: '2', className: 'w-4 h-4'),
                  Label(htmlFor: 'choice2', className: 'text-gray-300', child: Text('Option 2')),
                ]),
              ],
            ),
          ],
        )),

        _subsection('Fieldset & Legend', Fieldset(
          className: 'border border-gray-700 rounded-lg p-4',
          children: [
            Legend(className: 'px-2 text-gray-300 font-medium', child: Text('Personal Information')),
            Div(
              className: 'grid md:grid-cols-2 gap-4',
              children: [
                Input(type: 'text', placeholder: 'First name', className: 'px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white'),
                Input(type: 'text', placeholder: 'Last name', className: 'px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white'),
              ],
            ),
          ],
        )),

        _subsection('Progress & Meter', Div(
          className: 'space-y-4 max-w-md',
          children: [
            Div(children: [
              _componentLabel('Progress'),
              Progress(value: 0.7, max: 1, className: 'w-full h-2'),
            ]),
            Div(children: [
              _componentLabel('Meter'),
              Meter(value: 0.6, min: 0, max: 1, low: 0.3, high: 0.8, optimum: 0.7, className: 'w-full h-4'),
            ]),
          ],
        )),
      ],
    );
  }

  // ============ TABLE SECTION ============
  Component _tableSection() {
    return Div(
      children: [
        _sectionTitle('Table Elements'),

        _subsection('Complete Table', Table(
          className: 'w-full border-collapse',
          children: [
            Caption(
              className: 'text-gray-400 text-sm mb-2',
              child: Text('User Data Table'),
            ),
            Thead(
              className: 'bg-gray-800',
              child: Tr(children: [
                Th(className: 'px-4 py-3 text-left text-sm font-semibold text-white', child: Text('Name')),
                Th(className: 'px-4 py-3 text-left text-sm font-semibold text-white', child: Text('Email')),
                Th(className: 'px-4 py-3 text-left text-sm font-semibold text-white', child: Text('Role')),
              ]),
            ),
            Tbody(
              className: 'divide-y divide-gray-800',
              children: [
                Tr(className: 'hover:bg-gray-800/50', children: [
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('Alice')),
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('alice@example.com')),
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('Admin')),
                ]),
                Tr(className: 'hover:bg-gray-800/50', children: [
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('Bob')),
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('bob@example.com')),
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('User')),
                ]),
                Tr(className: 'hover:bg-gray-800/50', children: [
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('Charlie')),
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('charlie@example.com')),
                  Td(className: 'px-4 py-3 text-gray-300', child: Text('Editor')),
                ]),
              ],
            ),
            Tfoot(
              className: 'bg-gray-800/50',
              child: Tr(children: [
                Td(
                  colspan: 3,
                  className: 'px-4 py-2 text-gray-400 text-sm',
                  child: Text('3 users total'),
                ),
              ]),
            ),
          ],
        )),

        _subsection('Col & Colgroup', Table(
          className: 'w-full border-collapse mt-4',
          children: [
            Colgroup(children: [
              Col(className: 'bg-emerald-900/20'),
              Col(),
              Col(className: 'bg-emerald-900/20'),
            ]),
            Thead(child: Tr(children: [
              Th(className: 'px-4 py-2 text-left text-white', child: Text('Col 1')),
              Th(className: 'px-4 py-2 text-left text-white', child: Text('Col 2')),
              Th(className: 'px-4 py-2 text-left text-white', child: Text('Col 3')),
            ])),
            Tbody(child: Tr(children: [
              Td(className: 'px-4 py-2 text-gray-300', child: Text('Data 1')),
              Td(className: 'px-4 py-2 text-gray-300', child: Text('Data 2')),
              Td(className: 'px-4 py-2 text-gray-300', child: Text('Data 3')),
            ])),
          ],
        )),
      ],
    );
  }

  // ============ MEDIA SECTION ============
  Component _mediaSection() {
    return Div(
      children: [
        _sectionTitle('Media Elements'),

        _subsection('Img - Image', Img(
          src: 'https://picsum.photos/400/200',
          alt: 'Sample image',
          className: 'rounded-lg',
          width: 400,
          height: 200,
        )),

        _subsection('Figure & Figcaption', Figure(
          className: 'max-w-md',
          children: [
            Img(
              src: 'https://picsum.photos/400/250',
              alt: 'Figure image',
              className: 'rounded-lg w-full',
            ),
            Figcaption(
              className: 'mt-2 text-center text-gray-400 text-sm',
              child: Text('A beautiful landscape image with caption'),
            ),
          ],
        )),

        _subsection('Video', Video(
          src: 'https://www.w3schools.com/html/mov_bbb.mp4',
          controls: true,
          className: 'rounded-lg max-w-md',
          width: 400,
        )),

        _subsection('Audio', Audio(
          src: 'https://www.w3schools.com/html/horse.ogg',
          controls: true,
          className: 'w-full max-w-md',
        )),

        _subsection('Iframe', Iframe(
          src: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
          className: 'rounded-lg',
          width: 400,
          height: 225,
          allow: 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture',
        )),
      ],
    );
  }

  // ============ SEMANTIC SECTION ============
  Component _semanticSection() {
    return Div(
      children: [
        _sectionTitle('Semantic Elements'),

        _subsection('Header / Nav / Main / Footer', Div(
          className: 'border border-gray-700 rounded-lg overflow-hidden',
          children: [
            Header(
              className: 'bg-gray-800 p-3',
              child: Span(className: 'text-emerald-400 text-sm', child: Text('<Header>')),
            ),
            Nav(
              className: 'bg-gray-800/50 p-3 border-t border-gray-700',
              child: Span(className: 'text-emerald-400 text-sm', child: Text('<Nav>')),
            ),
            Main(
              className: 'p-3 border-t border-gray-700',
              child: Span(className: 'text-emerald-400 text-sm', child: Text('<Main>')),
            ),
            Footer(
              className: 'bg-gray-800 p-3 border-t border-gray-700',
              child: Span(className: 'text-emerald-400 text-sm', child: Text('<Footer>')),
            ),
          ],
        )),

        _subsection('Article / Section / Aside', Div(
          className: 'grid md:grid-cols-3 gap-4',
          children: [
            Article(
              className: 'border border-gray-700 rounded-lg p-4',
              children: [
                _componentLabel('Article'),
                P(className: 'text-gray-300 text-sm', child: Text('Self-contained content')),
              ],
            ),
            Section(
              className: 'border border-gray-700 rounded-lg p-4',
              children: [
                _componentLabel('Section'),
                P(className: 'text-gray-300 text-sm', child: Text('Generic section')),
              ],
            ),
            Aside(
              className: 'border border-gray-700 rounded-lg p-4',
              children: [
                _componentLabel('Aside'),
                P(className: 'text-gray-300 text-sm', child: Text('Sidebar content')),
              ],
            ),
          ],
        )),

        _subsection('Details / Summary', Details(
          className: 'border border-gray-700 rounded-lg',
          open: true,
          children: [
            Summary(
              className: 'px-4 py-3 bg-gray-800 cursor-pointer text-white font-medium',
              child: Text('Click to toggle (Details/Summary)'),
            ),
            Div(
              className: 'px-4 py-3 text-gray-300',
              child: Text('This content is inside the details element and can be toggled.'),
            ),
          ],
        )),

        _subsection('Dialog', Dialog(
          open: true,
          className: 'relative bg-gray-800 rounded-lg p-6 border border-gray-700',
          children: [
            H3(className: 'text-lg font-semibold text-white mb-2', child: Text('Dialog Title')),
            P(className: 'text-gray-300', child: Text('This is a dialog element. Normally it would be a modal.')),
          ],
        )),
      ],
    );
  }

  // ============ SVG SECTION ============
  Component _svgSection() {
    return Div(
      children: [
        _sectionTitle('SVG Elements'),

        _subsection('Basic Shapes', Div(
          className: 'flex flex-wrap gap-6 items-end',
          children: [
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Rect(
                      x: '10', y: '10',
                      width: '80', height: '80',
                      fill: Color.value(0x3B82F6),
                      rx: '8',
                    ),
                  ],
                ),
                _componentLabel('Rect'),
              ],
            ),
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Circle(
                      cx: '50', cy: '50', r: '40',
                      fill: Color.value(0x10B981),
                    ),
                  ],
                ),
                _componentLabel('Circle'),
              ],
            ),
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Ellipse(
                      cx: '50', cy: '50',
                      rx: '45', ry: '30',
                      fill: Color.value(0xF59E0B),
                    ),
                  ],
                ),
                _componentLabel('Ellipse'),
              ],
            ),
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Line(
                      x1: '10', y1: '10',
                      x2: '90', y2: '90',
                      stroke: Color.value(0xEF4444),
                      strokeWidth: '4',
                    ),
                  ],
                ),
                _componentLabel('Line'),
              ],
            ),
          ],
        )),

        _subsection('Path & Polygon', Div(
          className: 'flex flex-wrap gap-6 items-end',
          children: [
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Path(
                      d: 'M50 10 L90 90 L10 90 Z',
                      fill: Color.value(0x8B5CF6),
                    ),
                  ],
                ),
                _componentLabel('Path'),
              ],
            ),
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Polygon(
                      points: '50,10 90,40 75,90 25,90 10,40',
                      fill: Color.value(0xEC4899),
                    ),
                  ],
                ),
                _componentLabel('Polygon'),
              ],
            ),
            Div(
              className: 'text-center',
              children: [
                Svg(
                  viewBox: '0 0 100 100',
                  width: Unit.pixels(80),
                  height: Unit.pixels(80),
                  children: [
                    Polyline(
                      points: '10,80 30,20 50,60 70,30 90,70',
                      fill: Colors.transparent,
                      stroke: Color.value(0x06B6D4),
                      strokeWidth: '4',
                    ),
                  ],
                ),
                _componentLabel('Polyline'),
              ],
            ),
          ],
        )),

        _subsection('Combined SVG', Svg(
          viewBox: '0 0 200 100',
          width: Unit.pixels(200),
          height: Unit.pixels(100),
          className: 'bg-gray-800 rounded-lg',
          children: [
            Circle(cx: '30', cy: '50', r: '20', fill: Color.value(0x3B82F6)),
            Rect(x: '70', y: '30', width: '40', height: '40', fill: Color.value(0x10B981), rx: '4'),
            Polygon(points: '150,30 180,70 120,70', fill: Color.value(0xF59E0B)),
          ],
        )),
      ],
    );
  }
}
''';

/// HTML signals page - showcases duxt_signals
const _htmlSignalsTemplate = r'''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_signals/duxt_signals.dart';

// ============ SIGNALS ============
final _count = signal(0);
final _doubleCount = computed(() => _count() * 2);

final _todos = signal<List<_Todo>>([
  _Todo(id: 1, title: 'Learn signals', done: true),
  _Todo(id: 2, title: 'Build awesome apps', done: false),
]);
final _newTodoText = signal('');

final _email = formField('', validators: [
  required('Email is required'),
]);

final _isDark = signal(true);
final _activeTab = signal('counter');

@client
class SignalsPage extends StatefulComponent {
  const SignalsPage({super.key});

  @override
  State createState() => _SignalsPageState();
}

class _SignalsPageState extends SignalState<SignalsPage> {
  @override
  Component buildComponent(BuildContext context) {
    return Div(
      className: 'py-12 px-4 ${_isDark() ? "bg-gray-950" : "bg-gray-100"}',
      children: [
        Div(
          className: 'max-w-4xl mx-auto',
          children: [
            _header(),
            _tabs(),
            Div(className: 'mt-6', child: _getContent()),
          ],
        ),
      ],
    );
  }

  Component _header() {
    return Div(
      className: 'text-center mb-8',
      children: [
        Div(
          className: 'flex justify-center items-center gap-4 mb-4',
          children: [
            H1(
              className: 'text-4xl font-bold ${_isDark() ? "text-white" : "text-gray-900"}',
              child: Text('duxt_signals'),
            ),
            Button(
              onClick: () => _isDark.set(!_isDark()),
              className: 'p-2 rounded-lg ${_isDark() ? "bg-gray-800" : "bg-gray-200"}',
              child: Text(_isDark() ? '☀️' : '🌙'),
            ),
          ],
        ),
        P(
          className: '${_isDark() ? "text-gray-400" : "text-gray-600"}',
          child: Text('Reactive state management for Jaspr'),
        ),
      ],
    );
  }

  Component _tabs() {
    return Div(
      className: 'flex flex-wrap justify-center gap-2',
      children: [
        _tab('counter', 'Counter'),
        _tab('todo', 'Todo List'),
        _tab('form', 'Form'),
      ],
    );
  }

  Component _tab(String id, String label) {
    final isActive = _activeTab() == id;
    return Button(
      onClick: () => _activeTab.set(id),
      className: 'px-4 py-2 rounded-lg text-sm font-medium ${isActive
        ? "bg-emerald-600 text-white"
        : (_isDark() ? "bg-gray-800 text-gray-300" : "bg-gray-100 text-gray-600")}',
      child: Text(label),
    );
  }

  Component _getContent() {
    return switch (_activeTab()) {
      'counter' => _counterSection(),
      'todo' => _todoSection(),
      'form' => _formSection(),
      _ => _counterSection(),
    };
  }

  Component _card(String title, String description, List<Component> children) {
    return Div(
      className: 'rounded-xl p-6 ${_isDark() ? "bg-gray-900 border border-gray-800" : "bg-white border border-gray-200"}',
      children: [
        H2(className: 'text-xl font-bold mb-2 ${_isDark() ? "text-white" : "text-gray-900"}', child: Text(title)),
        P(className: 'text-sm mb-4 ${_isDark() ? "text-gray-400" : "text-gray-500"}', child: Text(description)),
        ...children,
      ],
    );
  }

  Component _codeBlock(String code) {
    return Pre(
      className: 'p-4 rounded-lg text-sm mb-6 ${_isDark() ? "bg-gray-800 text-emerald-400" : "bg-gray-100 text-emerald-600"}',
      child: Code(child: Text(code)),
    );
  }

  // ============ COUNTER ============
  Component _counterSection() {
    return _card(
      'Counter with Computed',
      'Basic signal with auto-derived computed value.',
      [
        _codeBlock('final count = signal(0);\nfinal double = computed(() => count() * 2);'),
        Div(className: 'flex items-center justify-center gap-4', children: [
          Button(
            onClick: () => _count.update((v) => v - 1),
            className: 'w-12 h-12 rounded-full text-xl font-bold bg-red-600 text-white',
            child: Text('−'),
          ),
          Span(className: 'text-5xl font-bold ${_isDark() ? "text-white" : "text-gray-900"} w-20 text-center', child: Text('${_count()}')),
          Button(
            onClick: () => _count.update((v) => v + 1),
            className: 'w-12 h-12 rounded-full text-xl font-bold bg-emerald-600 text-white',
            child: Text('+'),
          ),
        ]),
        Div(className: 'mt-4 text-center ${_isDark() ? "text-gray-400" : "text-gray-500"}', child: Text('Double: ${_doubleCount()}')),
        Div(className: 'mt-2 text-center', child: Button(
          onClick: () => _count.set(0),
          className: 'text-sm ${_isDark() ? "text-gray-400" : "text-gray-500"}',
          child: Text('Reset'),
        )),
      ],
    );
  }

  // ============ TODO ============
  Component _todoSection() {
    return _card(
      'Todo List',
      'Complex list state with signal updates.',
      [
        _codeBlock('final todos = signal<List<Todo>>([]);\ntodos.update((list) => [...list, newTodo]);'),
        Div(className: 'flex gap-2 mb-4', children: [
          Input(
            type: 'text',
            placeholder: 'Add todo...',
            value: _newTodoText(),
            onInput: (v) => _newTodoText.set(v),
            className: 'flex-1 px-4 py-2 rounded-lg ${_isDark() ? "bg-gray-800 border-gray-700 text-white" : "bg-gray-100 border-gray-200 text-gray-900"} border',
          ),
          Button(
            onClick: () {
              if (_newTodoText().trim().isNotEmpty) {
                _todos.update((list) => [...list, _Todo(id: DateTime.now().millisecondsSinceEpoch, title: _newTodoText().trim(), done: false)]);
                _newTodoText.set('');
              }
            },
            className: 'px-4 py-2 rounded-lg bg-emerald-600 text-white',
            child: Text('Add'),
          ),
        ]),
        Div(className: 'space-y-2', children: _todos().map((todo) => _todoItem(todo)).toList()),
      ],
    );
  }

  Component _todoItem(_Todo todo) {
    return Div(
      className: 'flex items-center gap-3 p-3 rounded-lg ${_isDark() ? "bg-gray-800" : "bg-gray-50"}',
      children: [
        Button(
          onClick: () => _todos.update((list) => list.map((t) => t.id == todo.id ? _Todo(id: t.id, title: t.title, done: !t.done) : t).toList()),
          className: 'w-6 h-6 rounded-full border-2 flex items-center justify-center ${todo.done ? "bg-emerald-500 border-emerald-500 text-white" : "border-gray-600"}',
          child: todo.done ? Text('✓') : Text(''),
        ),
        Span(className: 'flex-1 ${todo.done ? "line-through text-gray-500" : (_isDark() ? "text-white" : "text-gray-900")}', child: Text(todo.title)),
        Button(
          onClick: () => _todos.update((list) => list.where((t) => t.id != todo.id).toList()),
          className: 'text-gray-500 hover:text-red-400',
          child: Text('×'),
        ),
      ],
    );
  }

  // ============ FORM ============
  Component _formSection() {
    return _card(
      'Form Validation',
      'FormField with built-in validation.',
      [
        _codeBlock("final email = formField('', validators: [\n  required('Email is required'),\n]);"),
        Div(children: [
          Label(className: 'block text-sm font-medium mb-1 ${_isDark() ? "text-gray-300" : "text-gray-700"}', child: Text('Email')),
          Input(
            type: 'email',
            value: _email(),
            placeholder: 'your@email.com',
            onInput: (v) => _email.set(v),
            events: {'blur': (_) => _email.touch()},
            className: 'w-full px-4 py-2 rounded-lg border ${_email.touched && _email.hasError ? "border-red-500" : (_isDark() ? "border-gray-700" : "border-gray-200")} ${_isDark() ? "bg-gray-800 text-white" : "bg-white text-gray-900"}',
          ),
          if (_email.touched && _email.hasError)
            Div(className: 'mt-1 text-sm text-red-400', child: Text(_email.error ?? '')),
          Div(className: 'mt-4 flex items-center gap-4', children: [
            Button(
              onClick: () => _email.touch(),
              className: 'px-4 py-2 rounded-lg ${_email.isValid ? "bg-emerald-600 text-white" : "bg-gray-600 text-gray-400"}',
              child: Text('Submit'),
            ),
            Button(
              onClick: () => _email.reset(),
              className: 'text-sm ${_isDark() ? "text-gray-400" : "text-gray-500"}',
              child: Text('Reset'),
            ),
            Span(
              className: 'text-sm ${_email.isValid ? "text-emerald-400" : "text-gray-500"}',
              child: Text(_email.isValid ? '✓ Valid' : 'Enter email'),
            ),
          ]),
        ]),
      ],
    );
  }
}

class _Todo {
  final int id;
  final String title;
  final bool done;
  _Todo({required this.id, required this.title, required this.done});
}
''';
