# Duxt

A Nuxt-like meta-framework for [Jaspr](https://jaspr.dev) - bringing file-based routing, layouts, and Rails-like scaffolding to Dart web development.

## Features

- **File-based Routing** - Pages in `lib/pages/` auto-generate routes
- **Layouts System** - Reusable layout wrappers
- **Middleware** - Route guards for auth, redirects, etc.
- **API Routes** - Server endpoints in `server/api/`
- **Composables** - Vue-like reactive state hooks
- **Scaffold Generator** - Rails-like CRUD generation
- **Tailwind CSS** - Built-in integration

## Installation

```bash
dart pub global activate duxt
```

## Quick Start

```bash
# Create a new project
duxt create my-app
cd my-app
dart pub get

# Start development server
duxt dev

# Or start production server
duxt build
duxt start
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `duxt create <name>` | Create a new Duxt project |
| `duxt dev [--port]` | Start dev server with hot reload |
| `duxt start [--port]` | Start production server |
| `duxt build` | Build for production |
| `duxt generate` | Generate static site |
| `duxt g <type> <name> [fields]` | Generate with fields |
| `duxt add <type> <name>` | Add a file |
| `duxt scaffold <name> [fields]` | Full CRUD scaffold |

## Generators

### Generate Command (`duxt g`)

```bash
# Generate a model
duxt g model post title:String content:String

# Generate a component
duxt g component card title:String

# Generate a page
duxt g page about

# Generate a dynamic page
duxt g page 'posts/[slug]'

# Generate an API route
duxt g api users

# Generate middleware
duxt g middleware auth
```

**Type shortcuts:** `p`=page, `c`=component, `m`=model, `a`=api, `mw`=middleware, `co`=composable

### Scaffold Command

Generate full CRUD (model, pages, component, API):

```bash
duxt scaffold product name:String price:double description:String

# Generates:
# - lib/models/product.dart
# - lib/pages/products/index.dart
# - lib/pages/products/[id].dart
# - lib/components/product_card.dart
# - server/api/products.dart
```

Options:
- `--api-only` - Only generate model and API
- `--force` - Overwrite existing files

## Project Structure

```
my-app/
├── lib/
│   ├── main.client.dart      # Entry point
│   ├── app.dart              # Router configuration
│   ├── pages/                # File-based routing
│   │   ├── index.dart        # → /
│   │   ├── about.dart        # → /about
│   │   └── posts/
│   │       └── [slug].dart   # → /posts/:slug
│   ├── layouts/              # Layout components
│   │   └── default.dart
│   ├── components/           # Reusable components
│   └── models/               # Data models
├── middleware/               # Route middleware
├── composables/              # Shared reactive logic
├── server/
│   └── api/                  # API routes
├── web/
│   ├── index.html
│   └── styles.tw.css         # Tailwind CSS
├── duxt.config.dart          # Configuration
└── pubspec.yaml
```

## Routing Conventions

| File | Route |
|------|-------|
| `pages/index.dart` | `/` |
| `pages/about.dart` | `/about` |
| `pages/posts/index.dart` | `/posts` |
| `pages/posts/[id].dart` | `/posts/:id` |
| `pages/posts/[...slug].dart` | `/posts/*` |

## Example Page

```dart
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class AboutPage extends StatelessComponent {
  const AboutPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'container mx-auto p-4', [
      h1(classes: 'text-3xl font-bold', [
        text('About Us'),
      ]),
      p(classes: 'mt-4 text-gray-600', [
        text('Welcome to our site!'),
      ]),
    ]);
  }
}
```

## Example API Route

```dart
import 'package:duxt/server.dart';

final handler = defineEventHandler((request) async {
  switch (request.method) {
    case 'GET':
      return ApiResponse.json({'message': 'Hello!'});
    case 'POST':
      final body = request.json;
      return ApiResponse.created(body);
    default:
      return ApiResponse.methodNotAllowed();
  }
});
```

## Requirements

- Dart SDK ^3.0.0
- Jaspr ^0.22.1

## License

MIT
