import 'dart:io';
import 'package:path/path.dart' as p;

enum TailwindFailureReason { noInputFile, binaryNotFound, compileFailed }

class TailwindCompileResult {
  final bool ok;
  final TailwindFailureReason? reason;
  final String? stderr;

  const TailwindCompileResult.success()
      : ok = true,
        reason = null,
        stderr = null;

  const TailwindCompileResult.failure(this.reason, {this.stderr}) : ok = false;
}

/// Shared Tailwind helpers used across dev/build commands.
class DuxtTailwind {
  static final RegExp _versionPattern = RegExp(r'v\d+\.\d+\.\d+');

  static String inputPath(String projectDir) =>
      p.join(projectDir, 'web', 'styles.tw.css');

  static String outputPath(String projectDir) =>
      p.join(projectDir, 'web', 'styles.css');

  static bool hasInput(String projectDir) =>
      File(inputPath(projectDir)).existsSync();

  static Future<bool> isAvailable() async => await findExecutable() != null;

  static Future<String?> findExecutable() async {
    if (await _canRun('tailwindcss', runInShell: true)) {
      return 'tailwindcss';
    }

    final home = Platform.environment['HOME'] ?? '';
    final locations = [
      '/usr/local/bin/tailwindcss',
      '$home/.local/bin/tailwindcss',
      '/opt/homebrew/bin/tailwindcss',
      '$home/.npm-global/bin/tailwindcss',
    ];
    for (final location in locations) {
      if (File(location).existsSync() && await _canRun(location)) {
        return location;
      }
    }

    return null;
  }

  static Future<String?> version({String? executable}) async {
    final resolvedExecutable = executable ?? await findExecutable();
    if (resolvedExecutable == null) return null;

    try {
      final result = await Process.run(
        resolvedExecutable,
        ['--help'],
        runInShell: resolvedExecutable == 'tailwindcss',
      );
      final output = '${result.stdout}\n${result.stderr}';
      return _versionPattern.firstMatch(output)?.group(0);
    } on ProcessException {
      return null;
    }
  }

  static Future<TailwindCompileResult> compile(
    String projectDir, {
    bool minify = false,
  }) async {
    if (!hasInput(projectDir)) {
      return const TailwindCompileResult.failure(
          TailwindFailureReason.noInputFile);
    }
    final executable = await findExecutable();
    if (executable == null) {
      return const TailwindCompileResult.failure(
        TailwindFailureReason.binaryNotFound,
      );
    }

    final result = await Process.run(
        executable,
        [
          '--input',
          inputPath(projectDir),
          '--output',
          outputPath(projectDir),
          if (minify) '--minify',
        ],
        workingDirectory: projectDir,
        runInShell: executable == 'tailwindcss');

    if (result.exitCode == 0) {
      return const TailwindCompileResult.success();
    }
    return TailwindCompileResult.failure(
      TailwindFailureReason.compileFailed,
      stderr: result.stderr.toString(),
    );
  }

  /// Start Tailwind in watch mode. Returns the process.
  static Future<Process> watch(String projectDir, {bool verbose = false}) async {
    final executable = await findExecutable() ?? 'tailwindcss';

    final process = await Process.start(
      executable,
      [
        '--input', inputPath(projectDir),
        '--output', outputPath(projectDir),
        '--watch',
      ],
      workingDirectory: projectDir,
      runInShell: executable == 'tailwindcss',
    );
    return process;
  }

  static Future<bool> _canRun(
    String executable, {
    bool runInShell = false,
  }) async {
    try {
      final result = await Process.run(
        executable,
        ['--help'],
        runInShell: runInShell,
      );
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
