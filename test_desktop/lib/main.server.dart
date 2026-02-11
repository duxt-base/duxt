import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:duxt/duxt.dart';
import 'app.dart';

import 'main.server.options.dart';

void main() {
  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: 'test_desktop',
    head: [
      link(href: '/styles.css', rel: 'stylesheet'),
    ],
    body: App(),
  ));
}
