/// Content module for Duxt framework
///
/// Provides utilities for loading and rendering markdown content
/// with frontmatter support, table of contents generation, and
/// documentation layouts.
///
/// ## Usage
///
/// ```dart
/// import 'package:duxt/content.dart';
///
/// // Load content
/// final loader = ContentLoader();
/// final doc = await loader.load('getting-started/index.md');
///
/// // Render in component
/// yield ContentPage(document: doc);
/// ```
library;

export 'content_loader.dart';
export 'content_page.dart';
