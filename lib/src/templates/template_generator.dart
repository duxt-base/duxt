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

    // Company module (nested routing example)
    await _createCompanyModule(targetDir);

    // Blog module (fullstack example)
    await _createBlogModule(targetDir);

    // Server (API + Database)
    await _createServerFiles(targetDir);

    // Web files
    await _createTailwindStyles(targetDir);
    await _createIndexHtml(dartName, targetDir);

    print('');
    print('  \x1B[32m✓\x1B[0m Created project structure');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart       → /');
    print('    ├── about/pages/index.dart      → /about');
    print('    ├── showcase/pages/index.dart   → /showcase');
    print('    ├── company/pages/              (nested routing)');
    print('    ├── blog/pages/                 (fullstack example)');
    print('    │   ├── index.dart              → /blog');
    print('    │   └── [slug].dart             → /blog/:slug');
    print('    ├── shared/layouts/default.dart');
    print('    └── app.dart');
    print('');
    print('  server/');
    print('    ├── main.dart                   Entry point');
    print('    ├── db.dart                     SQLite connection');
    print('    ├── models/post.dart            Post model');
    print('    └── api/posts.dart              API routes');
    print('');
    print('  \x1B[36mℹ\x1B[0m  Run \x1B[1mduxt dev\x1B[0m to start both frontend & API');
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/home/pages',
      'lib/home/components',
      'lib/about/pages',
      'lib/showcase/pages',
      'lib/company/pages',
      'lib/company/pages/team',
      'lib/blog/pages',
      'lib/shared/components',
      'lib/shared/layouts',
      'server',
      'server/api',
      'server/models',
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
  duxt: ^0.2.8
  duxt_ui: ^0.2.3
  sqlite3: ^2.4.0
  web: ^1.0.0

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
import 'package:jaspr_router/jaspr_router.dart';

// Modules
import 'home/pages/index.dart';
import 'about/pages/index.dart';
import 'showcase/pages/index.dart';
import 'company/pages/index.dart';
import 'company/pages/about.dart';
import 'company/pages/team/index.dart';
import 'company/pages/team/engineering.dart';
import 'blog/pages/index.dart';
import 'blog/pages/[slug].dart';

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
          // Company module (nested routing example)
          Route(
            path: '/company',
            title: 'Company',
            builder: (context, state) => const CompanyPage(),
          ),
          Route(
            path: '/company/about',
            title: 'About Company',
            builder: (context, state) => const CompanyAboutPage(),
          ),
          Route(
            path: '/company/team',
            title: 'Team',
            builder: (context, state) => const CompanyTeamPage(),
          ),
          Route(
            path: '/company/team/engineering',
            title: 'Engineering',
            builder: (context, state) => const CompanyTeamEngineeringPage(),
          ),
          // Blog module (fullstack example)
          Route(
            path: '/blog',
            title: 'Blog',
            builder: (context, state) => const BlogPage(),
          ),
          Route(
            path: '/blog/:slug',
            title: 'Post',
            builder: (context, state) => BlogPostPage(
              slug: state.params['slug']!,
            ),
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
import 'package:duxt_ui/duxt_ui.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'relative', [
      // Header - fixed top, transparent
      header(classes: 'fixed top-0 left-0 right-0 z-50 bg-transparent', [
        div(classes: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8', [
          div(classes: 'flex h-16 items-center justify-between', [
            Link(
              to: '/',
              child: img(src: 'https://duxt.dev/images/logo.svg', alt: 'Duxt', classes: 'h-8'),
            ),
            nav(classes: 'flex items-center gap-6', [
              Link(to: '/', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Home')])),
              Link(to: '/blog', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Blog')])),
              Link(to: '/showcase', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Showcase')])),
              Link(to: '/company', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Company')])),
              Link(to: '/about', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('About')])),
            ]),
          ]),
        ]),
      ]),
      // Main content
      child,
      // Footer - fixed bottom, transparent
      footer(classes: 'fixed bottom-0 left-0 right-0 z-50 bg-transparent', [
        div(classes: 'max-w-7xl mx-auto px-4 py-4 text-center', [
          DCopyright(text: 'Built with Duxt'),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'shared', 'layouts', 'default.dart')).writeAsString(content);
  }

  static Future<void> _createHomeModule(String projectName, String targetDir) async {
    final pageContent = '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'h-screen flex items-center justify-center bg-gradient-to-b from-gray-900 to-gray-950', [
      div(classes: 'text-center px-4', [
        span(classes: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-cyan-400 bg-cyan-500/10 rounded-full', [
          Component.text('Welcome to Duxt'),
        ]),
        h1(classes: 'text-5xl font-bold text-white mb-6', [Component.text('$projectName')]),
        p(classes: 'text-xl text-gray-400 mb-10', [Component.text('lib/home/pages/index.dart — change me!')]),
        div(classes: 'flex justify-center gap-4', [
          a(
            href: 'https://duxt.dev/duxt',
            target: Target.blank,
            classes: 'px-6 py-3 bg-cyan-500 text-white rounded-lg font-medium hover:bg-cyan-600 transition-colors',
            [Component.text('Get Started')],
          ),
          a(
            href: 'https://duxt.dev/duxt-ui',
            target: Target.blank,
            classes: 'px-6 py-3 border border-gray-600 text-gray-300 rounded-lg font-medium hover:bg-gray-800 transition-colors',
            [Component.text('Components')],
          ),
        ]),
      ]),
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
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: 'About', color: DBadgeColor.primary),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-6', [Component.text('About this app')]),
        p(classes: 'text-lg text-gray-400 mb-8', [
          Component.text('This is a Duxt application. Edit this page at lib/about/pages/index.dart'),
        ]),
        div(classes: 'flex justify-center gap-4', [
          DButton(label: 'Learn More', color: DButtonColor.primary),
          DButton(label: 'Contact', variant: DButtonVariant.outline, color: DButtonColor.neutral),
        ]),
      ]),
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
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-20 pb-16 px-4', [
      div(classes: 'max-w-5xl mx-auto', [
        // Header
        div(classes: 'text-center mb-12', [
          h1(classes: 'text-4xl font-bold text-white mb-4', [Component.text('Component Showcase')]),
          a(
            href: 'https://duxt.dev/duxt-ui',
            target: Target.blank,
            classes: 'text-cyan-400 hover:text-cyan-300',
            [Component.text('View full documentation →')],
          ),
        ]),

        // Tabs
        DTabs(
          items: [
            DTabItem(value: 'buttons', label: 'Buttons'),
            DTabItem(value: 'inputs', label: 'Inputs'),
            DTabItem(value: 'feedback', label: 'Feedback'),
          ],
          defaultValue: _selectedTab,
          onSelect: (value) => setState(() => _selectedTab = value),
        ),

        div(classes: 'mt-8', [
          // Buttons showcase
          if (_selectedTab == 'buttons') ...[
            _sectionTitle('Variants'),
            div(classes: 'flex flex-wrap gap-3 mb-8', [
              DButton(label: 'Solid', variant: DButtonVariant.solid),
              DButton(label: 'Outline', variant: DButtonVariant.outline),
              DButton(label: 'Soft', variant: DButtonVariant.soft),
              DButton(label: 'Ghost', variant: DButtonVariant.ghost),
            ]),
            _sectionTitle('Colors'),
            div(classes: 'flex flex-wrap gap-3 mb-8', [
              DButton(label: 'Primary', color: DButtonColor.primary),
              DButton(label: 'Success', color: DButtonColor.success),
              DButton(label: 'Warning', color: DButtonColor.warning),
              DButton(label: 'Error', color: DButtonColor.error),
            ]),
            _sectionTitle('Sizes'),
            div(classes: 'flex flex-wrap items-center gap-3 mb-8', [
              DButton(label: 'SM', size: DButtonSize.sm),
              DButton(label: 'MD', size: DButtonSize.md),
              DButton(label: 'LG', size: DButtonSize.lg),
            ]),
            _sectionTitle('States'),
            div(classes: 'flex flex-wrap gap-3', [
              DButton(label: 'Loading...', loading: true),
              DButton(label: 'Disabled', disabled: true),
            ]),
          ],

          // Inputs showcase
          if (_selectedTab == 'inputs') ...[
            _sectionTitle('Text Inputs'),
            div(classes: 'grid grid-cols-1 md:grid-cols-2 gap-4 mb-8', [
              DInput(placeholder: 'Default input'),
              DInput(label: 'With Label', placeholder: 'Enter text...'),
            ]),
            _sectionTitle('Checkboxes & Switches'),
            div(classes: 'space-y-3 mb-8', [
              DCheckbox(label: 'Default checkbox'),
              DSwitch(label: 'Enable notifications'),
            ]),
          ],

          // Feedback showcase
          if (_selectedTab == 'feedback') ...[
            _sectionTitle('Alerts'),
            div(classes: 'space-y-4 mb-8', [
              DAlert(title: 'Info', description: 'This is an informational message'),
              DAlert(title: 'Success', description: 'Operation completed', color: DAlertColor.success),
              DAlert(title: 'Warning', description: 'Please review', color: DAlertColor.warning),
            ]),
            _sectionTitle('Badges'),
            div(classes: 'flex flex-wrap gap-3 mb-8', [
              DBadge(label: 'Default'),
              DBadge(label: 'Primary', color: DBadgeColor.primary),
              DBadge(label: 'Success', color: DBadgeColor.success),
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
    return h3(classes: 'text-lg font-semibold text-white mb-4 mt-8 first:mt-0', [Component.text(title)]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'showcase', 'pages', 'index.dart')).writeAsString(content);
  }

  static Future<void> _createCompanyModule(String targetDir) async {
    // /company
    final indexContent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyPage extends StatelessComponent {
  const CompanyPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company', color: DBadgeColor.primary),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('Company')]),
        p(classes: 'text-gray-400 mb-2', [Component.text('lib/company/pages/index.dart')]),
        p(classes: 'text-lg text-gray-400 mb-8', [
          Component.text('This showcases nested file-based routing.'),
        ]),
        div(classes: 'flex flex-wrap justify-center gap-3', [
          Link(to: '/company/about', child: DButton(label: '/company/about')),
          Link(to: '/company/team', child: DButton(label: '/company/team', variant: DButtonVariant.outline)),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'company', 'pages', 'index.dart')).writeAsString(indexContent);

    // /company/about
    final aboutContent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyAboutPage extends StatelessComponent {
  const CompanyAboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company/about', color: DBadgeColor.success),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('About Company')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('lib/company/pages/about.dart')]),
        div(classes: 'flex justify-center gap-3', [
          Link(to: '/company', child: DButton(label: '← Back to /company', variant: DButtonVariant.ghost)),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'company', 'pages', 'about.dart')).writeAsString(aboutContent);

    // /company/team
    final teamIndexContent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyTeamPage extends StatelessComponent {
  const CompanyTeamPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company/team', color: DBadgeColor.warning),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('Our Team')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('lib/company/pages/team/index.dart')]),
        div(classes: 'flex flex-wrap justify-center gap-3', [
          Link(to: '/company', child: DButton(label: '← /company', variant: DButtonVariant.ghost)),
          Link(to: '/company/team/engineering', child: DButton(label: '/company/team/engineering')),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'company', 'pages', 'team', 'index.dart')).writeAsString(teamIndexContent);

    // /company/team/engineering
    final engineeringContent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyTeamEngineeringPage extends StatelessComponent {
  const CompanyTeamEngineeringPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company/team/engineering', color: DBadgeColor.error),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('Engineering Team')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('lib/company/pages/team/engineering.dart')]),
        div(classes: 'flex justify-center gap-3', [
          Link(to: '/company/team', child: DButton(label: '← /company/team', variant: DButtonVariant.ghost)),
        ]),
      ]),
    ]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'company', 'pages', 'team', 'engineering.dart')).writeAsString(engineeringContent);
  }

  static Future<void> _createBlogModule(String targetDir) async {
    // /blog - List page
    final indexContent = r'''
import 'dart:convert';
import 'dart:js_interop';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';
import 'package:web/web.dart' as web;

class BlogPage extends StatefulComponent {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final response = await web.window.fetch('http://localhost:3001/api/posts'.toJS).toDart;
      if (response.ok) {
        final jsText = await response.text().toDart;
        final data = jsonDecode(jsText.toDart);
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data['posts']);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load posts';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'API server not running. Run: duxt dev';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-4xl mx-auto', [
        div(classes: 'text-center mb-12', [
          DBadge(label: 'Blog', color: DBadgeColor.primary),
          h1(classes: 'text-4xl font-bold text-white mt-4 mb-4', [Component.text('Latest Posts')]),
          p(classes: 'text-gray-400', [Component.text('Fullstack example with SQLite API')]),
        ]),
        if (_loading)
          div(classes: 'flex justify-center py-12', [DSpinner(size: DSpinnerSize.lg)])
        else if (_error != null)
          DAlert(title: 'Error', description: _error!, color: DAlertColor.error)
        else if (_posts.isEmpty)
          div(classes: 'text-center py-12', [p(classes: 'text-gray-400', [Component.text('No posts yet.')])])
        else
          div(classes: 'space-y-6', [for (final post in _posts) _postCard(post)]),
      ]),
    ]);
  }

  Component _postCard(Map<String, dynamic> post) {
    return Link(
      to: '/blog/${post['slug']}',
      child: div(classes: 'block bg-gray-800/50 rounded-xl p-6 border border-gray-700/50 hover:border-cyan-500/50 transition-colors', [
        h2(classes: 'text-xl font-semibold text-white mb-2', [Component.text(post['title'] ?? 'Untitled')]),
        if (post['excerpt'] != null) p(classes: 'text-gray-400 mb-4', [Component.text(post['excerpt'])]),
        span(classes: 'text-cyan-400 text-sm', [Component.text('Read more →')]),
      ]),
    );
  }
}
''';
    await File(p.join(targetDir, 'lib', 'blog', 'pages', 'index.dart')).writeAsString(indexContent);

    // /blog/:slug - Detail page
    final detailContent = r'''
import 'dart:convert';
import 'dart:js_interop';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';
import 'package:web/web.dart' as web;

class BlogPostPage extends StatefulComponent {
  final String slug;
  const BlogPostPage({required this.slug, super.key});

  @override
  State<BlogPostPage> createState() => _BlogPostPageState();
}

class _BlogPostPageState extends State<BlogPostPage> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    try {
      final response = await web.window.fetch('http://localhost:3001/api/posts/${component.slug}'.toJS).toDart;
      if (response.ok) {
        final jsText = await response.text().toDart;
        final data = jsonDecode(jsText.toDart);
        setState(() { _post = data['post']; _loading = false; });
      } else {
        setState(() { _error = 'Post not found'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'API server not running'; _loading = false; });
    }
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-3xl mx-auto', [
        div(classes: 'mb-8', [
          Link(to: '/blog', child: span(classes: 'text-cyan-400 hover:text-cyan-300', [Component.text('← Back to Blog')])),
        ]),
        if (_loading)
          div(classes: 'flex justify-center py-12', [DSpinner(size: DSpinnerSize.lg)])
        else if (_error != null)
          DAlert(title: 'Error', description: _error!, color: DAlertColor.error)
        else if (_post != null)
          article([
            h1(classes: 'text-4xl font-bold text-white mb-8', [Component.text(_post!['title'] ?? 'Untitled')]),
            div(classes: 'prose prose-invert max-w-none', [
              for (final line in (_post!['content'] as String? ?? '').split('\n')) _renderLine(line),
            ]),
          ]),
      ]),
    ]);
  }

  Component _renderLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return div(classes: 'h-4', []);
    if (t.startsWith('# ')) return h1(classes: 'text-3xl font-bold text-white mt-8 mb-4', [Component.text(t.substring(2))]);
    if (t.startsWith('## ')) return h2(classes: 'text-2xl font-semibold text-white mt-6 mb-3', [Component.text(t.substring(3))]);
    if (t.startsWith('- ')) return li(classes: 'text-gray-300 ml-4', [Component.text(t.substring(2))]);
    if (t.startsWith('```')) return div(classes: 'h-0', []);
    return p(classes: 'text-gray-300 mb-2', [Component.text(line)]);
  }
}
''';
    await File(p.join(targetDir, 'lib', 'blog', 'pages', '[slug].dart')).writeAsString(detailContent);
  }

  static Future<void> _createServerFiles(String targetDir) async {
    // server/db.dart - Database connection
    final dbContent = """
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Database singleton
class Db {
  static late sqlite.Database _db;

  static void init([String path = 'blog.db']) {
    _db = sqlite.sqlite3.open(path);
    _createTables();
  }

  static void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        slug TEXT UNIQUE NOT NULL,
        content TEXT NOT NULL,
        excerpt TEXT,
        published INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  static sqlite.Database get db => _db;
}
""";
    await File(p.join(targetDir, 'server', 'db.dart')).writeAsString(dbContent);

    // server/models/post.dart - Post model
    final postModelContent = r'''
import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../db.dart';

class Post {
  final int? id;
  final String title;
  final String slug;
  final String content;
  final String? excerpt;
  final bool published;
  final DateTime? createdAt;

  Post({
    this.id,
    required this.title,
    required this.slug,
    required this.content,
    this.excerpt,
    this.published = false,
    this.createdAt,
  });

  factory Post.fromRow(sqlite.Row row) => Post(
    id: row['id'] as int,
    title: row['title'] as String,
    slug: row['slug'] as String,
    content: row['content'] as String,
    excerpt: row['excerpt'] as String?,
    published: (row['published'] as int) == 1,
    createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
  );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as int?,
    title: json['title'] as String,
    slug: json['slug'] as String,
    content: json['content'] as String,
    excerpt: json['excerpt'] as String?,
    published: json['published'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'slug': slug,
    'content': content,
    'excerpt': excerpt,
    'published': published,
    'createdAt': createdAt?.toIso8601String(),
  };

  // Repository methods
  static List<Post> findAll({bool publishedOnly = false}) {
    final q = publishedOnly
        ? 'SELECT * FROM posts WHERE published = 1 ORDER BY created_at DESC'
        : 'SELECT * FROM posts ORDER BY created_at DESC';
    return Db.db.select(q).map(Post.fromRow).toList();
  }

  static Post? findById(int id) {
    final r = Db.db.select('SELECT * FROM posts WHERE id = ?', [id]);
    return r.isEmpty ? null : Post.fromRow(r.first);
  }

  static Post? findBySlug(String slug) {
    final r = Db.db.select('SELECT * FROM posts WHERE slug = ?', [slug]);
    return r.isEmpty ? null : Post.fromRow(r.first);
  }

  static Post create(Post post) {
    Db.db.execute(
      'INSERT INTO posts (title, slug, content, excerpt, published) VALUES (?, ?, ?, ?, ?)',
      [post.title, post.slug, post.content, post.excerpt, post.published ? 1 : 0],
    );
    return findById(Db.db.lastInsertRowId)!;
  }

  static Post? update(int id, Post post) {
    Db.db.execute(
      'UPDATE posts SET title = ?, slug = ?, content = ?, excerpt = ?, published = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [post.title, post.slug, post.content, post.excerpt, post.published ? 1 : 0, id],
    );
    return findById(id);
  }

  static bool delete(int id) {
    if (findById(id) == null) return false;
    Db.db.execute('DELETE FROM posts WHERE id = ?', [id]);
    return true;
  }

  static void seed() {
    final existing = Db.db.select('SELECT COUNT(*) as count FROM posts');
    if ((existing.first['count'] as int) > 0) return;

    final posts = [
      Post(
        title: 'Getting Started with Duxt',
        slug: 'getting-started',
        content: '# Getting Started\n\nWelcome to Duxt!\n\n## Features\n\n- File-based routing\n- Server API\n- Component library',
        excerpt: 'Learn how to get started with Duxt.',
        published: true,
      ),
      Post(
        title: 'Building APIs',
        slug: 'building-apis',
        content: '# Building APIs\n\nDuxtServer provides an Express-like API.\n\n## Example\n\n```dart\nserver.get("/api/posts", (req) => json(posts));\n```',
        excerpt: 'Build REST APIs with DuxtServer.',
        published: true,
      ),
    ];
    for (final p in posts) create(p);
  }
}
''';
    await File(p.join(targetDir, 'server', 'models', 'post.dart')).writeAsString(postModelContent);

    // server/api/posts.dart - API routes
    final postsApiContent = r'''
import 'package:duxt/server.dart';
import '../models/post.dart';

/// Register post API routes
void registerPostRoutes(DuxtServer server) {
  // GET /api/posts - List all posts
  server.get('/api/posts', (req) {
    final posts = Post.findAll(publishedOnly: true);
    return json({'posts': posts.map((p) => p.toJson()).toList()});
  });

  // GET /api/posts/:slug - Get post by slug
  server.get('/api/posts/:slug', (req) {
    final slug = req.params['slug'];
    if (slug == null) return json({'error': 'Slug required'}, statusCode: 400);

    final post = Post.findBySlug(slug);
    if (post == null) return json({'error': 'Not found'}, statusCode: 404);

    return json({'post': post.toJson()});
  });

  // POST /api/posts - Create post
  server.post('/api/posts', (req) {
    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    try {
      final post = Post.create(Post.fromJson(body));
      return json({'post': post.toJson()}, statusCode: 201);
    } catch (e) {
      return json({'error': e.toString()}, statusCode: 400);
    }
  });

  // PUT /api/posts/:id - Update post
  server.put('/api/posts/:id', (req) {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) return json({'error': 'Invalid ID'}, statusCode: 400);

    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    final post = Post.update(id, Post.fromJson(body));
    if (post == null) return json({'error': 'Not found'}, statusCode: 404);

    return json({'post': post.toJson()});
  });

  // DELETE /api/posts/:id - Delete post
  server.delete('/api/posts/:id', (req) {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) return json({'error': 'Invalid ID'}, statusCode: 400);

    if (!Post.delete(id)) return json({'error': 'Not found'}, statusCode: 404);

    return json({'success': true});
  });
}
''';
    await File(p.join(targetDir, 'server', 'api', 'posts.dart')).writeAsString(postsApiContent);

    // server/main.dart - Entry point
    final mainContent = r'''
import 'package:duxt/server.dart';
import 'db.dart';
import 'models/post.dart';
import 'api/posts.dart';

void main() {
  // Initialize database
  Db.init();
  Post.seed();

  // Create server
  final server = DuxtServer(
    port: 3001,
    middleware: [cors(), jsonBody(), logger()],
  );

  // Register API routes
  registerPostRoutes(server);

  // Start server
  server.start();
  print('');
  print('API server running at http://localhost:3001');
  print('');
  print('Endpoints:');
  print('  GET    /api/posts');
  print('  GET    /api/posts/:slug');
  print('  POST   /api/posts');
  print('  PUT    /api/posts/:id');
  print('  DELETE /api/posts/:id');
}
''';
    await File(p.join(targetDir, 'server', 'main.dart')).writeAsString(mainContent);
  }

  static Future<void> _createTailwindStyles(String targetDir) async {
    final content = '''
@import "tailwindcss";

@theme {
  /* Primary color - cyan (Duxt brand #06b6d4) */
  --color-primary-50: #ecfeff;
  --color-primary-100: #cffafe;
  --color-primary-200: #a5f3fc;
  --color-primary-300: #67e8f9;
  --color-primary-400: #22d3ee;
  --color-primary-500: #06b6d4;
  --color-primary-600: #0891b2;
  --color-primary-700: #0e7490;
  --color-primary-800: #155e75;
  --color-primary-900: #164e63;
  --color-primary-950: #083344;
}

@layer base {
  html {
    font-family: system-ui, -apple-system, sans-serif;
  }

  body {
    @apply bg-white text-gray-900;
    @apply dark:bg-gray-950 dark:text-gray-100;
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
  <!-- Iconify web component for icon support -->
  <script src="https://code.iconify.design/iconify-icon/2.1.0/iconify-icon.min.js"></script>
</head>
<body>
  <script src="/main.client.dart.js" defer></script>
</body>
</html>
''';
    await File(p.join(targetDir, 'web', 'index.html')).writeAsString(content);
  }
}
