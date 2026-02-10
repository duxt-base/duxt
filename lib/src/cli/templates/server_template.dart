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

  static Future<void> _writeFiles(String projectName, String dir) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _serverPubspec(projectName));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, 'duxt.config.dart', _serverConfig(projectName));
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _serverAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    await _write(dir, 'lib/main.server.dart', blogMainServerTemplate(projectName));

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _serverLayoutTemplate(projectName));

    // Home page
    await _write(dir, 'lib/home/pages/index.dart', _serverHomeTemplate(projectName));

    // Blog pages (SSR)
    await _write(dir, 'lib/blog/pages/index.dart', _serverBlogIndexTemplate);
    await _write(dir, 'lib/blog/pages/_slug_.dart', _serverBlogPostTemplate);

    // Models
    await _write(dir, 'lib/models/post.dart', _serverPostModel);

    // Server (DuxtServer + ORM)
    await _write(dir, 'server/main.dart', _serverMainTemplate(projectName));
    await _write(dir, 'server/db.dart', _serverDbTemplate(projectName));
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

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created server project with DuxtORM');
    print('');
    print('  lib/');
    print('    ├── home/pages/index.dart       → /');
    print('    ├── blog/pages/');
    print('    │   ├── index.dart              → /blog (SSR listing)');
    print('    │   └── _slug_.dart             → /blog/:slug');
    print('    ├── models/post.dart');
    print('    ├── shared/layouts/');
    print('    ├── .generated/routes.dart      (auto-generated)');
    print('    └── app.dart');
    print('');
    print('  server/                           (DuxtORM + API)');
    print('    ├── main.dart');
    print('    ├── db.dart');
    print('    └── api/posts.dart');
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
/// Duxt configuration
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

  /// Database configuration
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
                      to: '/blog',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('Blog'),
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

/// Server home page
String _serverHomeTemplate(String projectName) => '''
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
        className: 'max-w-3xl mx-auto text-center',
        children: [
          Span(
            className: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-cyan-400 bg-cyan-500/10 rounded-full',
            child: Text('Server-Rendered'),
          ),
          H1(
            className: 'text-5xl font-bold text-white mb-6',
            child: Text('$projectName'),
          ),
          P(
            className: 'text-xl text-gray-400 mb-10',
            child: Text('A server-rendered Duxt app with ORM and API routes.'),
          ),
          Div(
            className: 'flex justify-center gap-4',
            children: [
              Link(
                to: '/blog',
                child: Span(
                  className: 'px-6 py-3 bg-cyan-600 text-white rounded-lg hover:bg-cyan-700 transition-colors inline-block',
                  child: Text('Read the Blog'),
                ),
              ),
              A(
                href: 'https://duxt.dev/duxt',
                target: Target.blank,
                className: 'px-6 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-800 transition-colors',
                child: Text('Documentation'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
''';

/// Server blog index - SSR with AsyncStatelessComponent using duxt_html
const _serverBlogIndexTemplate = r'''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:jaspr/server.dart';
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_ui/duxt_ui.dart';

import '../../models/post.dart';

/// Blog listing page - renders posts on the server
class BlogPage extends AsyncStatelessComponent {
  const BlogPage({super.key});

  @override
  Future<Component> build(BuildContext context) async {
    final posts = await Post.findAll(publishedOnly: true);

    return Div(
      className: 'pt-24 pb-20 px-4',
      child: Div(
        className: 'max-w-4xl mx-auto',
        children: [
          Div(
            className: 'text-center mb-12',
            children: [
              DBadge(label: 'Blog', color: DBadgeColor.primary),
              H1(
                className: 'text-4xl font-bold text-white mt-4 mb-4',
                child: Text('Latest Posts'),
              ),
              P(
                className: 'text-gray-400',
                child: Text('Server-rendered with DuxtORM'),
              ),
            ],
          ),
          if (posts.isEmpty)
            Div(
              className: 'text-center py-12',
              child: P(
                className: 'text-gray-400',
                child: Text('No posts yet. Create one via the API: POST /api/posts'),
              ),
            )
          else
            Div(
              className: 'space-y-6',
              children: [
                for (final post in posts)
                  _postCard(post),
              ],
            ),
        ],
      ),
    );
  }

  Component _postCard(Post post) {
    return A(
      href: '/blog/${post.slug}',
      className: 'block bg-gray-800/50 rounded-xl p-6 border border-gray-700/50 hover:border-cyan-500/50 transition-colors',
      children: [
        H2(
          className: 'text-xl font-semibold text-white mb-2',
          child: Text(post.title),
        ),
        if (post.excerpt != null)
          P(
            className: 'text-gray-400 mb-4',
            child: Text(post.excerpt!),
          ),
        Span(
          className: 'text-cyan-400 text-sm',
          child: Text('Read more →'),
        ),
      ],
    );
  }
}
''';

/// Server blog post detail - SSR with AsyncStatelessComponent using duxt_html
const _serverBlogPostTemplate = r'''
import 'package:jaspr/jaspr.dart' hide Text;
import 'package:jaspr/server.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_ui/duxt_ui.dart';

import '../../models/post.dart';

/// Blog post detail page - renders post on the server
class BlogPostPage extends AsyncStatelessComponent {
  final String slug;
  const BlogPostPage({required this.slug, super.key});

  @override
  Future<Component> build(BuildContext context) async {
    final post = await Post.findBySlug(slug);

    return Div(
      className: 'pt-24 pb-20 px-4',
      child: Div(
        className: 'max-w-3xl mx-auto',
        children: [
          Div(
            className: 'mb-8',
            child: Link(
              to: '/blog',
              child: Span(
                className: 'text-cyan-400 hover:text-cyan-300',
                child: Text('← Back to Blog'),
              ),
            ),
          ),
          if (post == null)
            DAlert(title: 'Error', description: 'Post not found', color: DAlertColor.error)
          else
            Article(
              children: [
                H1(
                  className: 'text-4xl font-bold text-white mb-4',
                  child: Text(post.title),
                ),
                if (post.excerpt != null)
                  P(
                    className: 'text-xl text-gray-400 mb-8',
                    child: Text(post.excerpt!),
                  ),
                Div(
                  className: 'prose prose-invert max-w-none',
                  children: [
                    for (final line in post.content.split('\n'))
                      _renderLine(line),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Component _renderLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return Div(className: 'h-4');
    if (t.startsWith('# ')) return H1(className: 'text-3xl font-bold text-white mt-8 mb-4', child: Text(t.substring(2)));
    if (t.startsWith('## ')) return H2(className: 'text-2xl font-semibold text-white mt-6 mb-3', child: Text(t.substring(3)));
    if (t.startsWith('### ')) return H3(className: 'text-xl font-semibold text-white mt-4 mb-2', child: Text(t.substring(4)));
    return P(className: 'text-gray-300 mb-2', child: Text(line));
  }
}
''';

/// Simplified Post model (no category/tag relations - kept simple for starter template)
const _serverPostModel = r'''
import 'package:duxt_orm/duxt_orm.dart';

class Post extends Entity {
  int? _id;
  String title;
  String slug;
  String content;
  String? excerpt;
  bool published;
  DateTime? createdAt;

  Post({
    int? id,
    required this.title,
    required this.slug,
    required this.content,
    this.excerpt,
    this.published = false,
    this.createdAt,
  }) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'slug': slug,
        'content': content,
        'excerpt': excerpt,
        'published': published ? 1 : 0,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'content': content,
        'excerpt': excerpt,
        'published': published,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Post.fromRow(Map<String, dynamic> row) => Post(
        id: row['id'] as int?,
        title: row['title'] as String,
        slug: row['slug'] as String,
        content: row['content'] as String,
        excerpt: row['excerpt'] as String?,
        published: (row['published'] as int?) == 1,
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int?,
        title: json['title'] as String,
        slug: json['slug'] as String,
        content: json['content'] as String,
        excerpt: json['excerpt'] as String?,
        published: json['published'] as bool? ?? false,
      );

  static void register() {
    Entity.registerModel<Post>(
      Post.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
        'title': Column.string(200).notNull(),
        'slug': Column.string(200).unique().notNull(),
        'content': Column.text().notNull(),
        'excerpt': Column.text().nullable(),
        'published': Column.boolean().defaultValue(false),
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );
  }

  // Query helpers
  static Future<List<Post>> findAll({bool publishedOnly = false}) async {
    var query = Model<Post>().query();
    if (publishedOnly) {
      query = query.where('published', 1);
    }
    return query.orderByDesc('created_at').get();
  }

  static Future<Post?> findBySlug(String slug) async {
    return Model<Post>().query().where('slug', slug).first();
  }

  // Seed data
  static Future<void> seed() async {
    final count = await Model<Post>().count();
    if (count > 0) return;

    final post1 = Post(
      title: 'Getting Started with Duxt',
      slug: 'getting-started',
      content: '# Getting Started\n\nWelcome to Duxt!\n\nDuxt is a fullstack framework for Dart.',
      excerpt: 'Learn how to build apps with Duxt.',
      published: true,
    );
    await post1.save();

    final post2 = Post(
      title: 'Building APIs with DuxtORM',
      slug: 'building-apis',
      content: '# Building APIs\n\nDuxtORM provides an ActiveRecord-style API for database operations.',
      excerpt: 'Build REST APIs with DuxtORM.',
      published: true,
    );
    await post2.save();
  }
}
''';

/// Server main.dart (DuxtServer entry)
String _serverMainTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt/server.dart';
import 'db.dart';
import 'package:$projectName/models/post.dart';
import 'api/posts.dart';

void main() async {
  // Initialize ORM and run migrations
  await Db.init();

  // Seed sample data
  await Post.seed();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3001;

  final server = DuxtServer(
    port: port,
    middleware: [securityHeaders(), bodyLimit(), cors(origins: [\'http://localhost:4000\']), jsonBody(), logger()],
  );

  registerPostRoutes(server);

  server.start();
}
''';

/// Server db.dart
String _serverDbTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:$projectName/models/post.dart';

class Db {
  static Future<void> init() async {
    // Register models
    Post.register();

    // Initialize ORM with SQLite
    final dataDir = Platform.environment['DATA_DIR'] ?? '.';
    await DuxtOrm.init((
      driver: 'sqlite',
      host: '',
      port: 0,
      database: '',
      username: '',
      password: '',
      path: '\$dataDir/app.db',
      ssl: false,
    ));

    // Run migrations (creates tables)
    await DuxtOrm.migrate();
  }
}
''';
