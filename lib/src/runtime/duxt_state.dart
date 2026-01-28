import 'package:jaspr/jaspr.dart';

/// Mixin for StatefulComponent that handles async data loading in SPA mode.
///
/// Usage:
/// ```dart
/// class _PostsState extends State<PostsPage> with DuxtState<List<Post>> {
///   @override
///   Future<List<Post>> load() => PostsApi.getAll();
///
///   @override
///   Component buildLoading() => Spinner();
///
///   @override
///   Component buildData(List<Post> posts) => PostList(posts: posts);
/// }
/// ```
mixin DuxtState<T> on State {
  T? _data;
  Object? _error;
  bool _loading = true;

  /// Override to load data.
  Future<T> load();

  /// Override to build loading state.
  Component buildLoading() => const Text('Loading...');

  /// Override to build error state.
  Component buildError(Object error) => Text('Error: $error');

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
    setState(() {});
  }

  /// Reload the data.
  Future<void> reload() async {
    _loading = true;
    _error = null;
    setState(() {});
    await _loadData();
  }

  @override
  Component build(BuildContext context) {
    if (_loading) return buildLoading();
    if (_error != null) return buildError(_error!);
    return buildData(_data as T);
  }
}

/// Mixin for multiple data sources in SPA mode.
///
/// Usage:
/// ```dart
/// class _DashboardState extends State<DashboardPage> with DuxtMultiState {
///   @override
///   Map<String, Future<dynamic> Function()> get loaders => {
///     'posts': PostsApi.getAll,
///     'users': UsersApi.getAll,
///   };
///
///   @override
///   Component buildData(Map<String, dynamic> data) {
///     final posts = data['posts'] as List<Post>;
///     final users = data['users'] as List<User>;
///     return Dashboard(posts: posts, users: users);
///   }
/// }
/// ```
mixin DuxtMultiState on State {
  final Map<String, dynamic> _data = {};
  Object? _error;
  bool _loading = true;

  /// Override to define data loaders.
  Map<String, Future<dynamic> Function()> get loaders;

  /// Override to build loading state.
  Component buildLoading() => const Text('Loading...');

  /// Override to build error state.
  Component buildError(Object error) => Text('Error: $error');

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
    setState(() {});
  }

  /// Reload all data.
  Future<void> reload() async {
    _loading = true;
    _error = null;
    _data.clear();
    setState(() {});
    await _loadAll();
  }

  /// Reload specific key.
  Future<void> reloadKey(String key) async {
    if (!loaders.containsKey(key)) return;
    try {
      _data[key] = await loaders[key]!();
      setState(() {});
    } catch (e) {
      _error = e;
      setState(() {});
    }
  }

  @override
  Component build(BuildContext context) {
    if (_loading) return buildLoading();
    if (_error != null) return buildError(_error!);
    return buildData(_data);
  }
}
