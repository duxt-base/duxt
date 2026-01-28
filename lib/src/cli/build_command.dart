import 'dart:io';
import 'package:args/command_runner.dart';
import '../core/router_generator.dart';
import '../core/builder.dart';

/// Command to build for production
/// Usage: duxt build
class BuildCommand extends Command<int> {
  @override
  final name = 'build';

  @override
  final description = 'Build the project for production';

  BuildCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      defaultsTo: '.output',
      help: 'Output directory',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = Directory.current.path;
    final outputDir = argResults!['output'] as String;

    print('\x1B[36mDuxt\x1B[0m Building for production...');
    print('');

    try {
      // Generate routes
      print('→ Generating routes...');
      await RouterGenerator.generate(projectDir);

      // Run Jaspr build
      print('→ Building Jaspr app...');
      await DuxtBuilder.build(projectDir, outputDir);

      print('');
      print('\x1B[32m✓\x1B[0m Build complete! Output: $outputDir/');
      print('');

      return 0;
    } catch (e) {
      print('\x1B[31m✗\x1B[0m Build failed: $e');
      return 1;
    }
  }
}
