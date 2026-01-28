/// Base class for Duxt pages
///
/// Similar to Nuxt's definePageMeta and page components
abstract class DuxtPage {
  /// The layout to use for this page
  /// Defaults to 'default' if not overridden
  String? get layout => null;

  /// Middleware to run before rendering this page
  List<String> get middleware => [];

  /// Page title for SEO
  String? get title => null;

  /// Page meta tags
  Map<String, String> get meta => {};

  /// Whether this page requires authentication
  bool get requiresAuth => false;
}

/// Mixin for pages that need async data loading
mixin AsyncDataMixin {
  /// Called on server-side to fetch data before rendering
  /// Similar to Nuxt's asyncData/useFetch
  Future<void> asyncData(DuxtContext context) async {}
}

/// Context passed to asyncData and middleware
class DuxtContext {
  final String path;
  final Map<String, String> params;
  final Map<String, String> query;
  final Map<String, dynamic> state;

  DuxtContext({
    required this.path,
    required this.params,
    required this.query,
    Map<String, dynamic>? state,
  }) : state = state ?? {};

  /// Redirect to another route
  void redirect(String path) {
    throw RedirectException(path);
  }

  /// Return an error
  void error(int statusCode, String message) {
    throw ErrorException(statusCode, message);
  }
}

class RedirectException implements Exception {
  final String path;
  RedirectException(this.path);
}

class ErrorException implements Exception {
  final int statusCode;
  final String message;
  ErrorException(this.statusCode, this.message);
}
