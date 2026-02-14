<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/duxt-base/duxt/main/web/logo.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/duxt-base/duxt/main/web/logo.svg">
  <img alt="Duxt" src="https://raw.githubusercontent.com/duxt-base/duxt/main/web/logo.svg" width="180">
</picture>

# Duxt

[![Pub Version](https://img.shields.io/pub/v/duxt?color=00C0E8&label=pub.dev)](https://pub.dev/packages/duxt)
[![License: MIT](https://img.shields.io/badge/license-MIT-00C0E8.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.0+-00C0E8.svg)](https://dart.dev)

**The meta-framework for [Jaspr](https://jaspr.dev)** — Build full-stack Dart web apps with module-based architecture, file-based routing, and powerful scaffolding.

---

## Features

| Feature | Description |
|---------|-------------|
| **Module-Based Architecture** | Organize code by feature with pages, components, models & APIs |
| **File-Based Routing** | Pages and markdown files auto-generate routes — no manual config |
| **3 Project Templates** | Static (SSG), Server (SSR), or Client (SPA) — pick your rendering mode |
| **Namespace Support** | Nest modules under namespaces like `Admin/Post` for grouped routes |
| **Built-in Tailwind CSS** | Automatic compilation with watch mode — no `jaspr_tailwind` needed |
| **Desktop Apps** | Build native desktop apps with Tauri via `duxt build desktop` |
| **Scaffold Generator** | Full CRUD (model, API, pages, forms) from a single command |
| **Content & Docs** | Markdown content with frontmatter, table of contents, custom components |
| **Security Middleware** | CORS, rate limiting, CSRF, body limits, security headers out of the box |
| **Multi-Target Builds** | Cross-compile for linux-x64, linux-arm64, macos-x64, macos-arm64 |
| **Performance Tracing** | `--perf` flag shows rebuild stage timings to diagnose slow builds |

---

## Quick Start

### Installation

```bash
dart pub global activate duxt
```

### Create Your First App

```bash
duxt create my-app
cd my-app
dart pub get
duxt dev
```

Choose a template when prompted:

| Template | Mode | Best For |
|----------|------|----------|
| **static** | SSG | Marketing sites, landing pages, docs |
| **server** | SSR | Dynamic apps, blogs, content sites with ORM + API |
| **client** | SPA | Interactive single-page apps with client-side rendering |

Your app runs at `http://localhost:4000` with SSR frontend and API server on port 4001.

---

## Project Structure

```
my-app/
├── lib/
│   ├── blog/                       # Feature module
│   │   ├── pages/
│   │   │   ├── index.dart          # -> /blog
│   │   │   └── _id_.dart           # -> /blog/:id
│   │   ├── content/
│   │   │   └── getting-started.md  # -> /blog/getting-started
│   │   ├── components/
│   │   ├── model.dart
│   │   └── api.dart
│   ├── admin/                      # Namespace
│   │   ├── posts/                  # -> /admin/posts
│   │   │   └── pages/
│   │   └── layouts/
│   │       └── default.dart        # Wraps all /admin/* routes
│   ├── theme/                      # Theme namespace (strips prefix)
│   │   └── home/
│   │       └── pages/
│   │           └── index.dart      # -> /
│   ├── shared/
│   │   ├── layouts/
│   │   │   └── default.dart
│   │   ├── components/
│   │   └── middleware/
│   ├── app.dart
│   └── main.dart
├── server/                         # Backend (server template)
│   ├── db.dart
│   ├── api/
│   └── models/
├── web/
│   └── styles.tw.css               # Tailwind input
├── duxt.config.dart                # Project configuration
└── .generated/
    └── routes.dart                 # Auto-generated routes
```

### Routing Conventions

| File Path | Route |
|-----------|-------|
| `lib/home/pages/index.dart` | `/` |
| `lib/blog/pages/index.dart` | `/blog` |
| `lib/blog/pages/_id_.dart` | `/blog/:id` |
| `lib/blog/pages/_id_/edit.dart` | `/blog/:id/edit` |
| `lib/blog/content/intro.md` | `/blog/intro` |
| `lib/admin/posts/pages/index.dart` | `/admin/posts` |
| `lib/theme/about/pages/index.dart` | `/about` |

---

## CLI Commands

| Command | Description |
|---------|-------------|
| `duxt create` | Create a new project (static/server/client) |
| `duxt dev` | Dev server with SSR + hot reload |
| `duxt build` | Build for production |
| `duxt build desktop` | Build native desktop app (Tauri) |
| `duxt start` | Run production server |
| `duxt preview` | Preview production build locally |
| `duxt generate` | Generate static site (SSG) |
| `duxt g` | Generate module, page, component, model, api, layout |
| `duxt scaffold` | Generate full CRUD module |
| `duxt d` | Delete module, page, or component |
| `duxt docs` | Generate API docs, doc pages, tutorials |
| `duxt info` | Show project structure summary |
| `duxt doctor` | Environment diagnostics |
| `duxt clean` | Clean build artifacts |
| `duxt update` | Update CLI to latest version |

### Dev Server Options

```bash
duxt dev                          # Default: port 4000
duxt dev --port=8080              # Custom port
duxt dev --no-api                 # Skip API server
duxt dev --verbose                # Detailed build output
duxt dev --perf                   # Rebuild stage timings
duxt dev --reload                 # Module reload mode (faster, experimental)
duxt dev --desktop                # Tauri desktop window
```

### Build Options

```bash
duxt build                        # Web build (default)
duxt build --target=linux-arm64   # Cross-compile for specific target
duxt build --all-targets          # All platforms (requires Docker)
duxt build desktop                # Native desktop app via Tauri
```

### Production

```bash
duxt start                        # Auto-finds free port
duxt start --port=8080            # Specific port
duxt start --open                 # Open browser after starting
duxt preview                      # Preview build on port 4000
duxt preview --port=3000          # Custom preview port
```

---

## Generators

### Generate Files

```bash
duxt g module posts                              # Full module
duxt g module Admin/Post                         # Namespaced module -> /admin/posts
duxt g page posts/_id_                           # Dynamic page
duxt g component posts/card title:String         # Component with props
duxt g model post title:String content:String    # Model with fields
duxt g api posts                                 # API client
duxt g layout dashboard                          # Layout
duxt g layout Admin                              # Namespace layout
```

### Scaffold (Full CRUD)

```bash
duxt scaffold posts title:String content:String author:String
duxt scaffold Admin/Post title:String body:String    # Namespaced
```

Generates: model, API, list page, detail page, create form, card component, form component, and server-side ORM model with REST endpoints.

### Delete Files

```bash
duxt d module posts        # Delete entire module
duxt d page posts/_id_     # Delete specific page
duxt d component header    # Delete component
```

---

## API Client

```dart
import 'package:duxt/duxt.dart';

// Configure
Api.configure(baseUrl: 'https://api.example.com');
Api.setAuth('your-jwt-token');

// CRUD
final posts = await Api.get('/posts');
final post = await Api.post('/posts', body: {'title': 'Hello'});
await Api.put('/posts/1', body: {'title': 'Updated'});
await Api.delete('/posts/1');
```

---

## State Management (SPA)

### DuxtState — Single Data Source

```dart
class PostsPage extends StatefulComponent {
  @override
  State createState() => _PostsState();
}

class _PostsState extends DuxtState<PostsPage, List<Post>> {
  @override
  Future<List<Post>> load() => PostsApi.getAll();

  @override
  Component buildLoading() => Text('Loading...');

  @override
  Component buildError(Object error) => Text('Error: $error');

  @override
  Component buildData(List<Post> posts) => div([
    for (final post in posts) PostCard(post: post),
  ]);
}
```

### DuxtMultiState — Multiple Data Sources

```dart
class _DashboardState extends DuxtMultiState<DashboardPage> {
  @override
  Map<String, Future<dynamic> Function()> get loaders => {
    'posts': () => PostsApi.getAll(),
    'stats': () => StatsApi.get(),
  };

  @override
  Component buildData(Map<String, dynamic> data) {
    final posts = getData<List<Post>>('posts');
    final stats = getData<Stats>('stats');
    return Dashboard(posts: posts!, stats: stats!);
  }
}
```

---

## Navigation

```dart
import 'package:duxt/duxt.dart';

// Extension methods on BuildContext
context.push('/posts');
context.push('/posts/1', extra: {'from': 'list'});
context.replace('/login');
context.back();
context.pushNamed('post-detail', params: {'id': '123'});
context.preload('/posts');  // Preload for faster navigation
```

---

## Content & Documentation

Place markdown files in any module's `content/` directory:

```
lib/docs/content/
├── getting-started.md    # -> /docs/getting-started
├── guides/
│   └── routing.md        # -> /docs/guides/routing
└── api-reference.md      # -> /docs/api-reference
```

Generate documentation scaffolds:

```bash
duxt docs page getting-started       # Create doc page template
duxt docs tutorial deploy-guide      # Create step-by-step tutorial
duxt docs generate                   # Generate API docs from code
```

---

## Security Middleware

Server template includes production-ready middleware:

```dart
import 'package:duxt/server.dart';

final server = DuxtServer();

server.use(securityHeaders());         // X-Content-Type-Options, X-Frame-Options
server.use(bodyLimit(maxBytes: 1024 * 1024));  // 1 MB body limit
server.use(rateLimit(maxRequests: 100));        // 100 req/min per IP
server.use(timeout(duration: Duration(seconds: 30)));
server.use(cors(origins: ['https://mysite.com']));
```

---

## Tailwind CSS

Built-in compilation — no `jaspr_tailwind` dependency needed.

```css
/* web/styles.tw.css */
@import "tailwindcss";

@source "../lib/**/*.dart";
@source "../.duxt/packages/**/*.dart";
```

Automatically compiles on `duxt dev` (watch mode) and `duxt build` (optimized).

---

## Using with Duxt UI

[Duxt UI](https://github.com/duxt-base/duxt-ui) provides pre-built Tailwind components:

```yaml
dependencies:
  duxt: ^0.6.0
  duxt_ui: ^0.2.0
```

```dart
import 'package:duxt_ui/duxt_ui.dart';

DButton(label: 'Get Started', color: DButtonColor.primary);
DInput(label: 'Email', type: InputType.email);
DModal(title: 'Confirm', children: [...]);
DAlert(title: 'Success', color: DAlertColor.success);
```

---

## Requirements

- **Dart SDK** ^3.0.0
- **Jaspr** ^0.22.2
- **Tailwind CSS** v4+ (auto-detected)

---

## Documentation

Visit [duxt.dev](https://duxt.dev) for full documentation.

---

## Contributing

Contributions welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built by the <a href="https://duxt.dev">duxt.dev</a> team</sub>
</p>
