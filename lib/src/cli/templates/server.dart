/// Server main.dart template
const serverMainTemplate = r'''
import 'dart:io';
import 'package:duxt/server.dart';
import 'db.dart';
import 'models/post.dart';
import 'api/posts.dart';

void main() async {
  // Initialize ORM and run migrations
  await Db.init();

  // Seed sample data
  await Post.seed();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3001;

  final server = DuxtServer(
    port: port,
    middleware: [cors(), jsonBody(), logger()],
  );

  registerPostRoutes(server);

  server.start();
}
''';

/// Database connection template (using DuxtORM)
const dbTemplate = r'''
import 'dart:io';
import 'package:duxt_orm/duxt_orm.dart';
import 'models/post.dart';

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
      path: '$dataDir/app.db',
      ssl: false,
    ));

    // Run migrations (creates tables)
    await DuxtOrm.migrate();
  }
}
''';

/// Post model template (using DuxtORM)
const postModelTemplate = r'''
import 'package:duxt_orm/duxt_orm.dart';

class Post extends Model {
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
    Model.registerModel<Post>(
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
    if (publishedOnly) {
      return Model.where<Post>('published', 1).orderByDesc('created_at').get();
    }
    return Model.query<Post>().orderByDesc('created_at').get();
  }

  static Future<Post?> findById(int id) => Model.find<Post>(id);

  static Future<Post?> findBySlug(String slug) =>
      Model.where<Post>('slug', slug).first();

  // Seed data
  static Future<void> seed() async {
    final count = await Model.count<Post>();
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

/// Posts API routes template (using DuxtORM)
const postsApiTemplate = r'''
import 'package:duxt/server.dart';
import 'package:duxt_orm/duxt_orm.dart';
import '../models/post.dart';

void registerPostRoutes(DuxtServer server) {
  // GET /api/posts - List all published posts
  server.get('/api/posts', (req) async {
    final posts = await Post.findAll(publishedOnly: true);
    return json({'posts': posts.map((p) => p.toJson()).toList()});
  });

  // GET /api/posts/:slug - Get single post by slug
  server.get('/api/posts/:slug', (req) async {
    final slug = req.params['slug'];
    if (slug == null) return json({'error': 'Slug required'}, statusCode: 400);

    final post = await Post.findBySlug(slug);
    if (post == null) return json({'error': 'Not found'}, statusCode: 404);

    return json({'post': post.toJson()});
  });

  // POST /api/posts - Create new post
  server.post('/api/posts', (req) async {
    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    try {
      final post = Post.fromJson(body);
      await post.save();
      return json({'post': post.toJson()}, statusCode: 201);
    } catch (e) {
      return json({'error': e.toString()}, statusCode: 400);
    }
  });

  // PUT /api/posts/:id - Update post
  server.put('/api/posts/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) return json({'error': 'Invalid ID'}, statusCode: 400);

    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    final post = await Model.find<Post>(id);
    if (post == null) return json({'error': 'Not found'}, statusCode: 404);

    // Update fields
    post.title = body['title'] as String? ?? post.title;
    post.slug = body['slug'] as String? ?? post.slug;
    post.content = body['content'] as String? ?? post.content;
    post.excerpt = body['excerpt'] as String? ?? post.excerpt;
    post.published = body['published'] as bool? ?? post.published;

    await post.save();
    return json({'post': post.toJson()});
  });

  // DELETE /api/posts/:id - Delete post
  server.delete('/api/posts/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) return json({'error': 'Invalid ID'}, statusCode: 400);

    final post = await Model.find<Post>(id);
    if (post == null) return json({'error': 'Not found'}, statusCode: 404);

    await post.destroy();
    return json({'success': true});
  });
}
''';
