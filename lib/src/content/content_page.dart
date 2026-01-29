/// Content page component for Duxt framework
///
/// Provides components for rendering markdown content pages with layouts.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'content_loader.dart';

/// Component for rendering a content document
class ContentPage extends StatelessComponent {
  /// The content document to render
  final ContentDocument document;

  /// Optional custom layout builder
  final Component Function(BuildContext, ContentDocument, List<Component>)?
      layoutBuilder;

  /// Whether to show table of contents
  final bool showToc;

  /// Custom CSS classes for the content wrapper
  final String? contentClasses;

  const ContentPage({
    required this.document,
    this.layoutBuilder,
    this.showToc = true,
    this.contentClasses,
  });

  @override
  Component build(BuildContext context) {
    final content = _buildContent();

    if (layoutBuilder != null) {
      return layoutBuilder!(context, document, content);
    } else {
      return _buildDefaultLayout(content);
    }
  }

  List<Component> _buildContent() {
    return [
      // Page header
      div(classes: 'content-header mb-8', [
        if (document.title.isNotEmpty)
          h1(
              classes: 'text-3xl font-bold text-white mb-2',
              [Component.text(document.title)]),
        if (document.description != null)
          p(
              classes: 'text-lg text-gray-400',
              [Component.text(document.description!)]),
      ]),
      // Main content - render HTML from markdown
      div(
        classes: contentClasses ?? 'prose prose-invert max-w-none',
        attributes: {'innerHTML': document.htmlContent},
        [],
      ),
    ];
  }

  Component _buildDefaultLayout(List<Component> content) {
    return div(classes: 'content-page flex', [
      // Main content area
      main_(classes: 'flex-1 max-w-3xl mx-auto px-8 py-12', content),
      // Table of contents sidebar
      if (showToc && document.tableOfContents.isNotEmpty)
        ContentToc(entries: document.tableOfContents),
    ]);
  }
}

/// Table of contents component
class ContentToc extends StatelessComponent {
  final List<TocEntry> entries;
  final String? title;

  const ContentToc({
    required this.entries,
    this.title = 'On this page',
  });

  @override
  Component build(BuildContext context) {
    return aside(
      classes: 'hidden lg:block w-64 pl-8 py-12',
      [
        div(classes: 'sticky top-24', [
          if (title != null)
            div(
                classes:
                    'text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4',
                [
                  Component.text(title!),
                ]),
          nav(classes: 'space-y-1', [
            for (final entry in entries) _buildTocEntry(entry),
          ]),
        ]),
      ],
    );
  }

  Component _buildTocEntry(TocEntry entry) {
    final indentClass = entry.level > 2 ? 'pl-${(entry.level - 2) * 4}' : '';
    return a(
      href: '#${entry.anchor}',
      classes:
          'block text-sm text-gray-400 hover:text-white transition-colors py-1 $indentClass',
      [Component.text(entry.text)],
    );
  }
}

/// Navigation sidebar component for content sections
class ContentNav extends StatelessComponent {
  final List<NavSection> sections;
  final String currentPath;

  const ContentNav({
    required this.sections,
    required this.currentPath,
  });

  @override
  Component build(BuildContext context) {
    return aside(
      classes:
          'fixed left-0 top-16 bottom-0 w-64 bg-gray-950 border-r border-gray-800 overflow-y-auto',
      [
        nav(classes: 'p-4 space-y-6', [
          for (final section in sections) _buildSection(section),
        ]),
      ],
    );
  }

  Component _buildSection(NavSection section) {
    return div([
      div(
          classes:
              'text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2',
          [
            Component.text(section.title),
          ]),
      ul(classes: 'space-y-1', [
        for (final item in section.items)
          li([
            a(
              href: item.path,
              classes:
                  'block text-sm py-1 ${currentPath == item.path ? 'text-indigo-400' : 'text-gray-400 hover:text-white'} transition-colors',
              [Component.text(item.title)],
            ),
          ]),
      ]),
    ]);
  }
}

/// Documentation layout component with sidebar, content, and TOC
class DocsContentLayout extends StatelessComponent {
  final ContentDocument document;
  final List<NavSection> navigation;
  final String currentPath;
  final Component? header;
  final Component? footer;

  const DocsContentLayout({
    required this.document,
    required this.navigation,
    required this.currentPath,
    this.header,
    this.footer,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen flex flex-col', [
      // Header
      if (header != null) header!,

      // Main layout
      div(classes: 'flex flex-1', [
        // Sidebar navigation
        ContentNav(sections: navigation, currentPath: currentPath),

        // Main content
        main_(classes: 'flex-1 ml-64 mr-64', [
          div(classes: 'max-w-3xl mx-auto px-8 py-12', [
            // Page header
            div(classes: 'mb-8', [
              h1(
                  classes: 'text-3xl font-bold text-white mb-2',
                  [Component.text(document.title)]),
              if (document.description != null)
                p(
                    classes: 'text-lg text-gray-400',
                    [Component.text(document.description!)]),
            ]),
            // Content
            div(
              classes: 'prose prose-invert max-w-none',
              attributes: {'innerHTML': document.htmlContent},
              [],
            ),
          ]),
        ]),

        // Table of contents
        if (document.tableOfContents.isNotEmpty)
          ContentToc(entries: document.tableOfContents),
      ]),

      // Footer
      if (footer != null) footer!,
    ]);
  }
}

/// Markdown content renderer component
///
/// Renders raw markdown as HTML content
class MarkdownContent extends StatelessComponent {
  final String markdown;
  final String? classes;

  const MarkdownContent({
    required this.markdown,
    this.classes,
  });

  @override
  Component build(BuildContext context) {
    // Convert markdown to HTML
    final html = _parseMarkdown(markdown);

    return div(
      classes: classes ?? 'prose prose-invert max-w-none',
      attributes: {'innerHTML': html},
      [],
    );
  }

  String _parseMarkdown(String markdown) {
    // Basic markdown parsing - in production, use the ContentLoader
    // This is a simplified version for direct markdown rendering
    var html = markdown;

    // Headers
    html = html.replaceAllMapped(
      RegExp(r'^######\s+(.+)$', multiLine: true),
      (m) => '<h6>${m.group(1)}</h6>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^#####\s+(.+)$', multiLine: true),
      (m) => '<h5>${m.group(1)}</h5>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^####\s+(.+)$', multiLine: true),
      (m) => '<h4>${m.group(1)}</h4>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^###\s+(.+)$', multiLine: true),
      (m) => '<h3>${m.group(1)}</h3>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^##\s+(.+)$', multiLine: true),
      (m) => '<h2>${m.group(1)}</h2>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^#\s+(.+)$', multiLine: true),
      (m) => '<h1>${m.group(1)}</h1>',
    );

    // Bold and italic
    html = html.replaceAllMapped(
      RegExp(r'\*\*\*(.+?)\*\*\*'),
      (m) => '<strong><em>${m.group(1)}</em></strong>',
    );
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );
    html = html.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (m) => '<em>${m.group(1)}</em>',
    );

    // Inline code
    html = html.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    // Links
    html = html.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // Paragraphs (simple)
    html = html.replaceAllMapped(
      RegExp(r'\n\n([^<\n][^\n]+)\n\n'),
      (m) => '\n\n<p>${m.group(1)}</p>\n\n',
    );

    return html;
  }
}

/// Code block component with syntax highlighting support
class ContentCodeBlock extends StatelessComponent {
  final String sourceCode;
  final String? language;
  final String? filename;
  final bool showLineNumbers;

  const ContentCodeBlock({
    required this.sourceCode,
    this.language,
    this.filename,
    this.showLineNumbers = false,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'code-block group my-4', [
      // Header with filename
      if (filename != null)
        div(
            classes:
                'flex items-center justify-between px-4 py-2 bg-gray-900 border-b border-gray-800 text-sm rounded-t-lg',
            [
              span(classes: 'text-gray-400', [Component.text(filename!)]),
              _buildCopyButton(),
            ]),
      // Code content
      div(classes: 'relative', [
        pre(
            classes:
                'p-4 overflow-x-auto ${filename == null ? 'rounded-lg' : 'rounded-b-lg'} bg-gray-900 border border-gray-800 ${filename != null ? 'border-t-0' : ''}',
            [
              code(
                  classes:
                      'language-${language ?? 'text'} text-sm text-gray-300',
                  [
                    if (showLineNumbers)
                      ..._buildLinesWithNumbers()
                    else
                      Component.text(sourceCode),
                  ]),
            ]),
        if (filename == null)
          div(
              classes:
                  'absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity',
              [
                _buildCopyButton(),
              ]),
      ]),
    ]);
  }

  List<Component> _buildLinesWithNumbers() {
    final lines = sourceCode.split('\n');
    final components = <Component>[];

    for (var i = 0; i < lines.length; i++) {
      components.add(
        div(classes: 'table-row', [
          span(
              classes: 'table-cell pr-4 text-gray-600 select-none text-right',
              [
                Component.text('${i + 1}'),
              ]),
          span(classes: 'table-cell', [Component.text(lines[i])]),
        ]),
      );
    }

    return [div(classes: 'table', components)];
  }

  Component _buildCopyButton() {
    final escapedCode = sourceCode.replaceAll('`', r'\`').replaceAll(r'$', r'\$');
    return button(
      classes:
          'p-2 text-gray-500 hover:text-white hover:bg-gray-800 rounded transition-colors',
      attributes: {
        'onclick': 'navigator.clipboard.writeText(`$escapedCode`)',
        'title': 'Copy to clipboard',
      },
      [
        span(classes: 'text-xs', [Component.text('Copy')])
      ],
    );
  }
}

/// Callout/alert component for documentation
class ContentCallout extends StatelessComponent {
  final String type; // info, warning, error, tip, note
  final String? title;
  final List<Component> children;

  const ContentCallout({
    this.type = 'info',
    this.title,
    required this.children,
  });

  @override
  Component build(BuildContext context) {
    return div(
        classes: 'rounded-lg border-l-4 $_borderColor $_bgColor p-4 my-4',
        [
          if (title != null || _defaultTitle != null)
            div(classes: 'font-semibold $_titleColor mb-2', [
              Component.text(title ?? _defaultTitle!),
            ]),
          div(classes: 'text-gray-300 text-sm', children),
        ]);
  }

  String get _borderColor {
    switch (type) {
      case 'warning':
        return 'border-yellow-500';
      case 'error':
      case 'danger':
        return 'border-red-500';
      case 'tip':
      case 'success':
        return 'border-green-500';
      case 'note':
        return 'border-blue-500';
      default:
        return 'border-indigo-500';
    }
  }

  String get _bgColor {
    switch (type) {
      case 'warning':
        return 'bg-yellow-500/10';
      case 'error':
      case 'danger':
        return 'bg-red-500/10';
      case 'tip':
      case 'success':
        return 'bg-green-500/10';
      case 'note':
        return 'bg-blue-500/10';
      default:
        return 'bg-indigo-500/10';
    }
  }

  String get _titleColor {
    switch (type) {
      case 'warning':
        return 'text-yellow-400';
      case 'error':
      case 'danger':
        return 'text-red-400';
      case 'tip':
      case 'success':
        return 'text-green-400';
      case 'note':
        return 'text-blue-400';
      default:
        return 'text-indigo-400';
    }
  }

  String? get _defaultTitle {
    switch (type) {
      case 'warning':
        return 'Warning';
      case 'error':
      case 'danger':
        return 'Error';
      case 'tip':
        return 'Tip';
      case 'success':
        return 'Success';
      case 'note':
        return 'Note';
      case 'info':
        return 'Info';
      default:
        return null;
    }
  }
}
