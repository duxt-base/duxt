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
| **File-Based Routing** | Pages auto-generate routes — no manual configuration |
| **Fullstack Template** | New projects include a complete blog example with SQLite |
| **Built-in Tailwind CSS** | Automatic Tailwind compilation with watch mode |
| **Multi-Target Builds** | Cross-compile for linux-x64, linux-arm64, macos-x64, macos-arm64 |
| **Simple API Client** | Static `Api` class with auth, headers & error handling |
| **SPA State Management** | `DuxtState` mixin handles loading, error & data states |
| **Scaffold Generator** | Full CRUD generation with a single command |
| **Middleware** | Route guards for authentication & authorization |
| **Content Support** | Markdown content with frontmatter for docs sites |

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

Your app is running at `http://localhost:4000` with:
- SSR frontend on port 4000
- API server on port 3001

---

## Project Structure

```
my-app/
├── lib/
│   ├── posts/                    # Feature module
│   │   ├── pages/
│   │   │   ├── index.dart        # -> /posts
│   │   │   ├── [id].dart         # -> /posts/:id
│   │   │   └── [id]/
│   │   │       └── edit.dart     # -> /posts/:id/edit
│   │   ├── components/
│   │   │   └── post_card.dart
│   │   ├── model.dart
│   │   └── api.dart
│   ├── shared/
│   │   ├── layouts/
│   │   │   └── default.dart
│   │   ├── components/
│   │   └── middleware/
│   ├── app.dart
│   └── main.dart
├── server/                       # Backend
│   ├── db.dart                   # Database setup
│   ├── api/                      # API routes
│   └── models/
├── web/
│   └── styles.tw.css            # Tailwind input
└── .duxt/                        # Generated files
    └── routes.g.dart
```

---

## CLI Commands

| Command | Description | Jaspr Equivalent |
|---------|-------------|------------------|
| `duxt create` | Create a new project | - |
| `duxt dev` | Start dev server with SSR + hot reload | `jaspr serve` |
| `duxt build` | Build for production | `jaspr build` |
| `duxt start` | Run production server | - |
| `duxt preview` | Preview production build locally | - |
| `duxt generate` | Generate static site (SSG only) | - |
| `duxt g` | Generate files | - |
| `duxt scaffold` | Generate full CRUD module | - |
| `duxt d` | Delete module, page, or component | - |
| `duxt doctor` | Show environment diagnostics | `jaspr doctor` |
| `duxt clean` | Clean build artifacts | `jaspr clean` |
| `duxt update` | Update CLI to latest version | - |
| `duxt version` | Show version | - |

### Development Options

```bash
# Start with custom ports
duxt dev --port=8080 --api-port=4000

# Skip API server
duxt dev --no-api
```

### Build Options

```bash
# Build for specific target
duxt build --target=linux-arm64

# Build for all targets
duxt build --all-targets

# Available targets: linux-x64, linux-arm64, macos-x64, macos-arm64
```

---

## Generators

### Generate Files

```bash
# Module (creates pages/, components/, model.dart, api.dart)
duxt g module posts

# Page (with dynamic params)
duxt g page posts/[id]

# Component (with props)
duxt g component posts/card title:String author:String

# Model (with fields)
duxt g model post title:String content:String createdAt:DateTime

# API
duxt g api posts

# Layout
duxt g layout dashboard
```

**Type shortcuts:** `p`=page, `c`=component, `m`=model, `a`=api, `l`=layout

### Scaffold (Full CRUD)

```bash
duxt scaffold posts title:String content:String author:String
```

Generates:
- Model with JSON serialization
- API class with CRUD methods
- List page with pagination
- Detail page
- Create/Edit forms

### Delete Files

```bash
duxt d module posts      # Delete entire module
duxt d page posts/[id]   # Delete specific page
duxt d component posts/card
```

---

## API Client

### Configuration

```dart
import 'package:duxt/duxt.dart';

// Set base URL
Api.configure(baseUrl: 'https://api.example.com');

// Set auth token
Api.setAuth('your-jwt-token');

// Add custom headers
Api.configure(
  baseUrl: 'https://api.example.com',
  headers: {'X-Custom-Header': 'value'},
);
```

### Making Requests

```dart
// GET
final posts = await Api.get('/posts');
final post = await Api.get('/posts/1');

// POST
final newPost = await Api.post('/posts', body: {
  'title': 'Hello World',
  'content': 'My first post',
});

// PUT
await Api.put('/posts/1', body: {'title': 'Updated'});

// PATCH
await Api.patch('/posts/1', body: {'title': 'Patched'});

// DELETE
await Api.delete('/posts/1');
```

### Module API Pattern

```dart
// lib/posts/api.dart
class PostsApi {
  static Future<List<Post>> getAll() async {
    final data = await Api.get('/posts');
    return Post.fromList(data);
  }

  static Future<Post> getOne(String id) async {
    final data = await Api.get('/posts/$id');
    return Post.fromJson(data);
  }

  static Future<Post> create(Post post) async {
    final data = await Api.post('/posts', body: post.toJson());
    return Post.fromJson(data);
  }

  static Future<Post> update(String id, Post post) async {
    final data = await Api.put('/posts/$id', body: post.toJson());
    return Post.fromJson(data);
  }

  static Future<void> delete(String id) async {
    await Api.delete('/posts/$id');
  }
}
```

---

## State Management (SPA)

### DuxtState

Handle async data loading with automatic state management:

```dart
class PostsPage extends StatefulComponent {
  @override
  State createState() => _PostsState();
}

class _PostsState extends DuxtState<PostsPage, List<Post>> {
  @override
  Future<List<Post>> load() => PostsApi.getAll();

  @override
  Component buildLoading() => DSpinner();

  @override
  Component buildError(Object error) => DAlert(
    title: 'Error',
    description: error.toString(),
    color: DAlertColor.error,
  );

  @override
  Component buildData(List<Post> posts) => div([
    for (final post in posts)
      PostCard(post: post),
  ]);
}
```

### DuxtMultiState

Load multiple data sources in parallel:

```dart
class _DashboardState extends DuxtMultiState<DashboardPage> {
  @override
  Map<String, Future<dynamic>> get loaders => {
    'posts': PostsApi.getAll(),
    'users': UsersApi.getAll(),
    'stats': StatsApi.get(),
  };

  @override
  Component buildData(Map<String, dynamic> data) {
    final posts = data['posts'] as List<Post>;
    final users = data['users'] as List<User>;
    final stats = data['stats'] as Stats;

    return Dashboard(posts: posts, users: users, stats: stats);
  }
}
```

---

## Middleware

### Create Middleware

```dart
// lib/shared/middleware/auth_middleware.dart
class AuthMiddleware extends DuxtMiddleware {
  @override
  Future<MiddlewareResult> handle(RouteState route) async {
    final token = await TokenStorage.getToken();

    if (token == null) {
      return MiddlewareResult.redirect('/login');
    }

    return MiddlewareResult.next();
  }
}
```

### Apply to Pages

```dart
class SecurePage extends DuxtPage {
  @override
  List<DuxtMiddleware> get middleware => [AuthMiddleware()];

  @override
  Component build(BuildContext context) => div([
    text('Protected content'),
  ]);
}
```

---

## Layouts

### Create a Layout

```dart
// lib/shared/layouts/dashboard_layout.dart
class DashboardLayout extends DuxtLayout {
  @override
  Component build(BuildContext context, Component child) => div(
    classes: 'flex min-h-screen',
    [
      Sidebar(),
      main(classes: 'flex-1 p-6', [child]),
    ],
  );
}
```

### Apply to Pages

```dart
class DashboardPage extends DuxtPage {
  @override
  Type get layout => DashboardLayout;

  @override
  Component build(BuildContext context) => div([
    text('Dashboard content'),
  ]);
}
```

---

## Server API (Backend)

### Create API Routes

```dart
// lib/api/server.dart
import 'package:duxt/server.dart';

void main() {
  final server = DuxtServer();

  // Middleware
  server.use(corsMiddleware());
  server.use(loggerMiddleware());
  server.use(jsonBodyParser());

  // Routes
  server.get('/posts', (req, res) async {
    final posts = await db.posts.findAll();
    return res.json(posts);
  });

  server.post('/posts', (req, res) async {
    final body = req.body;
    final post = await db.posts.create(body);
    return res.json(post, status: 201);
  });

  server.get('/posts/:id', (req, res) async {
    final id = req.params['id'];
    final post = await db.posts.findById(id);
    if (post == null) return res.notFound();
    return res.json(post);
  });

  server.listen(port: 3000);
}
```

---

## Content & Documentation

Build documentation sites with markdown:

```dart
// Load markdown content
final content = await ContentLoader.load('docs/getting-started.md');

// Access frontmatter
print(content.frontmatter['title']);
print(content.frontmatter['description']);

// Render HTML
print(content.html);

// Get table of contents
print(content.toc);
```

---

## Tailwind CSS

Duxt includes built-in Tailwind CSS compilation. No additional setup required.

```css
/* web/styles.tw.css */
@import "tailwindcss";

@source "../lib/**/*.dart";
@source "../.duxt/packages/**/*.dart";
```

Tailwind automatically:
- Compiles on `duxt dev` with watch mode
- Builds optimized CSS on `duxt build`
- Scans Dart files for class names

---

## Using with Duxt UI

Duxt works seamlessly with [Duxt UI](https://github.com/duxt-base/duxt-ui) for beautiful, pre-built components:

```yaml
dependencies:
  duxt: ^0.3.0
  duxt_ui: ^0.2.0
```

```dart
import 'package:duxt/duxt.dart';
import 'package:duxt_ui/duxt_ui.dart';

class HomePage extends DuxtPage {
  @override
  Component build(BuildContext context) => DContainer([
    DPageHero(
      title: 'Welcome to Duxt',
      description: 'Build beautiful Dart web apps',
    ),
    DButton(
      label: 'Get Started',
      color: DButtonColor.primary,
      onClick: () => Router.of(context).push('/docs'),
    ),
  ]);
}
```

---

## Requirements

- **Dart SDK** ^3.0.0
- **Jaspr** ^0.22.1
- **Tailwind CSS** v4+ (auto-detected or installed)

---

## Documentation

Visit [duxt.dev](https://duxt.dev) for full documentation.

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built by the <a href="https://duxt.dev">duxt.dev</a> team</sub>
</p>
