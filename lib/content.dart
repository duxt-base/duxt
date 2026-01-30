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
/// - Custom component embedding in markdown
/// - jaspr_content integration
///
/// ## Usage
///
/// ### Using DuxtContentApp (Recommended)
///
/// ```dart
/// import 'package:duxt/content.dart';
///
/// // In main.server.dart
/// runApp(
///   Document(
///     body: DuxtContentApp(
///       layouts: [DocsLayout(), UiLayout()],
///       components: [CodeBlock(), Callout(), Image(zoom: true)],
///       theme: ContentTheme(
///         primary: ThemeColor(ThemeColors.cyan.$500),
///       ),
///     ),
///   ),
/// );
/// ```
///
/// ### Using ContentLoader (Manual)
///
/// ```dart
/// import 'package:duxt/content.dart';
///
/// final loader = ContentLoader(
///   config: ContentLoaderConfig(
///     contentDir: 'content',
///     includeDrafts: false,
///   ),
/// );
///
/// final doc = await loader.load('getting-started/index');
/// final docs = await loader.loadDirectory('components');
/// final nav = await loader.loadNavigation();
/// ```
library;

export 'src/content/content.dart';
export 'src/content/duxt_content_app.dart';
