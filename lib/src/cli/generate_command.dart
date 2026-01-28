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
