import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';

/// A polished error page component for Duxt applications.
///
/// Uses Tailwind CSS classes (included in all Duxt projects) to render
/// a styled error page with status code, message, and a "Go Home" link.
class DuxtErrorPage extends StatelessComponent {
  final int statusCode;
  final String? path;
  final String? message;

  const DuxtErrorPage({
    super.key,
    this.statusCode = 404,
    this.path,
    this.message,
  });

  /// Static method matching [RouterComponentBuilder] signature for direct use
  /// as `Router(errorBuilder: DuxtErrorPage.routerErrorBuilder)`.
  static Component routerErrorBuilder(BuildContext context, RouteState state) {
    return DuxtErrorPage(
      statusCode: 404,
      path: state.location,
    );
  }

  @override
  Component build(BuildContext context) {
    final is500 = statusCode >= 500;

    final title = is500 ? 'Internal Server Error' : 'Page Not Found';
    final description = message ??
        (is500
            ? 'Something went wrong on our end. Please try again later.'
            : 'The page you are looking for does not exist or has been moved.');

    // Use full literal class strings so Tailwind JIT can discover them.
    final statusCodeClasses = is500
        ? 'text-8xl font-extrabold text-red-400 mb-4'
        : 'text-8xl font-extrabold text-cyan-400 mb-4';
    final buttonClasses = is500
        ? 'inline-block px-8 py-3 bg-red-600 text-white rounded-lg font-medium text-sm hover:bg-red-700 transition-colors'
        : 'inline-block px-8 py-3 bg-cyan-600 text-white rounded-lg font-medium text-sm hover:bg-cyan-700 transition-colors';

    // Truncate path to prevent abuse with very long URLs
    final displayPath = path != null && path!.length > 500
        ? '${path!.substring(0, 500)}...'
        : path;

    return div(
      classes: 'min-h-screen bg-gray-950 flex items-center justify-center',
      [
        div(classes: 'text-center px-4 max-w-lg', [
          // Large status code
          div(
            classes: statusCodeClasses,
            [Component.text('$statusCode')],
          ),
          // Title
          h1(
            classes: 'text-2xl font-semibold text-white mb-3',
            [Component.text(title)],
          ),
          // Description
          p(
            classes: 'text-gray-400 text-base leading-relaxed',
            [Component.text(description)],
          ),
          // Path display (only for 404)
          if (!is500 && displayPath != null)
            div(
              classes:
                  'mt-6 px-4 py-3 bg-white/[0.03] border border-white/[0.06] rounded-lg',
              [
                span(
                  classes: 'font-mono text-sm text-gray-500 break-all',
                  [Component.text(displayPath)],
                ),
              ],
            ),
          // Go Home button
          div(classes: 'mt-8', [
            Link(
              to: '/',
              child: span(
                classes: buttonClasses,
                [Component.text('Go Home')],
              ),
            ),
          ]),
        ]),
      ],
    );
  }
}
