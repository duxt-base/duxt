import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;

/// Watches project files for changes and triggers rebuilds.
/// Passes [ChangeType] so callers can distinguish add/remove from modify.
class DuxtWatcher {
  final String projectDir;
  final Future<void> Function(String path, ChangeType changeType) onFileChange;

  final List<DirectoryWatcher> _watchers = [];
  final List<StreamSubscription> _subscriptions = [];

  DuxtWatcher(this.projectDir, {required this.onFileChange});

  Future<void> start() async {
    // Watch lib/ recursively to catch pages in namespaces (e.g. lib/admin/posts/pages/)
    final libDir = p.join(projectDir, 'lib');
    if (Directory(libDir).existsSync()) {
      final watcher = DirectoryWatcher(libDir);
      _watchers.add(watcher);

      final subscription = watcher.events.listen((event) {
        if (event.path.endsWith('.dart') || event.path.endsWith('.md') || event.path.endsWith('.mdx')) {
          _debounce(() => onFileChange(event.path, event.type));
        }
      });

      _subscriptions.add(subscription);
    }

    // Watch content/ for markdown changes (content-only hot reload)
    final contentDir = p.join(projectDir, 'content');
    if (Directory(contentDir).existsSync()) {
      final watcher = DirectoryWatcher(contentDir);
      _watchers.add(watcher);

      final subscription = watcher.events.listen((event) {
        if (event.path.endsWith('.md') || event.path.endsWith('.mdx') ||
            event.path.endsWith('.yaml') || event.path.endsWith('.json')) {
          _debounce(() => onFileChange(event.path, event.type));
        }
      });

      _subscriptions.add(subscription);
    }

    // Also watch top-level directories that may exist outside lib/
    final extraDirs = ['server', 'middleware', 'composables'];
    for (final dir in extraDirs) {
      final fullPath = p.join(projectDir, dir);
      if (Directory(fullPath).existsSync()) {
        final watcher = DirectoryWatcher(fullPath);
        _watchers.add(watcher);

        final subscription = watcher.events.listen((event) {
          if (event.path.endsWith('.dart')) {
            _debounce(() => onFileChange(event.path, event.type));
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
