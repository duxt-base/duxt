import 'dart:io';
import 'package:args/command_runner.dart';
import '../core/router_generator.dart';
import '../core/static_generator.dart';

/// Command to generate static site
/// Usage: duxt generate
class GenerateCommand extends Command<int> {
  @override
  final name = 'generate';

  @override
  final description = 'Generate a static site';

  GenerateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'dist',
      help: 'Output directory for static files',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;
    final outputDir = argResults!['output'] as String;

    // Check if this is a fullstack project
    final serverDir = Directory('$projectDir/server');
    if (serverDir.existsSync()) {
      print('');
      print('\x1B[31m✗\x1B[0m Cannot generate static site for fullstack projects.');
      print('');
      print('  Your project has a \x1B[1mserver/\x1B[0m directory with API routes.');
      print('  Static sites cannot run server-side code.');
      print('');
      print('  Options:');
      print('    • \x1B[1mduxt build\x1B[0m   Build fullstack app (frontend + server binary)');
      print('    • \x1B[1mduxt preview\x1B[0m Preview production build locally');
      print('');
      return 1;
    }

    print('\x1B[36mDuxt\x1B[0m Generating static site...');
    print('');

    try {
      // Generate routes
      print('→ Generating routes...');
      await RouterGenerator.generate(projectDir);

      // Generate static files
      print('→ Pre-rendering pages...');
      await StaticGenerator.generate(projectDir, outputDir);

      print('');
      print('\x1B[32m✓\x1B[0m Static site generated! Output: $outputDir/');
      print('');

      return 0;
    } catch (e) {
      print('\x1B[31m✗\x1B[0m Generation failed: $e');
      return 1;
    }
  }
}
