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

- **Module-Based Architecture** — Organize code by feature with pages, components, models & APIs
- **File-Based Routing** — Pages and markdown files auto-generate routes
- **3 Rendering Modes** — Static (SSG), Server (SSR), or Client (SPA)
- **Namespace Support** — Nest modules under namespaces like `Admin/Post`
- **Built-in Tailwind CSS** — Automatic compilation, no extra dependencies
- **Desktop Apps** — Native desktop via Tauri with `duxt build desktop`
- **Scaffold Generator** — Full CRUD from a single command
- **Markdown Content** — Docs and blog content with frontmatter
- **Security Middleware** — CORS, rate limiting, CSRF, security headers
- **Multi-Target Builds** — Cross-compile for Linux, macOS, Windows
- **Performance Tracing** — `--perf` flag for rebuild stage timings

---

## Quick Start

```bash
dart pub global activate duxt
duxt create my-app
cd my-app && dart pub get
duxt dev
```

Your app runs at `http://localhost:4000`. Choose from **static**, **server**, or **client** templates when creating.

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
│   │   │   └── intro.md            # -> /blog/intro
│   │   ├── components/
│   │   └── model.dart
│   ├── admin/posts/pages/          # -> /admin/posts (namespace)
│   ├── theme/home/pages/           # -> / (theme strips prefix)
│   └── shared/layouts/
├── server/                         # Backend (server template)
├── web/styles.tw.css               # Tailwind input
└── duxt.config.dart
```

---

## CLI

```bash
duxt create my-app                # Create project
duxt dev                          # Dev server + hot reload
duxt dev --perf --verbose         # With performance tracing
duxt build                        # Production build
duxt build desktop                # Desktop app (Tauri)
duxt start --open                 # Run production server
duxt g module posts               # Generate module
duxt g module Admin/Post          # Namespaced module
duxt scaffold posts title:String  # Full CRUD generation
duxt d module posts               # Delete module
duxt info                         # Project summary
duxt doctor                       # Environment check
```

See all commands and options at [duxt.dev/duxt-cli](https://duxt.dev/duxt-cli).

---

## Ecosystem

| Package | Description |
|---------|-------------|
| [duxt](https://pub.dev/packages/duxt) | CLI & runtime framework |
| [duxt_html](https://pub.dev/packages/duxt_html) | Flutter-style HTML components for Jaspr (80+ typed components) |
| [duxt_ui](https://pub.dev/packages/duxt_ui) | Beautiful, accessible UI components (50+) |
| [duxt_orm](https://pub.dev/packages/duxt_orm) | ActiveRecord-style ORM — PostgreSQL, MySQL & SQLite |
| [duxt_signals](https://pub.dev/packages/duxt_signals) | Reactive signals for lightweight state management |
| [duxt_icons](https://pub.dev/packages/duxt_icons) | 200,000+ icons from Iconify — inline SVG for SSR |
| [duxt_mcp](https://duxt.dev/duxt-mcp) | MCP server for AI tools (Claude Code, Cursor) |

---

## Requirements

- **Dart SDK** ^3.0.0
- **Jaspr** ^0.22.2
- **Tailwind CSS** v4+ (auto-detected)

---

## Documentation

Full guides, API reference, and tutorials at **[duxt.dev](https://duxt.dev)**

- [Getting Started](https://duxt.dev/duxt-cli/create)
- [CLI Reference](https://duxt.dev/duxt-cli)
- [Routing](https://duxt.dev/duxt-cli/dev)
- [Scaffolding](https://duxt.dev/duxt-cli/utilities)
- [Security](https://duxt.dev/duxt/security)

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <sub>Built by the <a href="https://duxt.dev">duxt.dev</a> team</sub>
</p>
