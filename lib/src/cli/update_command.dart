import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';

/// Command to update Duxt CLI
/// Usage: duxt update
class UpdateCommand extends Command<int> {
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
      // Get current version
      final currentVersion = await _getCurrentVersion();
      print('  Current version: \x1B[33m$currentVersion\x1B[0m');

      // Get latest version from pub.dev
      final latestVersion = await _getLatestVersion();
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

  Future<String> _getCurrentVersion() async {
    // Read from our own pubspec or use hardcoded version
    return '0.3.2'; // This gets updated with each release
  }

  Future<String> _getLatestVersion() async {
    final result = await Process.run(
      'curl',
      ['-s', 'https://pub.dev/api/packages/duxt'],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to check pub.dev');
    }

    final json = jsonDecode(result.stdout as String);
    return json['latest']['version'] as String;
  }
}

/// Check for updates and notify user (non-blocking)
Future<void> checkForUpdates(String currentVersion) async {
  try {
    final result = await Process.run(
      'curl',
      ['-s', '--max-time', '2', 'https://pub.dev/api/packages/duxt'],
    );

    if (result.exitCode != 0) return;

    final json = jsonDecode(result.stdout as String);
    final latestVersion = json['latest']['version'] as String;

    if (latestVersion != currentVersion && _isNewer(latestVersion, currentVersion)) {
      print('');
      print('\x1B[33m┌─────────────────────────────────────────────────┐\x1B[0m');
      print('\x1B[33m│\x1B[0m  Update available: \x1B[90m$currentVersion\x1B[0m → \x1B[32m$latestVersion\x1B[0m            \x1B[33m│\x1B[0m');
      print('\x1B[33m│\x1B[0m  Run \x1B[1mduxt update\x1B[0m to update                      \x1B[33m│\x1B[0m');
      print('\x1B[33m└─────────────────────────────────────────────────┘\x1B[0m');
      print('');
    }
  } catch (_) {
    // Silently fail - don't block user
  }
}

bool _isNewer(String latest, String current) {
  final latestParts = latest.split('.').map(int.parse).toList();
  final currentParts = current.split('.').map(int.parse).toList();

  for (var i = 0; i < 3; i++) {
    if (latestParts[i] > currentParts[i]) return true;
    if (latestParts[i] < currentParts[i]) return false;
  }
  return false;
}
