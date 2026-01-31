/// Home page template
String homePageTemplate(String projectName) => '''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'h-screen flex items-center justify-center bg-gradient-to-b from-gray-900 to-gray-950', [
      div(classes: 'text-center px-4', [
        span(classes: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-cyan-400 bg-cyan-500/10 rounded-full', [
          Component.text('Welcome to Duxt'),
        ]),
        h1(classes: 'text-5xl font-bold text-white mb-6', [Component.text('$projectName')]),
        p(classes: 'text-xl text-gray-400 mb-10', [Component.text('lib/home/pages/index.dart')]),
        div(classes: 'flex justify-center gap-4', [
          a(
            href: 'https://duxt.dev/duxt',
            target: Target.blank,
            classes: 'px-6 py-3 bg-cyan-500 text-white rounded-lg font-medium hover:bg-cyan-600 transition-colors',
            [Component.text('Get Started')],
          ),
          a(
            href: 'https://duxt.dev/duxt-ui',
            target: Target.blank,
            classes: 'px-6 py-3 border border-gray-600 text-gray-300 rounded-lg font-medium hover:bg-gray-800 transition-colors',
            [Component.text('Components')],
          ),
        ]),
      ]),
    ]);
  }
}
''';

/// About page template
const aboutPageTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_ui/duxt_ui.dart';

class AboutPage extends StatelessComponent {
  const AboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: 'About', color: DBadgeColor.primary),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-6', [Component.text('About this app')]),
        p(classes: 'text-lg text-gray-400 mb-8', [
          Component.text('This is a Duxt application. Edit at lib/about/pages/index.dart'),
        ]),
        div(classes: 'flex justify-center gap-4', [
          DButton(label: 'Learn More', color: DButtonColor.primary),
          DButton(label: 'Contact', variant: DButtonVariant.outline, color: DButtonColor.neutral),
        ]),
      ]),
    ]);
  }
}
''';

/// Docs index.md content template
const docsIndexTemplate = '''
---
title: Documentation
---

# Welcome to the Docs

This is an example of **module-level content** using markdown files.

## How it works

1. Create markdown files in `lib/<module>/content/`
2. Routes are auto-generated: `lib/docs/content/getting-started.md` → `/docs/getting-started`
3. Use frontmatter for metadata like `title`, `layout`, etc.

## Features

- **File-based routing** for both Dart pages and markdown content
- **Layouts** for consistent page structure
- **Frontmatter** for page metadata

Check out the [getting started guide](/docs/getting-started) to learn more.
''';

/// Docs getting-started.md template
const docsGettingStartedTemplate = '''
---
title: Getting Started
---

# Getting Started

This guide will help you get started with your Duxt project.

## Project Structure

```
lib/
  home/pages/index.dart       → /
  docs/content/index.md       → /docs
  docs/content/getting-started.md → /docs/getting-started
  shared/layouts/             → layouts
```

## Adding Pages

### Dart Pages

Create a `.dart` file in `lib/<module>/pages/`:

```dart
// lib/about/pages/index.dart → /about
class AboutPage extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div([Component.text('About page')]);
  }
}
```

### Markdown Content

Create a `.md` file in `lib/<module>/content/`:

```markdown
---
title: My Page
---

# Hello World

This is a markdown page.
```

## Next Steps

- Explore the [showcase](/showcase) to see components
- Check the [blog](/blog) for fullstack example
- Read the full docs at [duxt.dev](https://duxt.dev)
''';

/// Showcase page template
const showcasePageTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_ui/duxt_ui.dart';

class ShowcasePage extends StatefulComponent {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  String _selectedTab = 'buttons';

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-20 pb-16 px-4', [
      div(classes: 'max-w-5xl mx-auto', [
        div(classes: 'text-center mb-12', [
          h1(classes: 'text-4xl font-bold text-white mb-4', [Component.text('Component Showcase')]),
          a(href: 'https://duxt.dev/duxt-ui', target: Target.blank, classes: 'text-cyan-400 hover:text-cyan-300', [Component.text('View docs →')]),
        ]),
        DControlledTabs(
          items: [
            DTabItem(value: 'buttons', label: 'Buttons'),
            DTabItem(value: 'inputs', label: 'Inputs'),
            DTabItem(value: 'feedback', label: 'Feedback'),
          ],
          selected: _selectedTab,
          onSelect: (value) => setState(() => _selectedTab = value),
        ),
        div(classes: 'mt-8', [
          if (_selectedTab == 'buttons') ...[
            _section('Variants', [
              DButton(label: 'Solid', variant: DButtonVariant.solid),
              DButton(label: 'Outline', variant: DButtonVariant.outline),
              DButton(label: 'Ghost', variant: DButtonVariant.ghost),
            ]),
            _section('Colors', [
              DButton(label: 'Primary', color: DButtonColor.primary),
              DButton(label: 'Success', color: DButtonColor.success),
              DButton(label: 'Error', color: DButtonColor.error),
            ]),
          ],
          if (_selectedTab == 'inputs') ...[
            _section('Text Inputs', [DInput(placeholder: 'Default input'), DInput(label: 'With Label')]),
            _section('Controls', [DCheckbox(label: 'Checkbox'), DSwitch(label: 'Switch')]),
          ],
          if (_selectedTab == 'feedback') ...[
            _section('Alerts', [
              DAlert(title: 'Info', description: 'Informational message'),
              DAlert(title: 'Success', description: 'Operation completed', color: DAlertColor.success),
            ]),
            _section('Badges', [DBadge(label: 'Default'), DBadge(label: 'Primary', color: DBadgeColor.primary)]),
          ],
        ]),
      ]),
    ]);
  }

  Component _section(String title, List<Component> children) {
    return div(classes: 'mb-8', [
      h3(classes: 'text-lg font-semibold text-white mb-4', [Component.text(title)]),
      div(classes: 'flex flex-wrap gap-3', children),
    ]);
  }
}
''';

/// Company pages templates
const companyIndexTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyPage extends StatelessComponent {
  const CompanyPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company', color: DBadgeColor.primary),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('Company')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('Nested routing example')]),
        div(classes: 'flex flex-wrap justify-center gap-3', [
          Link(to: '/company/about', child: DButton(label: '/company/about')),
          Link(to: '/company/team', child: DButton(label: '/company/team', variant: DButtonVariant.outline)),
        ]),
      ]),
    ]);
  }
}
''';

const companyAboutTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyAboutPage extends StatelessComponent {
  const CompanyAboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company/about', color: DBadgeColor.success),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('About Company')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('lib/company/pages/about.dart')]),
        Link(to: '/company', child: DButton(label: '← Back', variant: DButtonVariant.ghost)),
      ]),
    ]);
  }
}
''';

const companyTeamTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyTeamPage extends StatelessComponent {
  const CompanyTeamPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company/team', color: DBadgeColor.warning),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('Our Team')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('lib/company/pages/team/index.dart')]),
        div(classes: 'flex flex-wrap justify-center gap-3', [
          Link(to: '/company', child: DButton(label: '← /company', variant: DButtonVariant.ghost)),
          Link(to: '/company/team/engineering', child: DButton(label: '/company/team/engineering')),
        ]),
      ]),
    ]);
  }
}
''';

const companyEngineeringTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

class CompanyTeamEngineeringPage extends StatelessComponent {
  const CompanyTeamEngineeringPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 flex items-center justify-center px-4', [
      div(classes: 'max-w-2xl mx-auto text-center', [
        DBadge(label: '/company/team/engineering', color: DBadgeColor.error),
        h1(classes: 'text-4xl font-bold text-white mt-6 mb-4', [Component.text('Engineering Team')]),
        p(classes: 'text-gray-400 mb-8', [Component.text('lib/company/pages/team/engineering.dart')]),
        Link(to: '/company/team', child: DButton(label: '← /company/team', variant: DButtonVariant.ghost)),
      ]),
    ]);
  }
}
''';
