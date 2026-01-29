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

    // Showcase module (duxt_ui components)
    await _createShowcaseModule(targetDir);

    // Web files
    await _createTailwindStyles(targetDir);
    await _createIndexHtml(dartName, targetDir);

    print('');
    print('  \x1B[32m✓\x1B[0m Created project structure');
    print('');
    print('  lib/');
    print('    ├── home/');
    print('    │   ├── pages/index.dart');
    print('    │   └── components/');
    print('    ├── about/');
    print('    │   └── pages/index.dart');
    print('    ├── showcase/');
    print('    │   └── pages/index.dart');
    print('    ├── shared/');
    print('    │   └── layouts/default.dart');
    print('    └── app.dart');
    print('');
    print('  \x1B[36mℹ\x1B[0m  Using duxt_ui components');
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/home/pages',
      'lib/home/components',
      'lib/about/pages',
      'lib/showcase/pages',
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
  duxt_ui:
    path: /Volumes/External/duxt_ui

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
import 'showcase/pages/index.dart';

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
          // Showcase module
          Route(
            path: '/showcase',
            title: 'Showcase',
            builder: (context, state) => const ShowcasePage(),
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
import 'package:duxt_ui/duxt_ui.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gray-50 dark:bg-gray-950 flex flex-col', [
      // Header with navigation
      DHeader(
        left: DLink(
          href: '/',
          label: 'Duxt',
          color: DLinkColor.primary,
        ),
        right: DNavigationMenu(
          items: [
            DNavigationItem(label: 'Home', href: '/'),
            DNavigationItem(label: 'Showcase', href: '/showcase'),
            DNavigationItem(label: 'About', href: '/about'),
          ],
        ),
      ),
      // Main content
      DMain(children: [child]),
      // Footer
      DFooter(
        center: DCopyright(text: 'Built with Duxt'),
      ),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'shared', 'layouts', 'default.dart')).writeAsString(content);
  }

  static Future<void> _createHomeModule(String projectName, String targetDir) async {
    // Home page using duxt_ui components
    final pageContent = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_ui/duxt_ui.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return DPage(children: [
      // Hero section
      DPageHero(
        headline: 'Welcome to Duxt',
        title: '$projectName',
        description: 'Built with Duxt - The modern framework for Jaspr',
        gradient: true,
        links: [
          DButton(
            label: 'Get Started',
            color: DButtonColor.primary,
            size: DButtonSize.lg,
          ),
          DButton(
            label: 'Documentation',
            variant: DButtonVariant.outline,
            color: DButtonColor.neutral,
            size: DButtonSize.lg,
          ),
        ],
      ),
      // Features section
      DPageSection(
        headline: 'Features',
        title: 'Everything you need',
        description: 'Duxt provides all the tools to build modern web apps with Dart',
      ),
      DPageGrid(
        columns: DPageGridColumns.three,
        children: [
          DPageCard(
            icon: DIcon(name: 'heroicons:cube'),
            title: 'Module-Based',
            description: 'Organize code by feature with pages, components, and api per module',
          ),
          DPageCard(
            icon: DIcon(name: 'heroicons:bolt'),
            title: 'Simple API',
            description: 'Static Api class for clean HTTP calls',
          ),
          DPageCard(
            icon: DIcon(name: 'heroicons:cog-6-tooth'),
            title: 'Opinionated',
            description: 'Conventions over configuration for rapid development',
          ),
        ],
      ),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'home', 'pages', 'index.dart')).writeAsString(pageContent);

    // Keep empty components folder with a placeholder
    await File(p.join(targetDir, 'lib', 'home', 'components', '.gitkeep')).writeAsString('');
  }

  static Future<void> _createAboutModule(String targetDir) async {
    final content = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_ui/duxt_ui.dart';

class AboutPage extends StatelessComponent {
  const AboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return DPage(children: [
      DPageHeader(
        title: 'About',
        description: 'Learn more about this project',
      ),
      DContainer(children: [
        p(classes: 'text-lg text-gray-600 dark:text-gray-400 mb-8', [
          text(
            'Duxt is a meta-framework for Jaspr that brings modern conventions '
            'to Dart web development.',
          ),
        ]),
      ]),
      DPageSection(
        title: 'Features',
        description: 'What makes Duxt special',
      ),
      DPageGrid(
        columns: DPageGridColumns.two,
        children: [
          DPageCard(
            icon: DIcon(name: 'heroicons:cube'),
            title: 'Module-based architecture',
            description: 'Organize your code by features for better maintainability',
          ),
          DPageCard(
            icon: DIcon(name: 'heroicons:server'),
            title: 'Simple API client',
            description: 'Static Api class for clean HTTP calls',
          ),
          DPageCard(
            icon: DIcon(name: 'heroicons:arrow-path'),
            title: 'DuxtState mixin',
            description: 'Easy SPA data loading patterns',
          ),
          DPageCard(
            icon: DIcon(name: 'heroicons:paint-brush'),
            title: 'Tailwind CSS',
            description: 'Built-in Tailwind integration for styling',
          ),
        ],
      ),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'about', 'pages', 'index.dart')).writeAsString(content);
  }

  static Future<void> _createShowcaseModule(String targetDir) async {
    final content = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_ui/duxt_ui.dart';

class ShowcasePage extends StatefulComponent {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  String _selectedTab = 'buttons';

  @override
  Component build(BuildContext context) {
    return DPage(children: [
      DPageHeader(
        headline: 'Duxt UI',
        title: 'Component Showcase',
        description: 'Explore the beautiful components available in duxt_ui',
      ),
      DContainer(children: [
        // Tabs for different component categories
        DTabs(
          items: [
            DTabItem(value: 'buttons', label: 'Buttons'),
            DTabItem(value: 'cards', label: 'Cards'),
            DTabItem(value: 'inputs', label: 'Inputs'),
            DTabItem(value: 'feedback', label: 'Feedback'),
          ],
          defaultValue: _selectedTab,
          onSelect: (value) => setState(() => _selectedTab = value),
        ),

        div(classes: 'mt-8', [
          // Buttons showcase
          if (_selectedTab == 'buttons') ...[
            _sectionTitle('Button Variants'),
            div(classes: 'flex flex-wrap gap-4 mb-8', [
              DButton(label: 'Solid', variant: DButtonVariant.solid),
              DButton(label: 'Outline', variant: DButtonVariant.outline),
              DButton(label: 'Soft', variant: DButtonVariant.soft),
              DButton(label: 'Ghost', variant: DButtonVariant.ghost),
              DButton(label: 'Link', variant: DButtonVariant.link),
            ]),
            _sectionTitle('Button Colors'),
            div(classes: 'flex flex-wrap gap-4 mb-8', [
              DButton(label: 'Primary', color: DButtonColor.primary),
              DButton(label: 'Secondary', color: DButtonColor.secondary),
              DButton(label: 'Success', color: DButtonColor.success),
              DButton(label: 'Warning', color: DButtonColor.warning),
              DButton(label: 'Error', color: DButtonColor.error),
              DButton(label: 'Neutral', color: DButtonColor.neutral),
            ]),
            _sectionTitle('Button Sizes'),
            div(classes: 'flex flex-wrap items-center gap-4 mb-8', [
              DButton(label: 'XS', size: DButtonSize.xs),
              DButton(label: 'SM', size: DButtonSize.sm),
              DButton(label: 'MD', size: DButtonSize.md),
              DButton(label: 'LG', size: DButtonSize.lg),
              DButton(label: 'XL', size: DButtonSize.xl),
            ]),
            _sectionTitle('Loading State'),
            div(classes: 'flex flex-wrap gap-4', [
              DButton(label: 'Loading...', loading: true),
              DButton(label: 'Disabled', disabled: true),
            ]),
          ],

          // Cards showcase
          if (_selectedTab == 'cards') ...[
            _sectionTitle('Card Variants'),
            DPageGrid(
              columns: DPageGridColumns.two,
              children: [
                DCard(
                  variant: DCardVariant.outline,
                  header: DCardHeader(title: 'Outline Card', description: 'Default card style'),
                  children: [p([text('Card content goes here')])],
                ),
                DCard(
                  variant: DCardVariant.solid,
                  header: DCardHeader(title: 'Solid Card', description: 'Inverted colors'),
                  children: [p([text('Card content goes here')])],
                ),
                DCard(
                  variant: DCardVariant.soft,
                  header: DCardHeader(title: 'Soft Card', description: 'Subtle background'),
                  children: [p([text('Card content goes here')])],
                ),
                DCard(
                  variant: DCardVariant.subtle,
                  header: DCardHeader(title: 'Subtle Card', description: 'Soft with border'),
                  children: [p([text('Card content goes here')])],
                ),
              ],
            ),
            div(classes: 'h-8', []),
            _sectionTitle('Page Cards'),
            DPageGrid(
              columns: DPageGridColumns.three,
              children: [
                DPageCard(
                  icon: DIcon(name: 'heroicons:rocket-launch'),
                  title: 'Getting Started',
                  description: 'Learn how to get up and running quickly',
                  to: '/about',
                ),
                DPageCard(
                  icon: DIcon(name: 'heroicons:book-open'),
                  title: 'Documentation',
                  description: 'Read the full documentation',
                ),
                DPageCard(
                  icon: DIcon(name: 'heroicons:code-bracket'),
                  title: 'Examples',
                  description: 'Browse example projects',
                ),
              ],
            ),
          ],

          // Inputs showcase
          if (_selectedTab == 'inputs') ...[
            _sectionTitle('Text Inputs'),
            div(classes: 'space-y-4 max-w-md mb-8', [
              DInput(placeholder: 'Default input'),
              DInput(placeholder: 'Disabled', disabled: true),
              DInput(placeholder: 'With label', label: 'Email'),
            ]),
            _sectionTitle('Checkboxes & Switches'),
            div(classes: 'space-y-4 mb-8', [
              DCheckbox(label: 'Accept terms and conditions'),
              DCheckbox(label: 'Checked by default', checked: true),
              DSwitch(label: 'Enable notifications'),
            ]),
            _sectionTitle('Select'),
            div(classes: 'max-w-md', [
              DSelect(
                placeholder: 'Choose an option',
                options: [
                  DSelectOption(value: 'opt1', label: 'Option 1'),
                  DSelectOption(value: 'opt2', label: 'Option 2'),
                  DSelectOption(value: 'opt3', label: 'Option 3'),
                ],
              ),
            ]),
          ],

          // Feedback showcase
          if (_selectedTab == 'feedback') ...[
            _sectionTitle('Alerts'),
            div(classes: 'space-y-4 mb-8', [
              DAlert(
                title: 'Info',
                description: 'This is an informational message',
                variant: DAlertVariant.soft,
              ),
              DAlert(
                title: 'Success',
                description: 'Operation completed successfully',
                variant: DAlertVariant.soft,
                color: DAlertColor.success,
              ),
              DAlert(
                title: 'Warning',
                description: 'Please review before continuing',
                variant: DAlertVariant.soft,
                color: DAlertColor.warning,
              ),
              DAlert(
                title: 'Error',
                description: 'Something went wrong',
                variant: DAlertVariant.soft,
                color: DAlertColor.error,
              ),
            ]),
            _sectionTitle('Badges'),
            div(classes: 'flex flex-wrap gap-4 mb-8', [
              DBadge(label: 'Default'),
              DBadge(label: 'Primary', color: DBadgeColor.primary),
              DBadge(label: 'Success', color: DBadgeColor.success),
              DBadge(label: 'Warning', color: DBadgeColor.warning),
              DBadge(label: 'Error', color: DBadgeColor.error),
            ]),
            _sectionTitle('Progress'),
            div(classes: 'max-w-md space-y-4', [
              DProgress(value: 25),
              DProgress(value: 50, color: DProgressColor.success),
              DProgress(value: 75, color: DProgressColor.warning),
            ]),
            _sectionTitle('Spinner'),
            div(classes: 'flex gap-4', [
              DSpinner(size: DSpinnerSize.sm),
              DSpinner(size: DSpinnerSize.md),
              DSpinner(size: DSpinnerSize.lg),
            ]),
          ],
        ]),
      ]),
    ]);
  }

  Component _sectionTitle(String title) {
    return h3(classes: 'text-lg font-semibold text-gray-900 dark:text-white mb-4', [
      text(title),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'showcase', 'pages', 'index.dart')).writeAsString(content);
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
