import 'package:jaspr/client.dart';
import 'package:duxt/duxt.dart';

import 'main.client.options.dart';

void main() {
  Api.configure(baseUrl: '/api');
  Jaspr.initializeApp(options: defaultClientOptions);
  runApp(const ClientApp());
}
