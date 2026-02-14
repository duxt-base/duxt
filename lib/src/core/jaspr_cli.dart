import 'dart:io';
import 'package:path/path.dart' as p;

/// Shared resolver for jaspr CLI executable location.
class JasprCli {
  static String globalPath() {
    final env = Platform.environment;

    final pubCache = env['PUB_CACHE'];
    if (pubCache != null && pubCache.isNotEmpty) {
      return p.join(pubCache, 'bin', _executableName());
    }

    if (Platform.isWindows) {
      final localAppData = env['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return p.join(localAppData, 'Pub', 'Cache', 'bin', _executableName());
      }

      final userProfile = env['USERPROFILE'] ?? '';
      if (userProfile.isNotEmpty) {
        return p.join(
          userProfile,
          'AppData',
          'Local',
          'Pub',
          'Cache',
          'bin',
          _executableName(),
        );
      }
    }

    final home = env['HOME'] ?? '';
    return p.join(home, '.pub-cache', 'bin', _executableName());
  }

  static String resolveCommand() {
    final path = globalPath();
    if (File(path).existsSync()) {
      return path;
    }
    return 'jaspr';
  }

  /// Resolve the installed jaspr_cli snapshot path when available.
  ///
  /// Using the snapshot directly avoids the shell wrapper script in
  /// ~/.pub-cache/bin/jaspr and makes process lifecycle management more reliable.
  static String? globalSnapshotPath() {
    final wrapper = File(globalPath());

    if (wrapper.existsSync()) {
      try {
        final content = wrapper.readAsStringSync();
        final match = RegExp(r'dart "([^"]*jaspr\.dart-[^"]+\.snapshot)"')
            .firstMatch(content);
        final scriptedPath = match?.group(1);
        if (scriptedPath != null && File(scriptedPath).existsSync()) {
          return scriptedPath;
        }
      } catch (_) {
        // Fall back to directory scan below.
      }
    }

    final pubCacheBin = p.dirname(globalPath());
    final snapshotDir = Directory(
      p.join(p.dirname(pubCacheBin), 'global_packages', 'jaspr_cli', 'bin'),
    );
    if (!snapshotDir.existsSync()) return null;

    final snapshots = snapshotDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('jaspr.dart-'))
        .where((f) => p.basename(f.path).endsWith('.snapshot'))
        .toList(growable: false)
      ..sort((a, b) => b.path.compareTo(a.path));

    if (snapshots.isEmpty) return null;
    return snapshots.first.path;
  }

  static bool shouldRunInShell(String command) {
    if (!Platform.isWindows) return false;
    final lower = command.toLowerCase();
    return lower == 'jaspr' || lower.endsWith('.bat') || lower.endsWith('.cmd');
  }

  static String _executableName() => Platform.isWindows ? 'jaspr.bat' : 'jaspr';
}
