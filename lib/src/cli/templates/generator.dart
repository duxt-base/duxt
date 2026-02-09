import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'layouts.dart';
import 'modules.dart';
import 'blog.dart';
import 'server.dart';
import 'web.dart';
import 'minimal.dart';
import 'marketing.dart';
import 'html.dart';

/// Generates a new Duxt project from templates
class TemplateGenerator {
  static Future<void> generate(
    String projectName,
    String targetDir, {
    String mode = 'static',
    String template = 'default',
  }) async {
    final dartName = projectName.replaceAll('-', '_').replaceAll(' ', '_');

    switch (template) {
      case 'minimal':
        await MinimalTemplate.generate(dartName, targetDir, mode: mode);
      case 'marketing':
        await MarketingTemplate.generate(dartName, targetDir, mode: mode);
      case 'blog':
        await _generateBlog(dartName, targetDir, mode: mode);
      case 'html':
        await HtmlTemplate.generate(dartName, targetDir, mode: mode);
      default:
        await _generateDefault(dartName, targetDir, mode: mode);
    }
  }

  /// Default template - full-featured demo
  static Future<void> _generateDefault(String projectName, String targetDir, {String mode = 'static'}) async {
    await _createDirectories(targetDir, mode: mode);
    await _writeFiles(projectName, targetDir, mode: mode);
    _printSuccess(projectName, mode: mode);
  }

  /// Blog template - focused blog with DuxtORM
  static Future<void> _generateBlog(String projectName, String targetDir, {String mode = 'static'}) async {
    await _createBlogDirectories(targetDir);
    await _writeBlogFiles(projectName, targetDir, mode: mode);
    _printBlogSuccess(projectName);
  }

  static Future<void> _createBlogDirectories(String targetDir) async {
    final dirs = [
      'lib', 'lib/.generated',
      'lib/home/pages',
      'lib/blog/pages',
      'lib/shared/layouts',
      'lib/models',
      'server', 'server/api',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeBlogFiles(String projectName, String dir, {required String mode}) async {
    // Config files
    await _write(dir, 'pubspec.yaml', pubspecTemplate(projectName, mode: mode));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files (simplified for blog)
    await _write(dir, 'lib/app.dart', _blogAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    if (mode == 'static' || mode == 'server') {
      await _write(dir, 'lib/main.server.dart', blogMainServerTemplate(projectName));
    }

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _blogLayoutTemplate);

    // Home module
    await _write(dir, 'lib/home/pages/index.dart', _blogHomeTemplate(projectName));

    // Blog module (fullstack with DuxtORM)
    await _write(dir, 'lib/blog/pages/index.dart', blogIndexTemplate);
    await _write(dir, 'lib/blog/pages/_slug_.dart', blogPostTemplate);

    // Models (shared between lib and server) - order matters for foreign keys
    await _write(dir, 'lib/models/category.dart', categoryModelTemplate);
    await _write(dir, 'lib/models/tag.dart', tagModelTemplate);
    await _write(dir, 'lib/models/post.dart', postWithTagsModelTemplate);

    // Server (with DuxtORM + relations + tags)
    await _write(dir, 'server/main.dart', blogServerMainTemplate(projectName));
    await _write(dir, 'server/db.dart', blogDbTemplate(projectName));
    await _write(dir, 'server/api/categories.dart', categoriesApiTemplate(projectName));
    await _write(dir, 'server/api/tags.dart', tagsApiTemplate(projectName));
    await _write(dir, 'server/api/posts.dart', postsApiTemplate(projectName));

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

  static void _printBlogSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created blog project with DuxtORM');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart     → /');
    print('    ├── blog/pages/');
    print('    │   ├── index.dart            → /blog (tutorial or SSR listing)');
    print('    │   └── _slug_.dart           → /blog/:slug');
    print('    ├── models/');
    print('    │   ├── category.dart');
    print('    │   ├── tag.dart              (many-to-many with posts)');
    print('    │   └── post.dart');
    print('    ├── shared/layouts/');
    print('    └── app.dart');
    print('');
    print('  server/                         (DuxtORM + API)');
    print('    ├── main.dart');
    print('    ├── db.dart');
    print('    └── api/');
    print('        ├── categories.dart');
    print('        ├── tags.dart');
    print('        └── posts.dart');
    print('');
    print('  \x1B[36mRelations:\x1B[0m');
    print('    • Post belongsTo Category');
    print('    • Post belongsToMany Tags (via post_tags pivot)');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                      Start dev server');
    print('');
    print('  \x1B[36mProduction:\x1B[0m');
    print('    duxt build && docker build -t $projectName .');
  }

  static Future<void> _createDirectories(String targetDir, {required String mode}) async {
    final dirs = [
      'lib', 'lib/.generated',
      'lib/home/pages', 'lib/home/content', 'lib/home/components',
      'lib/about/pages', 'lib/about/content',
      'lib/docs/content',
      'lib/showcase/pages',
      'lib/company/pages', 'lib/company/pages/team',
      'lib/blog/pages',
      'lib/shared/components', 'lib/shared/layouts',
      'lib/models',
      'server', 'server/api',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir, {required String mode}) async {
    // Config files
    await _write(dir, 'pubspec.yaml', pubspecTemplate(projectName, mode: mode));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, 'duxt.config.dart', configTemplate(projectName));
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', appTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    // Server entry point for static/server modes
    if (mode == 'static' || mode == 'server') {
      await _write(dir, 'lib/main.server.dart', mainServerTemplate(projectName));
    }

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', defaultLayoutTemplate);
    await _write(dir, 'lib/shared/layouts/page.dart', pageLayoutTemplate);

    // Home module
    await _write(dir, 'lib/home/pages/index.dart', homePageTemplate(projectName));
    await _write(dir, 'lib/home/components/.gitkeep', '');

    // Docs module (content)
    await _write(dir, 'lib/docs/content/index.md', docsIndexTemplate);
    await _write(dir, 'lib/docs/content/getting-started.md', docsGettingStartedTemplate);

    // About module
    await _write(dir, 'lib/about/pages/index.dart', aboutPageTemplate);

    // Showcase module
    await _write(dir, 'lib/showcase/pages/index.dart', showcasePageTemplate);

    // Company module (nested routing)
    await _write(dir, 'lib/company/pages/index.dart', companyIndexTemplate);
    await _write(dir, 'lib/company/pages/about.dart', companyAboutTemplate);
    await _write(dir, 'lib/company/pages/team/index.dart', companyTeamTemplate);
    await _write(dir, 'lib/company/pages/team/engineering.dart', companyEngineeringTemplate);

    // Blog module (fullstack with DuxtORM)
    await _write(dir, 'lib/blog/pages/index.dart', blogIndexTemplate);
    await _write(dir, 'lib/blog/pages/_slug_.dart', blogPostTemplate);  // Dynamic route: /blog/:slug

    // Models (shared between lib and server)
    await _write(dir, 'lib/models/category.dart', categoryModelTemplate);
    await _write(dir, 'lib/models/post.dart', postModelTemplate);

    // Server (with DuxtORM + relations)
    await _write(dir, 'server/main.dart', serverMainTemplate(projectName));
    await _write(dir, 'server/db.dart', dbTemplate(projectName));
    await _write(dir, 'server/api/categories.dart', categoriesApiTemplate(projectName));
    await _write(dir, 'server/api/posts.dart', postsApiTemplate(projectName));

    // Web (no index.html - jaspr's Document handles this)
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

  static void _printSuccess(String projectName, {required String mode}) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created project structure (mode: $mode)');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart        → /');
    print('    ├── docs/content/index.md        → /docs');
    print('    ├── about/pages/index.dart       → /about');
    print('    ├── showcase/pages/index.dart    → /showcase');
    print('    ├── company/pages/               (nested routing demo)');
    print('    ├── blog/pages/');
    print('    │   ├── index.dart               → /blog');
    print('    │   └── _slug_.dart              → /blog/:slug');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart       (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  server/                            (DuxtORM + API)');
    print('    ├── main.dart');
    print('    ├── db.dart');
    print('    ├── models/post.dart');
    print('    └── api/posts.dart');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                         Start dev server');
    print('');
    print('  \x1B[36mProduction:\x1B[0m');
    print('    duxt build && docker build -t $projectName .');
  }
}

// Blog template specific strings
const _blogAppTemplate = r'''
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

const _blogLayoutTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gray-950 flex flex-col', [
      header(classes: 'sticky top-0 z-50 bg-gray-900/95 backdrop-blur border-b border-gray-800', [
        div(classes: 'max-w-4xl mx-auto px-4', [
          div(classes: 'flex h-16 items-center justify-between', [
            Link(to: '/', child: span(classes: 'text-xl font-bold text-white', [Component.text('My Blog')])),
            nav(classes: 'flex items-center gap-6', [
              Link(to: '/', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Home')])),
              Link(to: '/blog', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Blog')])),
            ]),
          ]),
        ]),
      ]),
      div(classes: 'flex-1', [child]),
      footer(classes: 'bg-gray-900 border-t border-gray-800 py-8', [
        div(classes: 'max-w-4xl mx-auto px-4 text-center text-gray-400 text-sm', [
          Component.text('Built with Duxt'),
        ]),
      ]),
    ]);
  }
}
''';

String _blogHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'py-20 px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        h1(classes: 'text-5xl font-bold text-white mb-6', [
          Component.text('$projectName'),
        ]),
        p(classes: 'text-xl text-gray-400 mb-8', [
          Component.text('A blog built with Duxt'),
        ]),
        Link(
          to: '/blog',
          child: span(
            classes: 'inline-block px-6 py-3 bg-cyan-600 text-white rounded-lg hover:bg-cyan-700 transition-colors',
            [Component.text('Read the Blog')],
          ),
        ),
      ]),
    ]);
  }
}
''';
