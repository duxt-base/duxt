import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'layouts.dart';
import 'modules.dart';
import 'blog.dart';
import 'server.dart';
import 'web.dart';

/// Generates a new Duxt project from templates
class TemplateGenerator {
  static Future<void> generate(String projectName, String targetDir, {String mode = 'static'}) async {
    final dartName = projectName.replaceAll('-', '_').replaceAll(' ', '_');

    await _createDirectories(targetDir, mode: mode);
    await _writeFiles(dartName, targetDir, mode: mode);
    _printSuccess(dartName, mode: mode);
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
      'server', 'server/api', 'server/models',
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

    // Server (with DuxtORM)
    await _write(dir, 'server/main.dart', serverMainTemplate);
    await _write(dir, 'server/db.dart', dbTemplate);
    await _write(dir, 'server/models/post.dart', postModelTemplate);
    await _write(dir, 'server/api/posts.dart', postsApiTemplate);

    // Web (no index.html - jaspr's Document handles this)
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));

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
