/// DuxtContentPage - Renders markdown content from module content directories
///
/// This component is used by generated routes to render markdown files
/// that are located in `lib/&lt;module&gt;/content/` directories.
library;

import 'dart:io';
import 'package:jaspr/server.dart';
import 'package:jaspr_router/jaspr_router.dart' show RouteBase;
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';
import 'package:path/path.dart' as p;
import '../components/error_page.dart';

export 'package:jaspr_content/jaspr_content.dart'
    show PageLayoutBase, CustomComponent, PageExtension;
export 'package:jaspr_content/theme.dart' show ContentTheme, ThemeColor;

/// Route information for content pages (used at runtime)
class ContentRouteInfo {
  final String path;
  final String filePath;
  final String moduleName;

  const ContentRouteInfo({
    required this.path,
    required this.filePath,
    required this.moduleName,
  });
}

/// Configuration for DuxtPage rendering
class DuxtPageConfig {
  /// Page layouts (first one is used as fallback)
  final List<PageLayoutBase> layouts;

  /// Custom components that can be used in markdown
  final List<CustomComponent> components;

  /// Content theme
  final ContentTheme? theme;

  /// Page extensions for post-processing
  final List<PageExtension> extensions;

  const DuxtPageConfig({
    this.layouts = const [],
    this.components = const [],
    this.theme,
    this.extensions = const [],
  });
}

/// Renders markdown content pages with the unified layout system
///
/// This component is automatically used by generated routes when
/// a route points to a markdown file in a module's content directory.
class DuxtContentPage extends AsyncStatelessComponent {
  final ContentRouteInfo routeInfo;
  final DuxtPageConfig? config;

  const DuxtContentPage({
    super.key,
    required this.routeInfo,
    this.config,
  });

  @override
  Future<Component> build(BuildContext context) async {
    final file = File(routeInfo.filePath);
    if (!file.existsSync()) {
      return _buildErrorPage('Content not found');
    }

    final content = await file.readAsString();
    final effectiveConfig = config ?? const DuxtPageConfig();

    // Create a single-page loader for this content
    final loader = _SinglePageLoader(
      filePath: routeInfo.filePath,
      url: routeInfo.path,
      content: content,
      config: PageConfig(
        parsers: [MarkdownParser()],
        extensions: [
          HeadingAnchorsExtension(),
          TableOfContentsExtension(),
          ...effectiveConfig.extensions,
        ],
        components: effectiveConfig.components,
        layouts: effectiveConfig.layouts,
        theme: effectiveConfig.theme,
      ),
    );

    // Create and build the page manually (render() requires ContentApp context)
    final page = loader.createPage();
    page.parseFrontmatter();
    await page.loadData();
    return await page.build();
  }

  Component _buildErrorPage(String message) {
    return DuxtErrorPage(
      statusCode: 404,
      path: routeInfo.path,
      message: message,
    );
  }
}

/// Simple loader for a single content page
class _SinglePageLoader implements RouteLoader {
  final String filePath;
  final String url;
  final String content;
  final PageConfig config;

  _SinglePageLoader({
    required this.filePath,
    required this.url,
    required this.content,
    required this.config,
  });

  Page createPage() {
    return Page(
      path: filePath,
      url: url,
      content: content,
      config: config,
      loader: this,
    );
  }

  @override
  Future<List<RouteBase>> loadRoutes(ConfigResolver resolver, bool eager) async {
    return [];
  }

  @override
  Future<String> readPartial(String path, Page page) async {
    // Prevent path traversal: partials must resolve within the project
    final canonical = p.canonicalize(path);
    final projectDir = p.canonicalize(Directory.current.path);
    if (!canonical.startsWith(projectDir)) {
      throw Exception('Partial path outside project');
    }

    final file = File(canonical);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('Partial not found');
  }

  @override
  String readPartialSync(String path, Page page) {
    final canonical = p.canonicalize(path);
    final projectDir = p.canonicalize(Directory.current.path);
    if (!canonical.startsWith(projectDir)) {
      throw Exception('Partial path outside project');
    }

    final file = File(canonical);
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
    throw Exception('Partial not found');
  }

  @override
  void invalidatePage(Page page) {
    // No-op for single page loader
  }
}
