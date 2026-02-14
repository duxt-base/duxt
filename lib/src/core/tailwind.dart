import 'dart:io';
import 'package:path/path.dart' as p;

/// Shared Tailwind CSS compilation utilities
class DuxtTailwind {
  /// Check if tailwindcss binary is available
  static Future<bool> isAvailable() async {
    final which = await Process.run('which', ['tailwindcss']);
    if (which.exitCode == 0) return true;
    final home = Platform.environment['HOME'] ?? '';
    final locations = [
      '/usr/local/bin/tailwindcss',
      '$home/.local/bin/tailwindcss',
    ];
    return locations.any((loc) => File(loc).existsSync());
  }

  /// Compile Tailwind CSS once (for dev startup or build)
  static Future<bool> compile(String projectDir, {bool minify = false}) async {
    final inputFile = File(p.join(projectDir, 'web', 'styles.tw.css'));
    if (!inputFile.existsSync()) return false;
    if (!await isAvailable()) return false;

    final args = [
      '--input', p.join(projectDir, 'web', 'styles.tw.css'),
      '--output', p.join(projectDir, 'web', 'styles.css'),
      if (minify) '--minify',
    ];

    final result = await Process.run('tailwindcss', args, workingDirectory: projectDir);
    return result.exitCode == 0;
  }

  /// Start Tailwind in watch mode. Returns the process.
  static Future<Process> watch(String projectDir, {bool verbose = false}) async {
    final process = await Process.start(
      'tailwindcss',
      [
        '--input', p.join(projectDir, 'web', 'styles.tw.css'),
        '--output', p.join(projectDir, 'web', 'styles.css'),
        '--watch',
      ],
      workingDirectory: projectDir,
    );
    return process;
  }
}
