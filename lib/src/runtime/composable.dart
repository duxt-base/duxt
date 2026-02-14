/// Duxt composables - utilities for working with Jaspr router and state
///
/// These are thin wrappers around Jaspr router APIs for convenience.
library;

import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

/// Get the router state from context.
///
/// Usage:
/// ```dart
/// final router = useRouter(context);
/// router.push('/posts');
/// ```
RouterState useRouter(BuildContext context) => Router.of(context);

/// Get route state from the builder callback.
///
/// This is just a type alias reminder - RouteState comes from the route builder.
/// Usage in route builder:
/// ```dart
/// Route(
///   path: '/posts/:id',
///   builder: (context, state) {
///     final id = state.params['id'];
///     final filter = state.queryParams['filter'];
///     return PostPage(id: id!);
///   },
/// )
/// ```
typedef RouteStateCallback = Component Function(BuildContext context, RouteState state);

/// Extension on BuildContext for convenient navigation.
///
/// Usage:
/// ```dart
/// // Navigate to a path
/// context.push('/posts');
///
/// // Navigate with extra data
/// context.push('/posts/1', extra: {'from': 'list'});
///
/// // Replace current route
/// context.replace('/login');
///
/// // Go back
/// context.back();
///
/// // Navigate by route name
/// context.pushNamed('post-detail', params: {'id': '123'});
/// ```
extension DuxtNavigation on BuildContext {
  /// Navigate to a path, adding to browser history.
  void push(String path, {Object? extra}) => Router.of(this).push(path, extra: extra);

  /// Navigate without adding to browser history.
  void replace(String path) => Router.of(this).replace(path);

  /// Go back in browser history.
  void back() => Router.of(this).back();

  /// Navigate using a named route.
  void pushNamed(String name, {Map<String, String>? params}) =>
      Router.of(this).pushNamed(name, params: params ?? {});

  /// Replace using a named route.
  void replaceNamed(String name, {Map<String, String>? params}) =>
      Router.of(this).replaceNamed(name, params: params ?? {});

  /// Preload a route for faster navigation.
  void preload(String path) => Router.of(this).preload(path);

  /// Get the location for a named route.
  String namedLocation(String name) => Router.of(this).namedLocation(name);
}

/// Async data result holder.
///
/// Usage with DuxtState is preferred, but this can be used standalone
/// by creating an instance and calling [setLoading], [setData], or
/// [setError] to update state.
class AsyncData<T> {
  T? _data;
  Object? _error;
  bool _loading = false;

  /// Current data value.
  T? get data => _data;

  /// Current error if any.
  Object? get error => _error;

  /// Whether currently loading.
  bool get loading => _loading;

  /// Whether data has loaded successfully.
  bool get hasData => _data != null && _error == null;

  /// Whether an error occurred.
  bool get hasError => _error != null;

  /// Set loading state.
  void setLoading() {
    _loading = true;
    _error = null;
  }

  /// Set data and clear loading/error.
  void setData(T value) {
    _data = value;
    _error = null;
    _loading = false;
  }

  /// Set error and clear loading.
  void setError(Object e) {
    _error = e;
    _loading = false;
  }

  /// Reset to initial state.
  void reset() {
    _data = null;
    _error = null;
    _loading = false;
  }
}

/// Helper to extract route params in component constructors.
///
/// Usage:
/// ```dart
/// class PostPage extends StatelessComponent {
///   final String id;
///   const PostPage({required this.id, super.key});
/// }
///
/// // In route builder:
/// Route(
///   path: '/posts/:id',
///   builder: (context, state) => PostPage(id: state.params['id']!),
/// )
/// ```
String requireParam(RouteState state, String name) {
  final value = state.params[name];
  if (value == null) {
    throw ArgumentError('Missing required route param: $name');
  }
  return value;
}

/// Helper to get optional route param with default.
String paramOr(RouteState state, String name, String defaultValue) {
  return state.params[name] ?? defaultValue;
}

/// Helper to get query param.
String? queryParam(RouteState state, String name) {
  return state.queryParams[name];
}

/// Helper to get query param with default.
String queryParamOr(RouteState state, String name, String defaultValue) {
  return state.queryParams[name] ?? defaultValue;
}
