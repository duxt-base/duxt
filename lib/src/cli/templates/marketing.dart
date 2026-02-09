import 'dart:io';
import 'package:path/path.dart' as p;

import 'pubspec.dart';
import 'app.dart';
import 'web.dart';

/// Marketing template - landing page with hero, features, pricing
class MarketingTemplate {
  static Future<void> generate(String projectName, String targetDir, {String mode = 'static'}) async {
    await _createDirectories(targetDir);
    await _writeFiles(projectName, targetDir, mode: mode);
    _printSuccess(projectName);
  }

  static Future<void> _createDirectories(String targetDir) async {
    final dirs = [
      'lib',
      'lib/.generated',
      'lib/home/pages',
      'lib/home/components',
      'lib/shared/layouts',
      'web',
    ];

    for (final dir in dirs) {
      await Directory(p.join(targetDir, dir)).create(recursive: true);
    }
  }

  static Future<void> _writeFiles(String projectName, String dir, {required String mode}) async {
    // Config files
    await _write(dir, 'pubspec.yaml', _marketingPubspec(projectName, mode: mode));
    await _write(dir, 'build.yaml', buildYamlTemplate);
    await _write(dir, '.gitignore', gitignoreTemplate);

    // App files
    await _write(dir, 'lib/app.dart', _marketingAppTemplate);
    await _write(dir, 'lib/main.client.dart', mainClientTemplate);
    if (mode == 'server') {
      // Server mode includes ORM initialization
      await _write(dir, 'lib/main.server.dart', serverModeMainServerTemplate(projectName));
    } else if (mode == 'static') {
      await _write(dir, 'lib/main.server.dart', mainServerTemplate(projectName));
    }

    // Layouts
    await _write(dir, 'lib/shared/layouts/default.dart', _marketingLayoutTemplate);

    // Home module - landing page
    await _write(dir, 'lib/home/pages/index.dart', _marketingHomeTemplate(projectName));

    // Components
    await _write(dir, 'lib/home/components/hero.dart', _heroComponent(projectName));
    await _write(dir, 'lib/home/components/features.dart', _featuresComponent);
    await _write(dir, 'lib/home/components/pricing.dart', _pricingComponent);
    await _write(dir, 'lib/home/components/testimonials.dart', _testimonialsComponent);
    await _write(dir, 'lib/home/components/cta.dart', _ctaComponent);
    await _write(dir, 'lib/home/components/faq.dart', _faqComponent);

    // Web
    await _write(dir, 'web/styles.tw.css', tailwindTemplate);
    await _write(dir, 'web/main.client.dart', webMainClientTemplate(projectName));
  }

  static Future<void> _write(String dir, String path, String content) async {
    await File(p.join(dir, path)).writeAsString(content);
  }

  static void _printSuccess(String projectName) {
    print('');
    print('  \x1B[32m✓\x1B[0m Created marketing landing page');
    print('');
    print('  lib/');
    print('    ├── home/');
    print('    │   ├── pages/index.dart       → /');
    print('    │   └── components/');
    print('    │       ├── hero.dart');
    print('    │       ├── features.dart');
    print('    │       ├── pricing.dart');
    print('    │       ├── testimonials.dart');
    print('    │       ├── cta.dart');
    print('    │       └── faq.dart');
    print('    ├── shared/layouts/');
    print('    └── app.dart');
    print('');
    print('  \x1B[36mDevelopment:\x1B[0m');
    print('    duxt dev                       Start dev server');
    print('');
    print('  \x1B[36mCustomize:\x1B[0m');
    print('    Edit components in lib/home/components/');
    print('');
  }
}

/// Marketing pubspec - includes duxt_orm for server mode
String _marketingPubspec(String projectName, {String mode = 'static'}) {
  final serverDeps = mode == 'server' ? '''
  duxt_orm:
  sqlite3:
''' : '';

  return '''
name: $projectName
description: A Duxt marketing site
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  jaspr:
  jaspr_router:
  duxt:
  duxt_ui:
$serverDeps
dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: $mode
''';
}

const _marketingAppTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt/duxt.dart';

import '.generated/routes.dart' as generated;
import 'shared/layouts/default.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    final routes = generated.generatedRoutes;

    final wrappedRoutes = routes.map((route) => Route(
      path: route.path,
      builder: (context, state) => DefaultLayout(
        child: Builder(builder: (ctx) => route.builder!(ctx, state)),
      ),
    )).toList();

    return Router(
      routes: wrappedRoutes,
      errorBuilder: DuxtErrorPage.routerErrorBuilder,
    );
  }
}
''';

const _marketingLayoutTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';

class DefaultLayout extends StatelessComponent {
  final Component child;

  const DefaultLayout({super.key, required this.child});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gray-950', [
      // Navigation
      header(classes: 'fixed top-0 left-0 right-0 z-50 bg-gray-950/80 backdrop-blur-lg border-b border-gray-800', [
        div(classes: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8', [
          div(classes: 'flex h-16 items-center justify-between', [
            Link(to: '/', child: span(classes: 'text-xl font-bold text-white', [Component.text('Logo')])),
            nav(classes: 'hidden md:flex items-center gap-8', [
              a(href: '#features', classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Features')]),
              a(href: '#pricing', classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Pricing')]),
              a(href: '#testimonials', classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('Testimonials')]),
              a(href: '#faq', classes: 'text-sm text-gray-300 hover:text-white transition-colors', [Component.text('FAQ')]),
            ]),
            a(
              href: '#cta',
              classes: 'px-4 py-2 bg-cyan-600 text-white text-sm rounded-lg hover:bg-cyan-700 transition-colors',
              [Component.text('Get Started')],
            ),
          ]),
        ]),
      ]),
      // Main content
      main_([child]),
      // Footer
      footer(classes: 'bg-gray-900 border-t border-gray-800 py-12', [
        div(classes: 'max-w-7xl mx-auto px-4 text-center', [
          p(classes: 'text-gray-400 text-sm', [
            Component.text('Built with Duxt - The meta-framework for Jaspr'),
          ]),
        ]),
      ]),
    ]);
  }
}
''';

String _marketingHomeTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

import '../components/hero.dart';
import '../components/features.dart';
import '../components/pricing.dart';
import '../components/testimonials.dart';
import '../components/cta.dart';
import '../components/faq.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div([
      const Hero(),
      const Features(),
      const Pricing(),
      const Testimonials(),
      const FAQ(),
      const CTA(),
    ]);
  }
}
''';

String _heroComponent(String projectName) => r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class Hero extends StatelessComponent {
  const Hero({super.key});

  @override
  Component build(BuildContext context) {
    return section(classes: 'pt-32 pb-20 px-4', [
      div(classes: 'max-w-5xl mx-auto text-center', [
        // Badge
        div(classes: 'inline-flex items-center gap-2 px-4 py-2 bg-cyan-900/30 rounded-full mb-8', [
          span(classes: 'text-cyan-400 text-sm font-medium', [Component.text('New')]),
          span(classes: 'text-gray-300 text-sm', [Component.text('Version 2.0 is here')]),
        ]),
        // Heading
        h1(classes: 'text-5xl md:text-7xl font-bold text-white mb-6 leading-tight', [
          Component.text('Build something '),
          span(classes: 'text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500', [
            Component.text('amazing'),
          ]),
        ]),
        // Subheading
        p(classes: 'text-xl text-gray-400 mb-10 max-w-2xl mx-auto', [
          Component.text('The modern platform for building exceptional products. Start free and scale as you grow.'),
        ]),
        // CTA buttons
        div(classes: 'flex flex-col sm:flex-row justify-center gap-4', [
          a(
            href: '#cta',
            classes: 'px-8 py-4 bg-cyan-600 text-white font-medium rounded-lg hover:bg-cyan-700 transition-colors',
            [Component.text('Start for Free')],
          ),
          a(
            href: '#features',
            classes: 'px-8 py-4 border border-gray-700 text-white font-medium rounded-lg hover:bg-gray-800 transition-colors',
            [Component.text('Learn More')],
          ),
        ]),
      ]),
    ]);
  }
}
''';

const _featuresComponent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class Features extends StatelessComponent {
  const Features({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'features', classes: 'py-20 px-4 bg-gray-900/50', [
      div(classes: 'max-w-7xl mx-auto', [
        // Header
        div(classes: 'text-center mb-16', [
          h2(classes: 'text-4xl font-bold text-white mb-4', [
            Component.text('Everything you need'),
          ]),
          p(classes: 'text-xl text-gray-400', [
            Component.text('Powerful features to help you build faster'),
          ]),
        ]),
        // Features grid
        div(classes: 'grid md:grid-cols-3 gap-8', [
          _featureCard(
            icon: 'M13 10V3L4 14h7v7l9-11h-7z',
            title: 'Lightning Fast',
            description: 'Optimized for speed with instant page loads and smooth interactions.',
          ),
          _featureCard(
            icon: 'M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z',
            title: 'Secure by Default',
            description: 'Built-in security features to protect your data and users.',
          ),
          _featureCard(
            icon: 'M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z',
            title: 'Flexible & Scalable',
            description: 'Grows with your business from startup to enterprise.',
          ),
        ]),
      ]),
    ]);
  }

  static Component _featureCard({
    required String icon,
    required String title,
    required String description,
  }) {
    return div(classes: 'p-8 bg-gray-800/50 rounded-2xl border border-gray-700', [
      div(classes: 'w-12 h-12 bg-cyan-900/30 rounded-lg flex items-center justify-center mb-6', [
        Component.element(
          tag: 'svg',
          attributes: {
            'class': 'w-6 h-6 text-cyan-400',
            'fill': 'none',
            'stroke': 'currentColor',
            'viewBox': '0 0 24 24',
          },
          children: [
            Component.element(
              tag: 'path',
              attributes: {
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
                'stroke-width': '2',
                'd': icon,
              },
            ),
          ],
        ),
      ]),
      h3(classes: 'text-xl font-semibold text-white mb-3', [Component.text(title)]),
      p(classes: 'text-gray-400', [Component.text(description)]),
    ]);
  }
}
''';

const _pricingComponent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class Pricing extends StatelessComponent {
  const Pricing({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'pricing', classes: 'py-20 px-4', [
      div(classes: 'max-w-7xl mx-auto', [
        // Header
        div(classes: 'text-center mb-16', [
          h2(classes: 'text-4xl font-bold text-white mb-4', [
            Component.text('Simple, transparent pricing'),
          ]),
          p(classes: 'text-xl text-gray-400', [
            Component.text('No hidden fees. Cancel anytime.'),
          ]),
        ]),
        // Pricing cards
        div(classes: 'grid md:grid-cols-3 gap-8 max-w-5xl mx-auto', [
          _pricingCard(
            name: 'Starter',
            price: '0',
            description: 'Perfect for trying out',
            features: ['Up to 3 projects', 'Basic analytics', 'Community support'],
            isPopular: false,
          ),
          _pricingCard(
            name: 'Pro',
            price: '29',
            description: 'For growing teams',
            features: ['Unlimited projects', 'Advanced analytics', 'Priority support', 'Custom domains'],
            isPopular: true,
          ),
          _pricingCard(
            name: 'Enterprise',
            price: '99',
            description: 'For large organizations',
            features: ['Everything in Pro', 'SLA guarantee', 'Dedicated support', 'Custom integrations'],
            isPopular: false,
          ),
        ]),
      ]),
    ]);
  }

  static Component _pricingCard({
    required String name,
    required String price,
    required String description,
    required List<String> features,
    required bool isPopular,
  }) {
    final borderClass = isPopular ? 'border-cyan-500' : 'border-gray-700';
    final bgClass = isPopular ? 'bg-gray-800' : 'bg-gray-800/50';

    return div(classes: 'p-8 $bgClass rounded-2xl border $borderClass relative', [
      if (isPopular)
        div(classes: 'absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 bg-cyan-600 text-white text-sm font-medium rounded-full', [
          Component.text('Most Popular'),
        ]),
      h3(classes: 'text-xl font-semibold text-white mb-2', [Component.text(name)]),
      p(classes: 'text-gray-400 mb-6', [Component.text(description)]),
      div(classes: 'mb-6', [
        span(classes: 'text-5xl font-bold text-white', [Component.text('\$$price')]),
        span(classes: 'text-gray-400', [Component.text('/month')]),
      ]),
      ul(classes: 'space-y-3 mb-8', [
        for (final feature in features)
          li(classes: 'flex items-center gap-3 text-gray-300', [
            span(classes: 'text-cyan-400', [Component.text('✓')]),
            Component.text(feature),
          ]),
      ]),
      a(
        href: '#cta',
        classes: isPopular
            ? 'block w-full py-3 text-center bg-cyan-600 text-white font-medium rounded-lg hover:bg-cyan-700 transition-colors'
            : 'block w-full py-3 text-center border border-gray-600 text-white font-medium rounded-lg hover:bg-gray-700 transition-colors',
        [Component.text('Get Started')],
      ),
    ]);
  }
}
''';

const _testimonialsComponent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class Testimonials extends StatelessComponent {
  const Testimonials({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'testimonials', classes: 'py-20 px-4 bg-gray-900/50', [
      div(classes: 'max-w-7xl mx-auto', [
        // Header
        div(classes: 'text-center mb-16', [
          h2(classes: 'text-4xl font-bold text-white mb-4', [
            Component.text('Loved by developers'),
          ]),
          p(classes: 'text-xl text-gray-400', [
            Component.text('See what our users have to say'),
          ]),
        ]),
        // Testimonials grid
        div(classes: 'grid md:grid-cols-3 gap-8', [
          _testimonialCard(
            quote: 'This product has completely transformed how we build web apps. The developer experience is unmatched.',
            author: 'Sarah Chen',
            role: 'CTO at TechCorp',
          ),
          _testimonialCard(
            quote: 'We shipped our MVP in half the time we expected. The documentation is excellent.',
            author: 'Mike Johnson',
            role: 'Founder at StartupXYZ',
          ),
          _testimonialCard(
            quote: 'The best tool I have used in years. Simple, powerful, and a joy to work with.',
            author: 'Emily Davis',
            role: 'Senior Developer',
          ),
        ]),
      ]),
    ]);
  }

  static Component _testimonialCard({
    required String quote,
    required String author,
    required String role,
  }) {
    return div(classes: 'p-8 bg-gray-800/50 rounded-2xl border border-gray-700', [
      p(classes: 'text-gray-300 mb-6 italic', [
        Component.text('"$quote"'),
      ]),
      div(classes: 'flex items-center gap-4', [
        div(classes: 'w-12 h-12 bg-gradient-to-br from-cyan-400 to-blue-500 rounded-full', []),
        div([
          p(classes: 'text-white font-medium', [Component.text(author)]),
          p(classes: 'text-gray-400 text-sm', [Component.text(role)]),
        ]),
      ]),
    ]);
  }
}
''';

const _faqComponent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class FAQ extends StatelessComponent {
  const FAQ({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'faq', classes: 'py-20 px-4', [
      div(classes: 'max-w-3xl mx-auto', [
        // Header
        div(classes: 'text-center mb-16', [
          h2(classes: 'text-4xl font-bold text-white mb-4', [
            Component.text('Frequently asked questions'),
          ]),
          p(classes: 'text-xl text-gray-400', [
            Component.text('Got questions? We have answers.'),
          ]),
        ]),
        // FAQ items
        div(classes: 'space-y-4', [
          _faqItem(
            question: 'How do I get started?',
            answer: 'Simply sign up for a free account and follow our quick start guide. You will be up and running in minutes.',
          ),
          _faqItem(
            question: 'Can I cancel anytime?',
            answer: 'Yes! You can cancel your subscription at any time with no questions asked. We believe in earning your business every month.',
          ),
          _faqItem(
            question: 'Do you offer refunds?',
            answer: 'We offer a 30-day money-back guarantee. If you are not satisfied, just reach out and we will process your refund.',
          ),
          _faqItem(
            question: 'What kind of support do you offer?',
            answer: 'Free users get community support. Pro and Enterprise users get priority email and chat support with guaranteed response times.',
          ),
        ]),
      ]),
    ]);
  }

  static Component _faqItem({
    required String question,
    required String answer,
  }) {
    return div(classes: 'p-6 bg-gray-800/50 rounded-xl border border-gray-700', [
      h3(classes: 'text-lg font-medium text-white mb-2', [Component.text(question)]),
      p(classes: 'text-gray-400', [Component.text(answer)]),
    ]);
  }
}
''';

const _ctaComponent = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class CTA extends StatelessComponent {
  const CTA({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'cta', classes: 'py-20 px-4', [
      div(classes: 'max-w-4xl mx-auto', [
        div(classes: 'p-12 bg-gradient-to-br from-cyan-900/50 to-blue-900/50 rounded-3xl border border-cyan-800/50 text-center', [
          h2(classes: 'text-4xl font-bold text-white mb-4', [
            Component.text('Ready to get started?'),
          ]),
          p(classes: 'text-xl text-gray-300 mb-8', [
            Component.text('Join thousands of developers building amazing products.'),
          ]),
          div(classes: 'flex flex-col sm:flex-row justify-center gap-4', [
            a(
              href: '#',
              classes: 'px-8 py-4 bg-white text-gray-900 font-medium rounded-lg hover:bg-gray-100 transition-colors',
              [Component.text('Start Free Trial')],
            ),
            a(
              href: '#',
              classes: 'px-8 py-4 border border-white/30 text-white font-medium rounded-lg hover:bg-white/10 transition-colors',
              [Component.text('Contact Sales')],
            ),
          ]),
        ]),
      ]),
    ]);
  }
}
''';
