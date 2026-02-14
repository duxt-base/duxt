import 'package:jaspr/jaspr.dart';

/// Base class for StatefulComponent states that handle async data loading in SPA mode.
///
/// Extend this class in your page's State, providing the component type
/// and data type as type parameters. Override [load], [buildLoading],
/// [buildError], and [buildData].
abstract class DuxtState<S extends StatefulComponent, T> extends State<S> {
  T? _data;
  Object? _error;
  bool _loading = true;

  /// Override to load data.
  Future<T> load();

  /// Override to build loading state.
  Component buildLoading();

  /// Override to build error state.
  Component buildError(Object error);

  /// Override to build data state.
  Component buildData(T data);

  /// Current data (null if loading or error).
  T? get data => _data;

  /// Current error (null if loading or success).
  Object? get error => _error;

  /// Whether currently loading.
  bool get loading => _loading;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _data = await load();
      _error = null;
    } catch (e) {
      _error = e;
      _data = null;
    }
    _loading = false;
    // setState may fail on server (SSR) - that's expected
    try {
      setState(() {});
    } catch (_) {
      // On server, setState throws - ignore and let client hydrate
    }
  }

  /// Reload the data.
  Future<void> reload() async {
    _loading = true;
    _error = null;
    try {
      setState(() {});
    } catch (_) {}
    await _loadData();
  }

  @override
  Component build(BuildContext context) {
    if (_loading) return buildLoading();
    if (_error != null) return buildError(_error!);
    return buildData(_data as T);
  }
}

/// Base class for multiple data sources in SPA mode.
///
/// Extend this class and override [loaders] to provide named async
/// data sources. Override [buildLoading], [buildError], and [buildData]
/// to handle each state.
abstract class DuxtMultiState<S extends StatefulComponent> extends State<S> {
  final Map<String, dynamic> _data = {};
  Object? _error;
  bool _loading = true;

  /// Override to define data loaders.
  Map<String, Future<dynamic> Function()> get loaders;

  /// Override to build loading state.
  Component buildLoading();

  /// Override to build error state.
  Component buildError(Object error);

  /// Override to build data state.
  Component buildData(Map<String, dynamic> data);

  /// Get typed data by key.
  T? getData<T>(String key) => _data[key] as T?;

  /// Whether currently loading.
  bool get loading => _loading;

  /// Current error.
  Object? get error => _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      await Future.wait(
        loaders.entries.map((e) async {
          _data[e.key] = await e.value();
        }),
      );
      _error = null;
    } catch (e) {
      _error = e;
    }
    _loading = false;
    // setState may fail on server (SSR) - that's expected
    try {
      setState(() {});
    } catch (_) {}
  }

  /// Reload all data.
  Future<void> reload() async {
    _loading = true;
    _error = null;
    _data.clear();
    try {
      setState(() {});
    } catch (_) {}
    await _loadAll();
  }

  /// Reload specific key.
  Future<void> reloadKey(String key) async {
    if (!loaders.containsKey(key)) return;
    try {
      _data[key] = await loaders[key]!();
      try {
        setState(() {});
      } catch (_) {}
    } catch (e) {
      _error = e;
      try {
        setState(() {});
      } catch (_) {}
    }
  }

  @override
  Component build(BuildContext context) {
    if (_loading) return buildLoading();
    if (_error != null) return buildError(_error!);
    return buildData(_data);
  }
}
