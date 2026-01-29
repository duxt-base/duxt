/// Content loader for Duxt framework
///
/// Provides utilities to load and parse markdown content files with frontmatter support.
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:markdown/markdown.dart' as md;

/// Represents parsed content with frontmatter and body
class ContentDocument {
  /// Frontmatter metadata (title, description, etc.)
  final Map<String, dynamic> frontmatter;

  /// Raw markdown body content
  final String rawContent;

  /// Parsed HTML content
  final String htmlContent;

  /// Table of contents extracted from headings
  final List<TocEntry> tableOfContents;

  /// File path relative to content directory
  final String path;

  /// Slug derived from file path
  final String slug;

  ContentDocument({
    required this.frontmatter,
    required this.rawContent,
    required this.htmlContent,
    required this.tableOfContents,
    required this.path,
    required this.slug,
  });

  /// Get title from frontmatter
  String get title => frontmatter['title']?.toString() ?? '';

  /// Get description from frontmatter
  String? get description => frontmatter['description']?.toString();

  /// Get navigation order from frontmatter
  int get order => frontmatter['order'] as int? ?? 999;

  /// Get layout from frontmatter
  String? get layout => frontmatter['layout']?.toString();

  /// Get draft status from frontmatter
  bool get draft => frontmatter['draft'] as bool? ?? false;
}

/// Table of contents entry
class TocEntry {
  final String text;
  final String anchor;
  final int level;
  final List<TocEntry> children;

  TocEntry({
    required this.text,
    required this.anchor,
    required this.level,
    List<TocEntry>? children,
  }) : children = children ?? [];
}

/// Content loader configuration
class ContentLoaderConfig {
  /// Base directory for content files
  final String contentDir;

  /// File extensions to process
  final List<String> extensions;

  /// Whether to include draft content
  final bool includeDrafts;

  /// Custom markdown extensions
  final List<md.BlockSyntax> blockSyntaxes;

  /// Custom inline syntaxes
  final List<md.InlineSyntax> inlineSyntaxes;

  ContentLoaderConfig({
    this.contentDir = 'content',
    this.extensions = const ['.md', '.markdown'],
    this.includeDrafts = false,
    this.blockSyntaxes = const [],
    this.inlineSyntaxes = const [],
  });
}

/// Content loader for loading and parsing markdown files
class ContentLoader {
  final ContentLoaderConfig config;
  final Map<String, ContentDocument> _cache = {};

  ContentLoader({ContentLoaderConfig? config})
      : config = config ?? ContentLoaderConfig();

  /// Load a single content file by path
  Future<ContentDocument?> load(String filePath) async {
    // Check cache first
    if (_cache.containsKey(filePath)) {
      return _cache[filePath];
    }

    final fullPath = p.join(config.contentDir, filePath);
    final file = File(fullPath);

    if (!await file.exists()) {
      // Try with extensions
      for (final ext in config.extensions) {
        final fileWithExt = File('$fullPath$ext');
        if (await fileWithExt.exists()) {
          return _parseFile(fileWithExt, filePath);
        }
      }
      return null;
    }

    return _parseFile(file, filePath);
  }

  /// Load all content files from a directory
  Future<List<ContentDocument>> loadDirectory(String dirPath) async {
    final fullPath = p.join(config.contentDir, dirPath);
    final dir = Directory(fullPath);

    if (!await dir.exists()) {
      return [];
    }

    final documents = <ContentDocument>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = p.extension(entity.path);
        if (config.extensions.contains(ext)) {
          final relativePath = p.relative(entity.path, from: config.contentDir);
          final doc = await _parseFile(entity, relativePath);
          if (doc != null && (config.includeDrafts || !doc.draft)) {
            documents.add(doc);
          }
        }
      }
    }

    // Sort by order, then by title
    documents.sort((a, b) {
      final orderCompare = a.order.compareTo(b.order);
      return orderCompare != 0 ? orderCompare : a.title.compareTo(b.title);
    });

    return documents;
  }

  /// Load all content and build navigation structure
  Future<List<NavSection>> loadNavigation() async {
    final dir = Directory(config.contentDir);
    if (!await dir.exists()) {
      return [];
    }

    final sections = <String, NavSection>{};

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final sectionName = p.basename(entity.path);
        final docs = await loadDirectory(sectionName);

        if (docs.isNotEmpty) {
          sections[sectionName] = NavSection(
            title: _formatTitle(sectionName),
            path: '/$sectionName',
            items: docs.map((doc) => NavItem(
              title: doc.title,
              path: '/${doc.slug}',
              description: doc.description,
            )).toList(),
          );
        }
      }
    }

    return sections.values.toList();
  }

  /// Parse a markdown file into a ContentDocument
  Future<ContentDocument?> _parseFile(File file, String relativePath) async {
    try {
      final content = await file.readAsString();
      final parsed = _parseFrontmatter(content);

      // Generate slug from path
      final slug = _generateSlug(relativePath);

      // Parse markdown to HTML
      final html = _parseMarkdown(parsed.body);

      // Extract table of contents
      final toc = _extractToc(parsed.body);

      final doc = ContentDocument(
        frontmatter: parsed.frontmatter,
        rawContent: parsed.body,
        htmlContent: html,
        tableOfContents: toc,
        path: relativePath,
        slug: slug,
      );

      _cache[relativePath] = doc;
      return doc;
    } catch (e) {
      print('Error parsing content file $relativePath: $e');
      return null;
    }
  }

  /// Parse frontmatter from content
  _ParsedContent _parseFrontmatter(String content) {
    final frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n', multiLine: true);
    final match = frontmatterRegex.firstMatch(content);

    if (match != null) {
      final yamlContent = match.group(1) ?? '';
      final body = content.substring(match.end);

      try {
        final yaml = loadYaml(yamlContent);
        final frontmatter = yaml is Map
            ? Map<String, dynamic>.from(yaml)
            : <String, dynamic>{};
        return _ParsedContent(frontmatter: frontmatter, body: body);
      } catch (e) {
        print('Error parsing frontmatter YAML: $e');
        return _ParsedContent(frontmatter: {}, body: content);
      }
    }

    return _ParsedContent(frontmatter: {}, body: content);
  }

  /// Parse markdown to HTML
  String _parseMarkdown(String markdown) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubWeb,
      blockSyntaxes: config.blockSyntaxes,
      inlineSyntaxes: config.inlineSyntaxes,
    );

    final lines = markdown.split('\n');
    final nodes = document.parseLines(lines);
    return md.renderToHtml(nodes);
  }

  /// Extract table of contents from markdown headings
  List<TocEntry> _extractToc(String markdown) {
    final headingRegex = RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true);
    final entries = <TocEntry>[];

    for (final match in headingRegex.allMatches(markdown)) {
      final level = match.group(1)!.length;
      final text = match.group(2)!.trim();
      final anchor = _slugify(text);

      // Only include h2-h4 in TOC
      if (level >= 2 && level <= 4) {
        entries.add(TocEntry(
          text: text,
          anchor: anchor,
          level: level,
        ));
      }
    }

    return entries;
  }

  /// Generate slug from file path
  String _generateSlug(String path) {
    // Remove extension
    var slug = path;
    for (final ext in config.extensions) {
      if (slug.endsWith(ext)) {
        slug = slug.substring(0, slug.length - ext.length);
        break;
      }
    }

    // Handle index files
    if (slug.endsWith('/index') || slug == 'index') {
      slug = slug.replaceAll(RegExp(r'/index$|^index$'), '');
    }

    // Normalize path separators
    slug = slug.replaceAll(r'\', '/');

    return slug.isEmpty ? '' : slug;
  }

  /// Format directory name as title
  String _formatTitle(String name) {
    return name
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  /// Convert text to URL-safe anchor
  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  /// Clear the content cache
  void clearCache() {
    _cache.clear();
  }
}

/// Helper class for parsed frontmatter content
class _ParsedContent {
  final Map<String, dynamic> frontmatter;
  final String body;

  _ParsedContent({required this.frontmatter, required this.body});
}

/// Navigation section for sidebar
class NavSection {
  final String title;
  final String path;
  final List<NavItem> items;

  NavSection({
    required this.title,
    required this.path,
    required this.items,
  });
}

/// Navigation item
class NavItem {
  final String title;
  final String path;
  final String? description;

  NavItem({
    required this.title,
    required this.path,
    this.description,
  });
}
