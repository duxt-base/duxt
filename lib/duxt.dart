/// Duxt - A Nuxt-like meta-framework for Jaspr
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
library duxt;

// Runtime exports - for use in Duxt projects
export 'src/runtime/page.dart';
export 'src/runtime/layout.dart';
export 'src/runtime/middleware.dart';
export 'src/runtime/composable.dart';

// Core exports for code generation
export 'src/core/router_generator.dart' show RouteInfo;
export 'src/core/layout_system.dart' show LayoutSystem;
