import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;

/// Normalized change type abstraction used by Duxt watchers.
enum DuxtWatchChangeType { add, remove, modify, other }

/// Watches project files for changes and triggers rebuilds.
/// Batches rapid changes and dispatches all pending changes on debounce.
class DuxtWatcher {
  final String projectDir;
  final Future<void> Function(String path, DuxtWatchChangeType changeType)
      onFileChange;

  final List<DirectoryWatcher> _watchers = [];
  final List<StreamSubscription> _subscriptions = [];
  final Map<String, DuxtWatchChangeType> _pendingChanges = {};
  Timer? _debounceTimer;

  DuxtWatcher(this.projectDir, {required this.onFileChange});

  Future<void> start() async {
    // Watch lib/ recursively to catch pages in namespaces (e.g. lib/admin/posts/pages/)
    final libDir = p.join(projectDir, 'lib');
    if (Directory(libDir).existsSync()) {
      final watcher = DirectoryWatcher(libDir);
      _watchers.add(watcher);

      final subscription = watcher.events.listen((event) {
        _queueDebouncedChange(event.path, event.type, allowMarkdown: true);
      });

      _subscriptions.add(subscription);
    }

    // Watch content/ for markdown changes (content-only hot reload)
    final contentDir = p.join(projectDir, 'content');
    if (Directory(contentDir).existsSync()) {
      final watcher = DirectoryWatcher(contentDir);
      _watchers.add(watcher);

      final subscription = watcher.events.listen((event) {
        _queueDebouncedChange(event.path, event.type,
            allowMarkdown: true, allowYaml: true);
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
          _queueDebouncedChange(event.path, event.type, allowMarkdown: false);
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
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingChanges.clear();
  }

  void _queueDebouncedChange(
    String path,
    ChangeType type, {
    required bool allowMarkdown,
    bool allowYaml = false,
  }) {
    final normalized = _normalizePath(path);
    final lower = normalized.toLowerCase();
    final isDart = lower.endsWith('.dart');
    final isMd = lower.endsWith('.md') || lower.endsWith('.mdx');
    final isYaml = lower.endsWith('.yaml') || lower.endsWith('.json');
    final shouldTrack = isDart || (allowMarkdown && isMd) || (allowYaml && isYaml);
    if (!shouldTrack) return;

    final incoming = _mapChangeType(type);
    _pendingChanges.update(
      normalized,
      (existing) => _mergeChangeType(existing, incoming),
      ifAbsent: () => incoming,
    );

    // Short debounce so save->build starts sooner while still coalescing bursts.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      final batch = Map<String, DuxtWatchChangeType>.from(_pendingChanges);
      _pendingChanges.clear();
      for (final entry in batch.entries) {
        unawaited(onFileChange(entry.key, entry.value));
      }
    });
  }

  DuxtWatchChangeType _mergeChangeType(
    DuxtWatchChangeType existing,
    DuxtWatchChangeType incoming,
  ) {
    // Structural changes should win over modify/other in a burst window.
    if (incoming == DuxtWatchChangeType.add ||
        incoming == DuxtWatchChangeType.remove) {
      return incoming;
    }
    if (existing == DuxtWatchChangeType.add ||
        existing == DuxtWatchChangeType.remove) {
      return existing;
    }
    if (incoming == DuxtWatchChangeType.modify) return incoming;
    return existing;
  }

  String _normalizePath(String filePath) =>
      p.normalize(filePath).replaceAll('\\', '/');

  DuxtWatchChangeType _mapChangeType(ChangeType type) {
    if (type == ChangeType.ADD) return DuxtWatchChangeType.add;
    if (type == ChangeType.REMOVE) return DuxtWatchChangeType.remove;
    if (type == ChangeType.MODIFY) return DuxtWatchChangeType.modify;
    return DuxtWatchChangeType.other;
  }
}
