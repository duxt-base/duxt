/// DuxtContentApp - Wrapper for jaspr_content's ContentApp
///
/// Provides a Duxt-flavored content application for building documentation
/// sites with markdown support, custom components, and layouts.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

export 'package:jaspr_content/jaspr_content.dart'
    show
        ContentApp,
        MarkdownParser,
        PageParser,
        PageExtension,
        HeadingAnchorsExtension,
        TableOfContentsExtension,
        Page,
        PageLayoutBase,
        CustomComponent,
        CustomComponentBase,
        MustacheTemplateEngine,
        TemplateEngine;

export 'package:jaspr_content/theme.dart'
    show ContentTheme, ThemeColor, ThemeColors;

export 'package:jaspr_content/components/callout.dart' show Callout;
export 'package:jaspr_content/components/code_block.dart' show CodeBlock;
export 'package:jaspr_content/components/image.dart' show Image;

/// Duxt-flavored ContentApp for documentation sites
///
/// Wraps jaspr_content's ContentApp with sensible defaults and
/// Duxt conventions for building documentation sites.
///
/// ## Usage
///
/// ```dart
/// import 'package:duxt/content.dart';
///
/// // In main.server.dart
/// runApp(
///   Document(
///     body: DuxtContentApp(
///       layouts: [DocsLayout(), UiLayout()],
///       components: [MyCustomComponent()],
///     ),
///   ),
/// );
/// ```
class DuxtContentApp extends StatelessComponent {
  /// Directory containing content files (default: 'content')
  final String contentDir;

  /// Whether to eagerly load all pages at startup
  final bool eagerlyLoadAllPages;

  /// Template engine for processing templates (default: MustacheTemplateEngine)
  final TemplateEngine? templateEngine;

  /// Content parsers (default: [MarkdownParser()])
  final List<PageParser> parsers;

  /// Page extensions for post-processing
  final List<PageExtension> extensions;

  /// Custom components that can be used in content
  final List<CustomComponent> components;

  /// Page layouts
  final List<PageLayoutBase> layouts;

  /// Content theme
  final ContentTheme? theme;

  const DuxtContentApp({
    this.contentDir = 'content',
    this.eagerlyLoadAllPages = false,
    this.templateEngine,
    this.parsers = const [],
    this.extensions = const [],
    this.components = const [],
    this.layouts = const [],
    this.theme,
  });

  @override
  Component build(BuildContext context) {
    return ContentApp(
      directory: contentDir,
      eagerlyLoadAllPages: eagerlyLoadAllPages,
      templateEngine: templateEngine ?? MustacheTemplateEngine(),
      parsers: parsers.isEmpty ? [MarkdownParser()] : parsers,
      extensions: [
        HeadingAnchorsExtension(),
        TableOfContentsExtension(),
        ...extensions,
      ],
      components: components,
      layouts: layouts,
      theme: theme,
    );
  }
}

/// Base class for Duxt documentation layouts
///
/// Extends jaspr_content's PageLayoutBase with Duxt conventions.
///
/// ## Usage
///
/// ```dart
/// class DocsLayout extends DuxtPageLayout {
///   @override
///   String get name => 'docs-layout';
///
///   @override
///   Component buildHeader(Page page) {
///     return SiteHeader();
///   }
///
///   @override
///   Component buildSidebar(Page page) {
///     return DocsSidebar();
///   }
///
///   @override
///   Component buildBody(Page page, Component child) {
///     return div(classes: 'flex', [
///       buildSidebar(page),
///       main_(classes: 'flex-1', [child]),
///     ]);
///   }
/// }
/// ```
abstract class DuxtPageLayout extends PageLayoutBase {
  const DuxtPageLayout();

  /// Build the page header component
  Component buildHeader(Page page) => div([]);

  /// Build the sidebar navigation component
  Component buildSidebar(Page page) => div([]);

  /// Build the table of contents component (optional)
  Component? buildToc(Page page) => null;

  /// Build the page footer component
  Component buildFooter(Page page) => div([]);
}
