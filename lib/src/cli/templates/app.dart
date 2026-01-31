/// App.dart template
const appTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

// Generated routes
import '.generated/routes.dart' as generated;

// Shared
import 'shared/layouts/default.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    final routes = generated.generatedRoutes();

    final wrappedRoutes = routes.map((route) => Route(
      path: route.path,
      builder: (context, state) => DefaultLayout(
        child: Builder(builder: (ctx) => route.builder!(ctx, state)),
      ),
    )).toList();

    return Router(routes: wrappedRoutes);
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
