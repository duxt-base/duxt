// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:test_desktop/demo/pages/index.dart' deferred as _index;
import 'package:test_desktop/home/pages/index.dart' deferred as _pages_index;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'index': ClientLoader((p) => _index.DemoPage(), loader: _index.loadLibrary),
    'pages/index': ClientLoader(
      (p) => _pages_index.HomePage(),
      loader: _pages_index.loadLibrary,
    ),
  },
);
