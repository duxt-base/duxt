import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';

/// Command to update Duxt CLI
/// Usage: duxt update
class UpdateCommand extends Command<int> {
  final String currentVersion;

  UpdateCommand(this.currentVersion);

  @override
  final name = 'update';

  @override
  final description = 'Update Duxt CLI to the latest version';

  @override
  Future<int> run() async {
    print('');
    print('\x1B[36mDuxt\x1B[0m Checking for updates...');
    print('');

    try {
      print('  Current version: \x1B[33m$currentVersion\x1B[0m');

      // Get latest version from pub.dev
      final latestVersion = await _fetchLatestVersion();
      print('  Latest version:  \x1B[32m$latestVersion\x1B[0m');
      print('');

      if (currentVersion == latestVersion) {
        print('\x1B[32m✓\x1B[0m Already up to date!');
        print('');
        return 0;
      }

      print('\x1B[90m→\x1B[0m Updating...');

      final result = await Process.run(
        'dart',
        ['pub', 'global', 'activate', 'duxt'],
      );

      if (result.exitCode != 0) {
        print('\x1B[31m✗\x1B[0m Update failed: ${result.stderr}');
        return 1;
      }

      print('');
      print('\x1B[32m✓\x1B[0m Updated to $latestVersion!');
      print('');

      return 0;
    } catch (e) {
      print('\x1B[31m✗\x1B[0m Update failed: $e');
      return 1;
    }
  }
}

/// Check for updates and notify user (non-blocking)
Future<void> checkForUpdates(String currentVersion) async {
  try {
    final latestVersion = await _fetchLatestVersion(
      timeout: const Duration(seconds: 2),
    );

    if (latestVersion != currentVersion &&
        _isNewer(latestVersion, currentVersion)) {
      print('');
      print(
          '\x1B[33m┌─────────────────────────────────────────────────┐\x1B[0m');
      print(
          '\x1B[33m│\x1B[0m  Update available: \x1B[90m$currentVersion\x1B[0m → \x1B[32m$latestVersion\x1B[0m            \x1B[33m│\x1B[0m');
      print(
          '\x1B[33m│\x1B[0m  Run \x1B[1mduxt update\x1B[0m to update                      \x1B[33m│\x1B[0m');
      print(
          '\x1B[33m└─────────────────────────────────────────────────┘\x1B[0m');
      print('');
    }
  } catch (_) {
    // Silently fail - don't block user
  }
}

Future<String> _fetchLatestVersion({
  Duration timeout = const Duration(seconds: 10),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client
        .getUrl(Uri.parse('https://pub.dev/api/packages/duxt'))
        .timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw Exception('pub.dev returned ${response.statusCode}');
    }

    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    final payload = jsonDecode(body);
    if (payload is! Map) {
      throw Exception('Unexpected pub.dev response');
    }

    final latest = payload['latest'];
    if (latest is! Map || latest['version'] is! String) {
      throw Exception('pub.dev response missing latest version');
    }

    return latest['version'] as String;
  } on TimeoutException {
    throw Exception('Timed out while checking pub.dev');
  } finally {
    client.close(force: true);
  }
}

bool _isNewer(String latest, String current) {
  final latestParts = _parseVersion(latest);
  final currentParts = _parseVersion(current);
  final length = latestParts.length > currentParts.length
      ? latestParts.length
      : currentParts.length;

  for (var i = 0; i < length; i++) {
    final latestPart = i < latestParts.length ? latestParts[i] : 0;
    final currentPart = i < currentParts.length ? currentParts[i] : 0;
    if (latestPart > currentPart) return true;
    if (latestPart < currentPart) return false;
  }
  return false;
}

List<int> _parseVersion(String version) {
  final coreVersion = version.split('-').first;
  return coreVersion.split('.').map((part) => int.tryParse(part) ?? 0).toList();
}
