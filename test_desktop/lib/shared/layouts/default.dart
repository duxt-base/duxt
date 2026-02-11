import 'package:jaspr/jaspr.dart' hide Text;
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_html/duxt_html.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return Div(
      className: 'min-h-screen bg-gray-950 flex flex-col',
      children: [
        Header(
          className: 'sticky top-0 z-50 bg-gray-900/95 backdrop-blur border-b border-gray-800',
          child: Div(
            className: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8',
            child: Div(
              className: 'flex h-16 items-center justify-between',
              children: [
                Link(
                  to: '/',
                  child: Span(
                    className: 'text-xl font-bold text-white',
                    child: Text('test_desktop'),
                  ),
                ),
                Nav(
                  className: 'flex items-center gap-6',
                  children: [
                    Link(
                      to: '/',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('Home'),
                      ),
                    ),
                    Link(
                      to: '/demo',
                      child: Span(
                        className: 'text-sm text-gray-300 hover:text-white transition-colors',
                        child: Text('Demo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Div(className: 'flex-1', child: child),
        Footer(
          className: 'bg-gray-900 border-t border-gray-800 py-8',
          child: Div(
            className: 'max-w-7xl mx-auto px-4 text-center text-gray-400 text-sm',
            child: Text('Built with Duxt'),
          ),
        ),
      ],
    );
  }
}
