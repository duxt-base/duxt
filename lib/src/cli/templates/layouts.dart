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
    return div(classes: 'min-h-screen bg-gray-950 flex flex-col', [
      header(classes: 'sticky top-0 z-50 bg-gray-900/95 backdrop-blur border-b border-gray-800', [
        div(classes: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8', [
          div(classes: 'flex h-16 items-center justify-between', [
            Link(to: '/', child: img(src: 'https://duxt.dev/images/logo.svg', alt: 'Duxt', classes: '!h-7 !w-auto max-h-7')),
            nav(classes: 'flex items-center gap-6', [
              Link(to: '/', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Home')])),
              Link(to: '/docs', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Docs')])),
              Link(to: '/blog', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Blog')])),
              Link(to: '/showcase', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Showcase')])),
              Link(to: '/about', child: span(classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('About')])),
            ]),
          ]),
        ]),
      ]),
      div(classes: 'flex-1', [child]),
      footer(classes: 'bg-gray-900 border-t border-gray-800 py-6', [
        div(classes: 'max-w-7xl mx-auto px-4 text-center', [
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

    return div(classes: 'py-12 px-4', [
      div(classes: 'max-w-3xl mx-auto', [
        h1(classes: 'text-4xl font-bold text-white mb-8', [Component.text(title)]),
        div(classes: 'prose prose-invert prose-lg max-w-none [&_p]:!text-gray-100 [&_h1]:!text-cyan-400 [&_h2]:!text-cyan-400 [&_h3]:!text-cyan-400 [&_h4]:!text-white [&_a]:!text-cyan-400 [&_strong]:!text-white [&_code]:!text-cyan-300 [&_code]:bg-gray-800 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded [&_pre]:bg-gray-800 [&_li]:!text-gray-100', [child]),
      ]),
    ]);
  }
}
''';
