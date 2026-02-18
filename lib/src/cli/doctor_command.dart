import 'dart:io';
import 'package:args/command_runner.dart';

/// Command to show environment and project diagnostics
/// Usage: duxt doctor
class DoctorCommand extends Command<int> {
  @override
  final name = 'doctor';

  @override
  final description = 'Show environment and project diagnostics';

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;

    print('');
    print('\x1B[36m╭─────────────────────────────────────╮\x1B[0m');
    print('\x1B[36m│\x1B[0m  \x1B[1mDuxt\x1B[0m Doctor                       \x1B[36m│\x1B[0m');
    print('\x1B[36m╰─────────────────────────────────────╯\x1B[0m');
    print('');

    // Check Dart
    print('\x1B[1mEnvironment:\x1B[0m');
    final dartVersion = await Process.run('dart', ['--version']);
    if (dartVersion.exitCode == 0) {
      final version = dartVersion.stdout.toString().trim().isEmpty
          ? dartVersion.stderr.toString().trim()
          : dartVersion.stdout.toString().trim();
      print('  \x1B[32m✓\x1B[0m Dart: $version');
    } else {
      print('  \x1B[31m✗\x1B[0m Dart: Not found');
    }

    // Check Jaspr CLI
    final jasprVersion = await Process.run(
      'dart',
      ['pub', 'global', 'run', 'jaspr_cli:jaspr', '--version'],
    );
    if (jasprVersion.exitCode == 0) {
      final version = jasprVersion.stdout.toString().trim();
      print('  \x1B[32m✓\x1B[0m Jaspr CLI: $version');
    } else {
      print('  \x1B[31m✗\x1B[0m Jaspr CLI: Not installed');
      print('    Run: dart pub global activate jaspr_cli');
    }

    // Check Tailwind
    final tailwindCheck = await Process.run('which', ['tailwindcss']);
    if (tailwindCheck.exitCode == 0) {
      final tailwindVersion = await Process.run('tailwindcss', ['--help']);
      final output = tailwindVersion.stderr.toString();
      final versionMatch = RegExp(r'v[\d.]+').firstMatch(output);
      print('  \x1B[32m✓\x1B[0m Tailwind CSS: ${versionMatch?.group(0) ?? "installed"}');
    } else {
      print('  \x1B[33m!\x1B[0m Tailwind CSS: Not found (optional)');
    }

    print('');

    // Check project
    print('\x1B[1mProject:\x1B[0m');

    final pubspec = File('$projectDir/pubspec.yaml');
    if (!pubspec.existsSync()) {
      print('  \x1B[31m✗\x1B[0m Not in a Dart project directory');
      return 1;
    }
    print('  \x1B[32m✓\x1B[0m pubspec.yaml found');

    final duxtConfig = File('$projectDir/duxt.config.dart');
    if (duxtConfig.existsSync()) {
      print('  \x1B[32m✓\x1B[0m duxt.config.dart found');
    } else {
      print('  \x1B[33m!\x1B[0m duxt.config.dart not found (optional)');
    }

    final libDir = Directory('$projectDir/lib');
    if (libDir.existsSync()) {
      print('  \x1B[32m✓\x1B[0m lib/ directory found');
    } else {
      print('  \x1B[31m✗\x1B[0m lib/ directory not found');
    }

    // Check for main files
    final mainServer = File('$projectDir/lib/main.server.dart');
    final mainClient = File('$projectDir/lib/main.client.dart');

    if (mainServer.existsSync()) {
      print('  \x1B[32m✓\x1B[0m main.server.dart found');
    } else {
      print('  \x1B[31m✗\x1B[0m main.server.dart not found');
    }

    if (mainClient.existsSync()) {
      print('  \x1B[32m✓\x1B[0m main.client.dart found');
    } else {
      print('  \x1B[31m✗\x1B[0m main.client.dart not found');
    }

    // Check content directory
    final contentDir = Directory('$projectDir/content');
    if (contentDir.existsSync()) {
      final mdFiles = contentDir
          .listSync(recursive: true)
          .where((f) => f.path.endsWith('.md'))
          .length;
      print('  \x1B[32m✓\x1B[0m content/ directory ($mdFiles markdown files)');
    }

    // Check web directory
    final webDir = Directory('$projectDir/web');
    if (webDir.existsSync()) {
      print('  \x1B[32m✓\x1B[0m web/ directory found');

      final indexHtml = File('$projectDir/web/index.html');
      if (indexHtml.existsSync()) {
        print('  \x1B[32m✓\x1B[0m web/index.html found');
      }

      final stylesTw = File('$projectDir/web/styles.tw.css');
      if (stylesTw.existsSync()) {
        print('  \x1B[32m✓\x1B[0m web/styles.tw.css found (Tailwind input)');
      }
    }

    print('');

    // Run jaspr doctor for additional diagnostics
    print('\x1B[1mJaspr Diagnostics:\x1B[0m');
    final jasprDoctor = await Process.run(
      'dart',
      ['pub', 'global', 'run', 'jaspr_cli:jaspr', 'doctor'],
      workingDirectory: projectDir,
    );

    // Parse and display jaspr doctor output
    final output = jasprDoctor.stdout.toString();
    for (final line in output.split('\n')) {
      if (line.trim().isNotEmpty) {
        print('  $line');
      }
    }

    print('');
    return 0;
  }
}
