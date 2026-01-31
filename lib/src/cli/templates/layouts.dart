/// Default app layout template
const defaultLayoutTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'relative', [
      header(classes: 'fixed top-0 left-0 right-0 z-50 bg-transparent', [
        div(classes: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8', [
          div(classes: 'flex h-16 items-center justify-between', [
            Link(to: '/', child: img(src: 'https://duxt.dev/images/logo.svg', alt: 'Duxt', classes: 'h-8')),
            nav(classes: 'flex items-center gap-6', [
              Link(to: '/', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Home')])),
              Link(to: '/docs', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Docs')])),
              Link(to: '/blog', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Blog')])),
              Link(to: '/showcase', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('Showcase')])),
              Link(to: '/about', child: span(classes: 'text-sm text-gray-300 hover:text-white', [Component.text('About')])),
            ]),
          ]),
        ]),
      ]),
      child,
      footer(classes: 'fixed bottom-0 left-0 right-0 z-50 bg-transparent', [
        div(classes: 'max-w-7xl mx-auto px-4 py-4 text-center', [
          DCopyright(text: 'Built with Duxt'),
        ]),
      ]),
    ]);
  }
}
''';

/// Default page layout for content pages
const pageLayoutTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt/content.dart';

class DefaultPageLayout extends PageLayoutBase {
  const DefaultPageLayout();

  @override
  String get name => 'default';

  @override
  Component buildBody(Page page, Component child) {
    final pageData = page.data.page;
    final title = pageData['title'] as String? ?? 'Untitled';

    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-3xl mx-auto', [
        h1(classes: 'text-4xl font-bold text-white mb-8', [Component.text(title)]),
        div(classes: 'prose prose-invert max-w-none', [child]),
      ]),
    ]);
  }
}
''';
