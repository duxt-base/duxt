/// Environment sample template
const envSampleTemplate = r'''
# Server configuration
PORT=4100

# Data directory for SQLite database
DATA_DIR=.

# Uncomment for PostgreSQL:
# DB_DRIVER=postgres
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=myapp
# DB_USER=postgres
# DB_PASS=secret
''';

/// Server main.dart template
String serverMainTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt/server.dart';
import 'db.dart';
import 'package:$projectName/models/category.dart';
import 'package:$projectName/models/post.dart';
import 'api/posts.dart';
import 'api/categories.dart';

void main() async {
  // Initialize ORM and run migrations
  await Db.init();

  // Seed sample data
  await Category.seed();
  await Post.seed();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3001;

  final server = DuxtServer(
    port: port,
    middleware: [securityHeaders(), bodyLimit(), cors(origins: [\'http://localhost:4000\']), jsonBody(), logger()],
  );

  registerCategoryRoutes(server);
  registerPostRoutes(server);

  server.start();
}
''';

/// Database connection template (using DuxtORM)
String dbTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:$projectName/models/category.dart';
import 'package:$projectName/models/post.dart';

class Db {
  static Future<void> init() async {
    // Register models (order matters for foreign keys)
    Category.register();
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

/// Blog-specific database connection template (with Tag support)
String blogDbTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:$projectName/models/category.dart';
import 'package:$projectName/models/tag.dart';
import 'package:$projectName/models/post.dart';

class Db {
  static Future<void> init() async {
    // Register models (order matters for foreign keys)
    // 1. Independent entities first
    Category.register();
    Tag.register();
    // 2. Entities with relations (Post has FK to Category, M2M to Tags)
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

    // Run migrations (creates tables + pivot tables)
    await DuxtOrm.migrate();
  }
}
''';

/// Blog-specific server main.dart template (with Tag routes)
String blogServerMainTemplate(String projectName) => '''
import 'dart:io';
import 'package:duxt/server.dart';
import 'db.dart';
import 'package:$projectName/models/category.dart';
import 'package:$projectName/models/tag.dart';
import 'package:$projectName/models/post.dart';
import 'api/posts.dart';
import 'api/categories.dart';
import 'api/tags.dart';

void main() async {
  // Initialize ORM and run migrations
  await Db.init();

  // Seed sample data
  await Category.seed();
  await Tag.seed();
  await Post.seed();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3001;

  final server = DuxtServer(
    port: port,
    middleware: [securityHeaders(), bodyLimit(), cors(origins: [\'http://localhost:4000\']), jsonBody(), logger()],
  );

  registerCategoryRoutes(server);
  registerTagRoutes(server);
  registerPostRoutes(server);

  server.start();
}
''';

/// Post model template (using DuxtORM with relations)
const postModelTemplate = r'''
import 'package:duxt_orm/duxt_orm.dart';
import 'category.dart';

class Post extends Entity {
  int? _id;
  String title;
  String slug;
  String content;
  String? excerpt;
  int? categoryId;
  bool published;
  DateTime? createdAt;

  Post({
    int? id,
    required this.title,
    required this.slug,
    required this.content,
    this.excerpt,
    this.categoryId,
    this.published = false,
    this.createdAt,
  }) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

  // Relation accessor - returns loaded category (use .with_(['category']) to load)
  Category? get category => getRelation<Category>('category');

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'slug': slug,
        'content': content,
        'excerpt': excerpt,
        'category_id': categoryId,
        'published': published ? 1 : 0,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'content': content,
        'excerpt': excerpt,
        'categoryId': categoryId,
        'category': category?.toJson(),
        'published': published,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Post.fromRow(Map<String, dynamic> row) => Post(
        id: row['id'] as int?,
        title: row['title'] as String,
        slug: row['slug'] as String,
        content: row['content'] as String,
        excerpt: row['excerpt'] as String?,
        categoryId: row['category_id'] as int?,
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
        categoryId: json['categoryId'] as int?,
        published: json['published'] as bool? ?? false,
      );

  static void register() {
    // Register model with schema
    Entity.registerModel<Post>(
      Post.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
        'title': Column.string(200).notNull(),
        'slug': Column.string(200).unique().notNull(),
        'content': Column.text().notNull(),
        'excerpt': Column.text().nullable(),
        'category_id': Column.integer().nullable().references('categories'),
        'published': Column.boolean().defaultValue(false),
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );

    // Register BelongsTo relation: Post belongs to Category
    Entity.registerRelation<Post>(
      'category',
      BelongsTo<Category>(foreignKey: 'category_id'),
    );
  }

  // Query helpers
  static Future<List<Post>> findAll({bool publishedOnly = false, bool withCategory = false}) async {
    var query = Model<Post>().query();

    // Eager load category if requested
    if (withCategory) {
      query = query.with_(['category']);
    }

    if (publishedOnly) {
      query = query.where('published', 1);
    }

    return query.orderByDesc('created_at').get();
  }

  static Future<Post?> findById(int id, {bool withCategory = false}) async {
    var query = Model<Post>().query().where('id', id);
    if (withCategory) {
      query = query.with_(['category']);
    }
    return query.first();
  }

  static Future<Post?> findBySlug(String slug, {bool withCategory = false}) async {
    var query = Model<Post>().query().where('slug', slug);
    if (withCategory) {
      query = query.with_(['category']);
    }
    return query.first();
  }

  // Seed data
  static Future<void> seed() async {
    final count = await Model<Post>().count();
    if (count > 0) return;

    // Get categories for seeding
    final categories = await Model<Category>().all();
    final tutorialsCat = categories.where((c) => c.slug == 'tutorials').firstOrNull;
    final newsCat = categories.where((c) => c.slug == 'news').firstOrNull;

    final post1 = Post(
      title: 'Getting Started with Duxt',
      slug: 'getting-started',
      content: '# Getting Started\n\nWelcome to Duxt!\n\nDuxt is a fullstack framework for Dart.',
      excerpt: 'Learn how to build apps with Duxt.',
      categoryId: tutorialsCat?.id as int?,
      published: true,
    );
    await post1.save();

    final post2 = Post(
      title: 'Building APIs with DuxtORM',
      slug: 'building-apis',
      content: '# Building APIs\n\nDuxtORM provides an ActiveRecord-style API for database operations.',
      excerpt: 'Build REST APIs with DuxtORM.',
      categoryId: tutorialsCat?.id as int?,
      published: true,
    );
    await post2.save();

    final post3 = Post(
      title: 'Duxt 0.4.0 Released',
      slug: 'duxt-0-4-0-released',
      content: '# Duxt 0.4.0\n\nNew features include relations, eager loading, and template selection!',
      excerpt: 'Major release with ORM relations support.',
      categoryId: newsCat?.id as int?,
      published: true,
    );
    await post3.save();
  }
}
''';

/// Category model template (using DuxtORM with relations)
const categoryModelTemplate = r'''
import 'package:duxt_orm/duxt_orm.dart';
import 'post.dart';

class Category extends Entity {
  int? _id;
  String name;
  String slug;
  String? description;
  DateTime? createdAt;

  Category({
    int? id,
    required this.name,
    required this.slug,
    this.description,
    this.createdAt,
  }) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

  // Relation accessor - returns loaded posts (use .with_(['posts']) to load)
  List<Post> get posts => getRelation<List<Post>>('posts') ?? [];

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'createdAt': createdAt?.toIso8601String(),
      };

  /// Include posts in JSON output (after eager loading)
  Map<String, dynamic> toJsonWithPosts() => {
        ...toJson(),
        'posts': posts.map((p) => p.toJson()).toList(),
      };

  factory Category.fromRow(Map<String, dynamic> row) => Category(
        id: row['id'] as int?,
        name: row['name'] as String,
        slug: row['slug'] as String,
        description: row['description'] as String?,
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
      );

  static void register() {
    // Register model with schema
    Entity.registerModel<Category>(
      Category.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
        'name': Column.string(100).notNull(),
        'slug': Column.string(100).unique().notNull(),
        'description': Column.text().nullable(),
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );

    // Register HasMany relation: Category has many Posts
    Entity.registerRelation<Category>(
      'posts',
      HasMany<Post>(foreignKey: 'category_id'),
    );
  }

  // Query helpers
  static Future<List<Category>> findAll({bool withPosts = false}) async {
    var query = Model<Category>().query();
    if (withPosts) {
      query = query.with_(['posts']);
    }
    return query.orderBy('name').get();
  }

  static Future<Category?> findById(int id, {bool withPosts = false}) async {
    var query = Model<Category>().query().where('id', id);
    if (withPosts) {
      query = query.with_(['posts']);
    }
    return query.first();
  }

  static Future<Category?> findBySlug(String slug, {bool withPosts = false}) async {
    var query = Model<Category>().query().where('slug', slug);
    if (withPosts) {
      query = query.with_(['posts']);
    }
    return query.first();
  }

  // Seed data
  static Future<void> seed() async {
    final count = await Model<Category>().count();
    if (count > 0) return;

    final cat1 = Category(
      name: 'Tutorials',
      slug: 'tutorials',
      description: 'Step-by-step guides and tutorials',
    );
    await cat1.save();

    final cat2 = Category(
      name: 'News',
      slug: 'news',
      description: 'Latest updates and announcements',
    );
    await cat2.save();

    final cat3 = Category(
      name: 'Tips & Tricks',
      slug: 'tips-tricks',
      description: 'Quick tips and best practices',
    );
    await cat3.save();
  }
}
''';

/// Categories API routes template
String categoriesApiTemplate(String projectName) => '''
import 'package:duxt/server.dart';
import 'package:$projectName/models/category.dart';

void registerCategoryRoutes(DuxtServer server) {
  // GET /api/categories - List all categories
  server.get('/api/categories', (req) async {
    final categories = await Category.findAll();
    return json({'categories': categories.map((c) => c.toJson()).toList()});
  });

  // GET /api/categories/:slug - Get category with posts
  server.get('/api/categories/:slug', (req) async {
    final slug = req.params['slug'];
    if (slug == null) return json({'error': 'Slug required'}, statusCode: 400);

    // Eager load posts with the category
    final category = await Category.findBySlug(slug, withPosts: true);
    if (category == null) return json({'error': 'Not found'}, statusCode: 404);

    return json({'category': category.toJsonWithPosts()});
  });

  // POST /api/categories - Create new category
  server.post('/api/categories', (req) async {
    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    try {
      final category = Category.fromJson(body);
      await category.save();
      return json({'category': category.toJson()}, statusCode: 201);
    } catch (e) {
      print('Create failed: \$e');
      return json({'error': 'Invalid request data'}, statusCode: 400);
    }
  });
}
''';

/// Tag model template (using DuxtORM with BelongsToMany relations)
const tagModelTemplate = r'''
import 'package:duxt_orm/duxt_orm.dart';

class Tag extends Entity {
  int? _id;
  String name;
  String slug;
  String? color;
  DateTime? createdAt;

  Tag({
    int? id,
    required this.name,
    required this.slug,
    this.color,
    this.createdAt,
  }) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'slug': slug,
        'color': color,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'color': color,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Tag.fromRow(Map<String, dynamic> row) => Tag(
        id: row['id'] as int?,
        name: row['name'] as String,
        slug: row['slug'] as String,
        color: row['color'] as String?,
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as int?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        color: json['color'] as String?,
      );

  static void register() {
    Entity.registerModel<Tag>(
      Tag.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
        'name': Column.string(100).notNull(),
        'slug': Column.string(100).unique().notNull(),
        'color': Column.string(50).nullable(),
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );
  }

  // Query helpers
  static Future<List<Tag>> findAll() async {
    return Model<Tag>().query().orderBy('name').get();
  }

  static Future<Tag?> findById(int id) async {
    return Model<Tag>().find(id);
  }

  static Future<Tag?> findBySlug(String slug) async {
    return Model<Tag>().query().where('slug', slug).first();
  }

  // Seed data
  static Future<void> seed() async {
    final count = await Model<Tag>().count();
    if (count > 0) return;

    final tags = [
      Tag(name: 'Dart', slug: 'dart', color: '#0175C2'),
      Tag(name: 'Flutter', slug: 'flutter', color: '#02569B'),
      Tag(name: 'Jaspr', slug: 'jaspr', color: '#00D9FF'),
      Tag(name: 'Backend', slug: 'backend', color: '#4CAF50'),
      Tag(name: 'Frontend', slug: 'frontend', color: '#FF9800'),
    ];

    for (final tag in tags) {
      await tag.save();
    }
  }
}
''';

/// Tags API routes template
String tagsApiTemplate(String projectName) => '''
import 'package:duxt/server.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:$projectName/models/tag.dart';

void registerTagRoutes(DuxtServer server) {
  // GET /api/tags - List all tags
  server.get('/api/tags', (req) async {
    final tags = await Tag.findAll();
    return json({'tags': tags.map((t) => t.toJson()).toList()});
  });

  // GET /api/tags/:slug - Get tag by slug
  server.get('/api/tags/:slug', (req) async {
    final slug = req.params['slug'];
    if (slug == null) return json({'error': 'Slug required'}, statusCode: 400);

    final tag = await Tag.findBySlug(slug);
    if (tag == null) return json({'error': 'Not found'}, statusCode: 404);

    return json({'tag': tag.toJson()});
  });

  // POST /api/tags - Create new tag
  server.post('/api/tags', (req) async {
    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    try {
      final tag = Tag.fromJson(body);
      await tag.save();
      return json({'tag': tag.toJson()}, statusCode: 201);
    } catch (e) {
      print('Create failed: \$e');
      return json({'error': 'Invalid request data'}, statusCode: 400);
    }
  });

  // DELETE /api/tags/:id - Delete tag
  server.delete('/api/tags/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) return json({'error': 'Invalid ID'}, statusCode: 400);

    final tag = await Model<Tag>().find(id);
    if (tag == null) return json({'error': 'Not found'}, statusCode: 404);

    await tag.destroy();
    return json({'success': true});
  });
}
''';

/// Post model template with Tags (many-to-many via pivot table)
const postWithTagsModelTemplate = r'''
import 'package:duxt_orm/duxt_orm.dart';
import 'category.dart';
import 'tag.dart';

class Post extends Entity {
  int? _id;
  String title;
  String slug;
  String content;
  String? excerpt;
  String? featuredImage;
  int? categoryId;
  bool published;
  DateTime? publishDate;
  DateTime? createdAt;

  Post({
    int? id,
    required this.title,
    required this.slug,
    required this.content,
    this.excerpt,
    this.featuredImage,
    this.categoryId,
    this.published = false,
    this.publishDate,
    this.createdAt,
  }) : _id = id;

  @override
  dynamic get id => _id;

  @override
  set id(dynamic value) => _id = value as int?;

  // Relation accessors - use .with_(['category', 'tags']) to load
  Category? get category => getRelation<Category>('category');
  List<Tag> get tags => getRelation<List<Tag>>('tags') ?? [];

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'slug': slug,
        'content': content,
        'excerpt': excerpt,
        'featured_image': featuredImage,
        'category_id': categoryId,
        'published': published ? 1 : 0,
        'publish_date': publishDate?.toIso8601String(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'content': content,
        'excerpt': excerpt,
        'featuredImage': featuredImage,
        'categoryId': categoryId,
        'category': category?.toJson(),
        'tags': tags.map((t) => t.toJson()).toList(),
        'published': published,
        'publishDate': publishDate?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Post.fromRow(Map<String, dynamic> row) => Post(
        id: row['id'] as int?,
        title: row['title'] as String,
        slug: row['slug'] as String,
        content: row['content'] as String,
        excerpt: row['excerpt'] as String?,
        featuredImage: row['featured_image'] as String?,
        categoryId: row['category_id'] as int?,
        published: (row['published'] as int?) == 1,
        publishDate: row['publish_date'] != null
            ? DateTime.tryParse(row['publish_date'] as String)
            : null,
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
        featuredImage: json['featuredImage'] as String?,
        categoryId: json['categoryId'] as int?,
        published: json['published'] as bool? ?? false,
        publishDate: json['publishDate'] != null
            ? DateTime.tryParse(json['publishDate'] as String)
            : null,
      );

  static void register() {
    // Register model with schema
    Entity.registerModel<Post>(
      Post.fromRow,
      schema: {
        'id': Column.integer().primaryKey().autoIncrement(),
        'title': Column.string(200).notNull(),
        'slug': Column.string(200).unique().notNull(),
        'content': Column.text().notNull(),
        'excerpt': Column.text().nullable(),
        'featured_image': Column.string(500).nullable(),
        'category_id': Column.integer().nullable().references('categories'),
        'published': Column.boolean().defaultValue(false),
        'publish_date': Column.dateTime().nullable(),
        'created_at': Column.dateTime().nullable(),
        'updated_at': Column.dateTime().nullable(),
      },
    );

    // Register BelongsTo relation: Post belongs to Category
    Entity.registerRelation<Post>(
      'category',
      BelongsTo<Category>(foreignKey: 'category_id'),
    );

    // Register BelongsToMany relation: Post has many Tags (via pivot table)
    Entity.registerRelation<Post>(
      'tags',
      BelongsToMany<Tag>(
        pivotTable: 'post_tags',
        foreignPivotKey: 'post_id',
        relatedPivotKey: 'tag_id',
      ),
    );

    // Register pivot table for post_tags
    Entity.registerPivotTable('post_tags', schema: {
      'post_id': Column.integer().notNull().references('posts'),
      'tag_id': Column.integer().notNull().references('tags'),
    }, primaryKey: ['post_id', 'tag_id']);
  }

  // Query helpers
  static Future<List<Post>> findAll({
    bool publishedOnly = false,
    bool withCategory = false,
    bool withTags = false,
  }) async {
    var query = Model<Post>().query();

    // Eager load relations if requested
    final relations = <String>[];
    if (withCategory) relations.add('category');
    if (withTags) relations.add('tags');
    if (relations.isNotEmpty) {
      query = query.with_(relations);
    }

    if (publishedOnly) {
      query = query.where('published', 1);
    }

    return query.orderByDesc('created_at').get();
  }

  static Future<Post?> findById(int id, {bool withCategory = false, bool withTags = false}) async {
    var query = Model<Post>().query().where('id', id);
    final relations = <String>[];
    if (withCategory) relations.add('category');
    if (withTags) relations.add('tags');
    if (relations.isNotEmpty) {
      query = query.with_(relations);
    }
    return query.first();
  }

  static Future<Post?> findBySlug(String slug, {bool withCategory = false, bool withTags = false}) async {
    var query = Model<Post>().query().where('slug', slug);
    final relations = <String>[];
    if (withCategory) relations.add('category');
    if (withTags) relations.add('tags');
    if (relations.isNotEmpty) {
      query = query.with_(relations);
    }
    return query.first();
  }

  /// Attach a tag to this post
  Future<void> addTag(int tagId) => attach('tags', tagId);

  /// Remove a tag from this post
  Future<void> removeTag(int tagId) => detach('tags', tagId);

  /// Sync tags (replace all with given IDs)
  Future<void> setTags(List<int> tagIds) => sync('tags', tagIds);

  // Seed data
  static Future<void> seed() async {
    final count = await Model<Post>().count();
    if (count > 0) return;

    // Get categories and tags for seeding
    final categories = await Model<Category>().all();
    final allTags = await Model<Tag>().all();
    final tutorialsCat = categories.where((c) => c.slug == 'tutorials').firstOrNull;
    final newsCat = categories.where((c) => c.slug == 'news').firstOrNull;
    final dartTag = allTags.where((t) => t.slug == 'dart').firstOrNull;
    final jasprTag = allTags.where((t) => t.slug == 'jaspr').firstOrNull;
    final backendTag = allTags.where((t) => t.slug == 'backend').firstOrNull;

    final post1 = Post(
      title: 'Getting Started with Duxt',
      slug: 'getting-started',
      content: '# Getting Started\n\nWelcome to Duxt!\n\nDuxt is a fullstack framework for Dart.',
      excerpt: 'Learn how to build apps with Duxt.',
      categoryId: tutorialsCat?.id as int?,
      published: true,
    );
    await post1.save();
    if (dartTag != null) await post1.addTag(dartTag.id as int);
    if (jasprTag != null) await post1.addTag(jasprTag.id as int);

    final post2 = Post(
      title: 'Building APIs with DuxtORM',
      slug: 'building-apis',
      content: '# Building APIs\n\nDuxtORM provides an ActiveRecord-style API for database operations.',
      excerpt: 'Build REST APIs with DuxtORM.',
      categoryId: tutorialsCat?.id as int?,
      published: true,
    );
    await post2.save();
    if (dartTag != null) await post2.addTag(dartTag.id as int);
    if (backendTag != null) await post2.addTag(backendTag.id as int);

    final post3 = Post(
      title: 'Duxt 0.4.0 Released',
      slug: 'duxt-0-4-0-released',
      content: '# Duxt 0.4.0\n\nNew features include relations, eager loading, and template selection!',
      excerpt: 'Major release with ORM relations support.',
      categoryId: newsCat?.id as int?,
      published: true,
    );
    await post3.save();
    if (dartTag != null) await post3.addTag(dartTag.id as int);
  }
}
''';

/// Posts API routes template (using DuxtORM with relations)
String postsApiTemplate(String projectName) => '''
import 'package:duxt/server.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'package:$projectName/models/post.dart';

void registerPostRoutes(DuxtServer server) {
  // GET /api/posts - List all published posts with categories
  server.get('/api/posts', (req) async {
    // Eager load category with each post (prevents N+1 queries)
    final posts = await Post.findAll(publishedOnly: true, withCategory: true);
    return json({'posts': posts.map((p) => p.toJson()).toList()});
  });

  // GET /api/posts/:slug - Get single post with category by slug
  server.get('/api/posts/:slug', (req) async {
    final slug = req.params['slug'];
    if (slug == null) return json({'error': 'Slug required'}, statusCode: 400);

    // Eager load category with the post
    final post = await Post.findBySlug(slug, withCategory: true);
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
      print('Create failed: \$e');
      return json({'error': 'Invalid request data'}, statusCode: 400);
    }
  });

  // PUT /api/posts/:id - Update post
  server.put('/api/posts/:id', (req) async {
    final id = int.tryParse(req.params['id'] ?? '');
    if (id == null) return json({'error': 'Invalid ID'}, statusCode: 400);

    final body = req.body as Map<String, dynamic>?;
    if (body == null) return json({'error': 'Body required'}, statusCode: 400);

    final post = await Model<Post>().find(id);
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

    final post = await Model<Post>().find(id);
    if (post == null) return json({'error': 'Not found'}, statusCode: 404);

    await post.destroy();
    return json({'success': true});
  });
}
''';
