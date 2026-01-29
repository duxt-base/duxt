/// Content support for Duxt framework
///
/// Provides markdown content loading, parsing, and rendering capabilities
/// for building documentation sites and content-driven applications.
///
/// ## Features
///
/// - Frontmatter parsing (title, description, etc.)
/// - Markdown to HTML conversion
/// - Table of contents generation
/// - Navigation structure building
/// - Documentation layouts
///
/// ## Usage
///
/// ```dart
/// import 'package:duxt/content.dart';
///
/// // Configure the content loader
/// final loader = ContentLoader(
///   config: ContentLoaderConfig(
///     contentDir: 'content',
///     includeDrafts: false,
///   ),
/// );
///
/// // Load a single document
/// final doc = await loader.load('getting-started/index');
///
/// // Load all documents from a directory
/// final docs = await loader.loadDirectory('components');
///
/// // Build navigation from content structure
/// final nav = await loader.loadNavigation();
/// ```
library;

export 'src/content/content.dart';
