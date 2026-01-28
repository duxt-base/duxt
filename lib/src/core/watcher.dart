import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;

/// Watches project files for changes and triggers rebuilds
class DuxtWatcher {
  final String projectDir;
  final Future<void> Function(String path) onFileChange;

  final List<DirectoryWatcher> _watchers = [];
  final List<StreamSubscription> _subscriptions = [];

  DuxtWatcher(this.projectDir, {required this.onFileChange});

  Future<void> start() async {
    // Watch directories that trigger rebuilds
    final watchDirs = ['pages', 'layouts', 'components', 'middleware', 'composables'];

    for (final dir in watchDirs) {
      final fullPath = p.join(projectDir, dir);
      if (Directory(fullPath).existsSync()) {
        final watcher = DirectoryWatcher(fullPath);
        _watchers.add(watcher);

        final subscription = watcher.events.listen((event) {
          if (event.path.endsWith('.dart')) {
            _debounce(() => onFileChange(event.path));
          }
        });

        _subscriptions.add(subscription);
      }
    }
  }

  Future<void> stop() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _watchers.clear();
  }

  // Debounce to avoid multiple rapid rebuilds
  Timer? _debounceTimer;
  void _debounce(void Function() action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), action);
  }
}
