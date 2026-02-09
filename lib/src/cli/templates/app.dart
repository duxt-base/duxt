/// App.dart template
const appTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt/duxt.dart';
import 'package:duxt/content.dart';

// Generated routes
import '.generated/routes.dart' as generated;

// Shared
import 'shared/layouts/default.dart';
import 'shared/layouts/page.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    final routes = generated.generatedRoutes(
      config: DuxtPageConfig(
        layouts: [const DefaultPageLayout()],
      ),
    );

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

/// main.client.dart template
const mainClientTemplate = r'''
import 'package:jaspr/client.dart';
import 'package:duxt/duxt.dart';

import 'main.client.options.dart';

void main() {
  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultClientOptions);
  runApp(const ClientApp());
}
''';

/// main.server.dart template (for static/server modes)
String mainServerTemplate(String projectName) => '''
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:duxt/duxt.dart';
import 'app.dart';

import 'main.server.options.dart';

void main() {
  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: '$projectName',
    head: [
      link(href: '/styles.css', rel: 'stylesheet'),
    ],
    body: App(),
  ));
}
''';

/// main.server.dart template with ORM initialization (for server mode)
/// Models are added by scaffold command
String serverModeMainServerTemplate(String projectName) => '''
import 'dart:io';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:duxt/duxt.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'app.dart';

import 'main.server.options.dart';

void main() async {
  // Register models here (added by scaffold command)

  // Initialize ORM for SSR data fetching
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

  // Auto-migrate database tables
  await DuxtOrm.migrate();

  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: '$projectName',
    head: [
      link(href: '/styles.css', rel: 'stylesheet'),
    ],
    body: App(),
  ));
}
''';

/// main.server.dart template for blog (with ORM initialization for SSR)
String blogMainServerTemplate(String projectName) => '''
import 'dart:io';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:duxt/duxt.dart';
import 'package:duxt_orm/duxt_orm.dart';
import 'app.dart';
import 'models/category.dart';
import 'models/post.dart';

import 'main.server.options.dart';

void main() async {
  // Initialize ORM for SSR data fetching
  Category.register();
  Post.register();

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

  // Auto-migrate database tables
  await DuxtOrm.migrate();

  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: '$projectName',
    head: [
      link(href: '/styles.css', rel: 'stylesheet'),
    ],
    body: App(),
  ));
}
''';
