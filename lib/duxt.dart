/// Duxt - A modern meta-framework for Jaspr
///
/// Provides file-based routing, layouts, middleware, and more.
///
/// ## Usage
/// ```dart
/// import 'package:duxt/duxt.dart';
/// ```
///
/// For server API handlers:
/// ```dart
/// import 'package:duxt/server.dart';
/// ```
///
/// For content/documentation support:
/// ```dart
/// import 'package:duxt/content.dart';
/// ```
library duxt;

// Runtime exports - for use in Duxt projects
export 'src/runtime/page.dart';
export 'src/runtime/layout.dart';
export 'src/runtime/middleware.dart';
export 'src/runtime/composable.dart';
export 'src/runtime/api.dart';
export 'src/runtime/duxt_state.dart';
export 'src/runtime/d_modal.dart';

// Content exports are available via 'package:duxt/content.dart'
