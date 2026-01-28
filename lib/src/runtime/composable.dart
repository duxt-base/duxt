/// Base for Duxt composables (like Nuxt/Vue composables)
///
/// Composables are reusable stateful logic that can be shared across components
library;

/// Hook for accessing the current route
class UseRoute {
  final String path;
  final Map<String, String> params;
  final Map<String, String> query;
  final String? hash;

  UseRoute({
    required this.path,
    required this.params,
    required this.query,
    this.hash,
  });
}

/// Hook for navigation
class UseRouter {
  void push(String path) {
    // Will be implemented with Jaspr router
  }

  void replace(String path) {
    // Will be implemented with Jaspr router
  }

  void back() {
    // Will be implemented with Jaspr router
  }

  void forward() {
    // Will be implemented with Jaspr router
  }
}

/// Hook for fetching data (like Nuxt's useFetch)
class UseFetch<T> {
  final Future<T> Function() fetcher;
  final String? key;

  T? data;
  Object? error;
  bool pending = true;
  bool refresh = false;

  UseFetch(this.fetcher, {this.key});

  Future<void> execute() async {
    pending = true;
    error = null;

    try {
      data = await fetcher();
    } catch (e) {
      error = e;
    } finally {
      pending = false;
    }
  }
}

/// Hook for async state (like Nuxt's useAsyncData)
class UseAsyncData<T> {
  final String key;
  final Future<T> Function() handler;

  T? data;
  Object? error;
  bool pending = true;

  UseAsyncData(this.key, this.handler);

  Future<void> execute() async {
    pending = true;
    error = null;

    try {
      data = await handler();
    } catch (e) {
      error = e;
    } finally {
      pending = false;
    }
  }
}

/// Hook for reactive state
class UseState<T> {
  T _value;
  final List<void Function(T)> _listeners = [];

  UseState(this._value);

  T get value => _value;

  set value(T newValue) {
    _value = newValue;
    for (final listener in _listeners) {
      listener(newValue);
    }
  }

  void listen(void Function(T) listener) {
    _listeners.add(listener);
  }
}
