import 'page.dart';

/// Base class for Duxt middleware
///
/// Similar to Rails's route middleware
abstract class DuxtMiddleware {
  /// Unique name for this middleware
  String get name;

  /// Whether this middleware runs globally on all routes
  bool get global => false;

  /// Called before navigating to a route
  /// Return true to continue, false to abort
  /// Throw RedirectException to redirect
  Future<bool> handle(DuxtContext context, Future<void> Function() next);
}

/// Authentication middleware example
class AuthMiddleware extends DuxtMiddleware {
  @override
  String get name => 'auth';

  @override
  Future<bool> handle(DuxtContext context, Future<void> Function() next) async {
    // Check if user is authenticated
    final isAuthenticated = context.state['isAuthenticated'] ?? false;

    if (!isAuthenticated) {
      context.redirect('/login');
      return false;
    }

    await next();
    return true;
  }
}

/// Guest-only middleware (redirect if authenticated)
class GuestMiddleware extends DuxtMiddleware {
  @override
  String get name => 'guest';

  @override
  Future<bool> handle(DuxtContext context, Future<void> Function() next) async {
    final isAuthenticated = context.state['isAuthenticated'] ?? false;

    if (isAuthenticated) {
      context.redirect('/');
      return false;
    }

    await next();
    return true;
  }
}
