import 'dart:async';
import 'package:build_daemon/client.dart';
import 'package:build_daemon/data/build_status.dart';
import 'package:build_daemon/data/build_target.dart';
import 'package:build_daemon/data/server_log.dart';

/// Connects to a running build daemon to receive build events directly,
/// replacing fragile stdout parsing with a proper event stream.
class BuildEventClient {
  BuildDaemonClient? _client;
  StreamSubscription? _buildSub;
  StreamSubscription? _shutdownSub;

  /// Callback for build status changes.
  final void Function(BuildEventType type, {String? error}) onBuildEvent;

  /// Optional log handler for daemon logs.
  final void Function(String message, {bool isError})? onLog;

  BuildEventClient({required this.onBuildEvent, this.onLog});

  /// Connect to the build daemon for the given project directory.
  /// Returns true if connected successfully, false if no daemon is running.
  Future<bool> connect(String projectDir) async {
    try {
      _client = await BuildDaemonClient.connectUnchecked(
        projectDir,
        logHandler: (ServerLog log) {
          if (log.level.compareTo(Level.WARNING) >= 0) {
            onLog?.call(log.message, isError: log.error != null);
          }
        },
      );

      // Register for web build target events
      _client!.registerBuildTarget(
        DefaultBuildTarget((b) => b..target = 'web'),
      );

      _buildSub = _client!.buildResults.listen((results) {
        for (final result in results.results) {
          switch (result.status) {
            case BuildStatus.started:
              onBuildEvent(BuildEventType.started);
            case BuildStatus.succeeded:
              onBuildEvent(BuildEventType.succeeded);
            case BuildStatus.failed:
              onBuildEvent(BuildEventType.failed, error: result.error);
          }
        }
      });

      _shutdownSub = _client!.shutdownNotifications.listen((notification) {
        onLog?.call('Build daemon shutdown: ${notification.message}',
            isError: notification.failureType != 0);
      });

      return true;
    } on MissingPortFile {
      return false;
    } catch (e) {
      onLog?.call('Could not connect to build daemon: $e', isError: false);
      return false;
    }
  }

  /// Close the connection.
  Future<void> close() async {
    await _buildSub?.cancel();
    await _shutdownSub?.cancel();
    await _client?.close();
    _client = null;
  }
}

/// Build event types from the daemon.
enum BuildEventType { started, succeeded, failed }
