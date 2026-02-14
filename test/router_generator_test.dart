import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:duxt/src/core/router_generator.dart';

void main() {
  group('RouteInfo', () {
    test('toString includes path, component and module', () {
      final route = RouteInfo(
        path: '/blog',
        filePath: '/lib/blog/pages/index.dart',
        componentName: 'BlogPage',
        moduleName: 'blog',
        params: [],
        isCatchAll: false,
      );
      expect(route.toString(), contains('/blog'));
      expect(route.toString(), contains('BlogPage'));
      expect(route.toString(), contains('blog'));
    });

    test('content route toString shows content type', () {
      final route = RouteInfo(
        path: '/docs/intro',
        filePath: '/lib/docs/content/intro.md',
        componentName: '',
        moduleName: 'docs',
        params: [],
        isCatchAll: false,
        type: RouteType.content,
      );
      expect(route.toString(), contains('content'));
    });
  });

  group('RouteType', () {
    test('has dart and content values', () {
      expect(RouteType.values, hasLength(2));
      expect(RouteType.values, contains(RouteType.dart));
      expect(RouteType.values, contains(RouteType.content));
    });
  });

  group('RouterGenerator.generate', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duxt_router_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('creates .generated directory and routes.dart', () async {
      // Create a minimal module structure
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'home', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';

class HomePage extends StatelessComponent {
  const HomePage();

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield const Text('Home');
  }
}
''');

      await RouterGenerator.generate(tempDir.path);

      final outputFile = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart'));
      expect(outputFile.existsSync(), isTrue);

      final content = outputFile.readAsStringSync();
      expect(content, contains('GENERATED CODE'));
      expect(content, contains('generatedRoutes'));
      expect(content, contains("path: '/'"));
      expect(content, contains('HomePage'));
    });

    test('generates routes for multiple modules', () async {
      // Home module
      final homePages = Directory(p.join(tempDir.path, 'lib', 'home', 'pages'));
      homePages.createSync(recursive: true);
      File(p.join(homePages.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class HomePage extends StatelessComponent {
  const HomePage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      // Blog module
      final blogPages = Directory(p.join(tempDir.path, 'lib', 'blog', 'pages'));
      blogPages.createSync(recursive: true);
      File(p.join(blogPages.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class BlogPage extends StatelessComponent {
  const BlogPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains("path: '/'"));
      expect(content, contains("path: '/blog'"));
    });

    test('handles dynamic route parameters with bracket syntax', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'blog', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, '[slug].dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class BlogPostPage extends StatelessComponent {
  const BlogPostPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains(':slug'));
    });

    test('handles dynamic route parameters with underscore syntax', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'blog', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, '_id_.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class BlogDetailPage extends StatelessComponent {
  const BlogDetailPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains(':id'));
    });

    test('handles content routes from markdown files', () async {
      final contentDir = Directory(p.join(tempDir.path, 'lib', 'docs', 'content'));
      contentDir.createSync(recursive: true);

      File(p.join(contentDir.path, 'getting-started.md')).writeAsStringSync('# Getting Started');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains('/docs/getting-started'));
      expect(content, contains('DuxtContentPage'));
      expect(content, contains("import 'package:duxt/content.dart'"));
    });

    test('handles theme namespace - strips theme/ prefix', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'theme', 'blog', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class ThemeBlogPage extends StatelessComponent {
  const ThemeBlogPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      // theme/blog -> /blog (strips theme/ prefix)
      expect(content, contains("path: '/blog'"));
    });

    test('theme/home maps to root /', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'theme', 'home', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class ThemeHomePage extends StatelessComponent {
  const ThemeHomePage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains("path: '/'"));
    });

    test('skips files without valid component class', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'home', 'pages'));
      pagesDir.createSync(recursive: true);

      // File with no component class
      File(p.join(pagesDir.path, 'utils.dart')).writeAsStringSync('''
String formatDate(DateTime date) => date.toString();
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains('generatedRoutes'));
      // Should not generate any route entries for utils.dart
      expect(content, isNot(contains('formatDate')));
    });

    test('handles no lib directory gracefully', () async {
      // No lib/ directory — should not crash
      await RouterGenerator.generate(tempDir.path);

      final outputFile = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart'));
      expect(outputFile.existsSync(), isFalse);
    });

    test('sorts static routes before dynamic routes', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'blog', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, '_id_.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class BlogDetailPage extends StatelessComponent {
  const BlogDetailPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');
      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class BlogIndexPage extends StatelessComponent {
  const BlogIndexPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();

      // Static route (/blog) should come before dynamic (/blog/:id)
      final staticIndex = content.indexOf("path: '/blog'");
      final dynamicIndex = content.indexOf("path: '/blog/:id'");
      expect(staticIndex, lessThan(dynamicIndex));
    });

    test('extracts required constructor params as route params', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'users', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';

class UserPage extends StatelessComponent {
  final String id;

  const UserPage({super.key, required this.id});

  @override
  Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains(':id'));
      expect(content, contains("state.params['id']"));
    });

    test('skips internal directories', () async {
      // .generated should be skipped
      final genPages = Directory(p.join(tempDir.path, 'lib', '.generated', 'pages'));
      genPages.createSync(recursive: true);
      File(p.join(genPages.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class GenPage extends StatelessComponent {
  const GenPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      // shared should be skipped
      final sharedPages = Directory(p.join(tempDir.path, 'lib', 'shared', 'pages'));
      sharedPages.createSync(recursive: true);
      File(p.join(sharedPages.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class SharedPage extends StatelessComponent {
  const SharedPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final outputFile = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart'));
      final content = outputFile.readAsStringSync();
      expect(content, isNot(contains('GenPage')));
      expect(content, isNot(contains('SharedPage')));
    });

    test('skips write when routes unchanged', () async {
      // Create a module
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'home', 'pages'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class HomePage extends StatelessComponent {
  const HomePage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      // Generate once
      await RouterGenerator.generate(tempDir.path);
      final outputFile = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart'));
      expect(outputFile.existsSync(), isTrue);

      final firstContent = outputFile.readAsStringSync();
      final firstModified = outputFile.lastModifiedSync();

      // Wait a moment so timestamps differ if the file were rewritten
      await Future.delayed(const Duration(milliseconds: 50));

      // Generate again — routes haven't changed, file should NOT be rewritten
      await RouterGenerator.generate(tempDir.path);
      final secondContent = outputFile.readAsStringSync();
      final secondModified = outputFile.lastModifiedSync();

      expect(secondContent, equals(firstContent));
      // File should not have been rewritten (same modification time)
      expect(secondModified, equals(firstModified));
    });

    test('handles nested subdirectory pages', () async {
      final pagesDir = Directory(p.join(tempDir.path, 'lib', 'blog', 'pages', 'category'));
      pagesDir.createSync(recursive: true);

      File(p.join(pagesDir.path, 'index.dart')).writeAsStringSync('''
import 'package:jaspr/jaspr.dart';
class CategoryPage extends StatelessComponent {
  const CategoryPage();
  @override Iterable<Component> build(BuildContext context) sync* {}
}
''');

      await RouterGenerator.generate(tempDir.path);

      final content = File(p.join(tempDir.path, 'lib', '.generated', 'routes.dart')).readAsStringSync();
      expect(content, contains('/blog/category'));
    });
  });
}
