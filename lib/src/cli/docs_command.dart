import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Docs command - generate and manage documentation
/// Usage: `duxt docs <subcommand>`
///
/// Subcommands:
///   generate         Generate API docs from code
///   `page <name>`    Create a documentation page
///   `tutorial <name>` Create a tutorial page
class DocsCommand extends Command<int> {
  @override
  final name = 'docs';

  @override
  final description = 'Generate and manage documentation';

  DocsCommand() {
    addSubcommand(_DocsGenerateCommand());
    addSubcommand(_DocsPageCommand());
    addSubcommand(_DocsTutorialCommand());
  }
}

/// Generate API docs from code comments
class _DocsGenerateCommand extends Command<int> {
  @override
  final name = 'generate';

  @override
  final description = 'Generate API documentation from code comments';

  _DocsGenerateCommand() {
    argParser.addOption('output', abbr: 'o', defaultsTo: 'docs/api',
        help: 'Output directory for generated docs');
    argParser.addOption('format', abbr: 'f', defaultsTo: 'markdown',
        allowed: ['markdown', 'html'], help: 'Output format');
  }

  @override
  Future<int> run() async {
    final outputDir = argResults!['output'] as String;
    final format = argResults!['format'] as String;
    final projectDir = Directory.current.path;

    print('');
    print('\x1B[36mGenerating API documentation...\x1B[0m');
    print('');

    // Find all Dart files in lib/
    final libDir = Directory(p.join(projectDir, 'lib'));
    if (!libDir.existsSync()) {
      print('\x1B[31m✗\x1B[0m No lib/ directory found');
      return 1;
    }

    // Create output directory
    await Directory(p.join(projectDir, outputDir)).create(recursive: true);

    // Find model files to document
    final modelFiles = await _findDartFiles(libDir, 'models');
    final apiFiles = await _findDartFiles(libDir, null, '_api.dart');

    print('  Found ${modelFiles.length} model files');
    print('  Found ${apiFiles.length} API files');

    // Generate index
    final indexContent = _generateDocsIndex(modelFiles, apiFiles);
    await File(p.join(projectDir, outputDir, 'index.${format == 'markdown' ? 'md' : 'html'}'))
        .writeAsString(indexContent);
    print('  \x1B[32m✓\x1B[0m Generated $outputDir/index.${format == 'markdown' ? 'md' : 'html'}');

    // Generate model docs
    for (final file in modelFiles) {
      final name = p.basenameWithoutExtension(file.path);
      final content = await _generateModelDoc(file, format);
      await File(p.join(projectDir, outputDir, 'models', '$name.${format == 'markdown' ? 'md' : 'html'}'))
          .create(recursive: true)
          .then((f) => f.writeAsString(content));
      print('  \x1B[32m✓\x1B[0m Generated $outputDir/models/$name.${format == 'markdown' ? 'md' : 'html'}');
    }

    print('');
    print('\x1B[32m✓ Documentation generated!\x1B[0m');
    print('');
    print('  Output: $outputDir/');
    return 0;
  }

  Future<List<File>> _findDartFiles(Directory dir, [String? subdir, String? pattern]) async {
    final files = <File>[];
    final searchDir = subdir != null ? Directory(p.join(dir.path, subdir)) : dir;

    if (!searchDir.existsSync()) return files;

    await for (final entity in searchDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (pattern == null || entity.path.contains(pattern)) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  String _generateDocsIndex(List<File> modelFiles, List<File> apiFiles) {
    final buffer = StringBuffer();
    buffer.writeln('# API Documentation');
    buffer.writeln('');
    buffer.writeln('Generated from source code.');
    buffer.writeln('');

    if (modelFiles.isNotEmpty) {
      buffer.writeln('## Models');
      buffer.writeln('');
      for (final file in modelFiles) {
        final name = p.basenameWithoutExtension(file.path);
        final className = _toPascalCase(name);
        buffer.writeln('- [$className](models/$name.md)');
      }
      buffer.writeln('');
    }

    if (apiFiles.isNotEmpty) {
      buffer.writeln('## API Endpoints');
      buffer.writeln('');
      for (final file in apiFiles) {
        final name = p.basenameWithoutExtension(file.path).replaceAll('_api', '');
        buffer.writeln('- [${_toPascalCase(name)} API](api/$name.md)');
      }
    }

    return buffer.toString();
  }

  Future<String> _generateModelDoc(File file, String format) async {
    final content = await file.readAsString();
    final name = p.basenameWithoutExtension(file.path);
    final className = _toPascalCase(name);

    final buffer = StringBuffer();
    buffer.writeln('# $className');
    buffer.writeln('');

    // Extract class description from doc comments
    final docMatch = RegExp(r'///\s*(.+)').firstMatch(content);
    if (docMatch != null) {
      buffer.writeln(docMatch.group(1));
      buffer.writeln('');
    }

    // Extract fields
    final fieldMatches = RegExp(r'^\s*(String|int|bool|DateTime|double)\??\s+(\w+);', multiLine: true)
        .allMatches(content);

    if (fieldMatches.isNotEmpty) {
      buffer.writeln('## Fields');
      buffer.writeln('');
      buffer.writeln('| Name | Type |');
      buffer.writeln('|------|------|');
      for (final match in fieldMatches) {
        final type = match.group(1);
        final fieldName = match.group(2);
        buffer.writeln('| `$fieldName` | `$type` |');
      }
      buffer.writeln('');
    }

    // Extract static methods
    final methodMatches = RegExp(r'static\s+Future<[^>]+>\s+(\w+)\([^)]*\)', multiLine: true)
        .allMatches(content);

    if (methodMatches.isNotEmpty) {
      buffer.writeln('## Methods');
      buffer.writeln('');
      for (final match in methodMatches) {
        final methodName = match.group(1);
        buffer.writeln('### `$methodName()`');
        buffer.writeln('');
      }
    }

    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('*Generated from `${p.basename(file.path)}`*');

    return buffer.toString();
  }

  String _toPascalCase(String s) {
    if (s.isEmpty) return s;
    return s.split(RegExp(r'[_-]'))
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join('');
  }
}

/// Create a documentation page
class _DocsPageCommand extends Command<int> {
  @override
  final name = 'page';

  @override
  final description = 'Create a documentation page';

  @override
  String get invocation => 'duxt docs page <name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      print('Error: Please specify a page name');
      print('Usage: duxt docs page <name>');
      return 1;
    }

    final pageName = argResults!.rest[0].toLowerCase().replaceAll(' ', '-');
    final projectDir = Directory.current.path;
    final docsDir = p.join(projectDir, 'docs');

    await Directory(docsDir).create(recursive: true);

    final title = _toTitleCase(pageName);
    final content = '''
# $title

## Overview

Write your documentation here.

## Getting Started

### Prerequisites

- List any requirements

### Installation

```bash
# Installation commands
```

## Usage

Explain how to use this feature.

## Examples

```dart
// Example code
```

## API Reference

Document the API if applicable.

## Troubleshooting

Common issues and solutions.
''';

    final filePath = p.join(docsDir, '$pageName.md');
    await File(filePath).writeAsString(content);

    print('');
    print('\x1B[32m✓\x1B[0m Created docs/$pageName.md');
    print('');

    return 0;
  }

  String _toTitleCase(String s) {
    return s.split('-').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

/// Create a tutorial page
class _DocsTutorialCommand extends Command<int> {
  @override
  final name = 'tutorial';

  @override
  final description = 'Create a tutorial page';

  @override
  String get invocation => 'duxt docs tutorial <name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      print('Error: Please specify a tutorial name');
      print('Usage: duxt docs tutorial <name>');
      return 1;
    }

    final tutorialName = argResults!.rest[0].toLowerCase().replaceAll(' ', '-');
    final projectDir = Directory.current.path;
    final tutorialsDir = p.join(projectDir, 'docs', 'tutorials');

    await Directory(tutorialsDir).create(recursive: true);

    final title = _toTitleCase(tutorialName);
    final content = '''
# $title

Learn how to $title in Duxt.

## Prerequisites

Before starting this tutorial, make sure you have:

- [ ] A Duxt project set up
- [ ] Basic knowledge of Dart
- [ ] Required dependencies installed

## What You'll Build

Describe what the reader will create by the end of this tutorial.

## Step 1: Setup

First, let's set up our project:

```bash
# Create a new project
duxt create my_app
cd my_app
```

## Step 2: Create the Model

Generate the model:

```bash
duxt scaffold items name:string description:text --orm
```

This creates:
- `lib/models/item.dart` - The Item model
- `server/api/items.dart` - API routes
- `lib/items/pages/` - CRUD pages

## Step 3: Implement the Feature

Now let's implement the main feature:

```dart
// Your code here
```

## Step 4: Test It

Run the development server:

```bash
duxt dev
```

Open http://localhost:4100 in your browser.

## Summary

In this tutorial, you learned how to:

- Set up a Duxt project
- Generate models with the scaffold command
- Work with DuxtORM

## Next Steps

- Explore [Relations](/docs/tutorials/relations)
- Learn about [Authentication](/docs/tutorials/auth)
- Deploy your app [Production Guide](/docs/deployment)

## Troubleshooting

### Common Issues

**Issue**: Database not found
**Solution**: Make sure DATA_DIR is set correctly

---

*Estimated time: 15 minutes*
''';

    final filePath = p.join(tutorialsDir, '$tutorialName.md');
    await File(filePath).writeAsString(content);

    print('');
    print('\x1B[32m✓\x1B[0m Created docs/tutorials/$tutorialName.md');
    print('');
    print('Tutorial template created with:');
    print('  - Prerequisites section');
    print('  - Step-by-step instructions');
    print('  - Code examples');
    print('  - Troubleshooting guide');
    print('');

    return 0;
  }

  String _toTitleCase(String s) {
    return s.split('-').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}
