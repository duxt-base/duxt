# Changelog

All notable changes to this project will be documented in this file.

## [0.2.3] - 2026-01-29

### Changed
- Rewrite composables to use actual Jaspr router APIs
- `useRouter(context)` returns `RouterState` from jaspr_router
- Added `DuxtNavigation` extension on `BuildContext` for `context.push()`, `context.back()`, etc.
- Added `AsyncData<T>` class for standalone async state management
- Added route param helpers: `requireParam`, `paramOr`, `queryParam`, `queryParamOr`
- Removed placeholder `UseFetch`, `UseAsyncData`, `UseState`, `UseRoute`, `UseRouter` classes
- Updated URLs to duxt.dev and duxt-base/duxt

## [0.2.2] - 2026-01-28

### Changed
- Fixed `DuxtState` - changed from mixin to abstract class for better generics support
- Fixed form templates to use proper jaspr `input()` and `button()` API
- Added `jaspr/dom.dart` import to all generated files for HTML elements
- Removed all third-party trademark references
- Updated GitHub URLs to base-al/duxt

### Fixed
- `input()` now uses `type: InputType.text` and `name:` parameters correctly
- `button()` now uses `type: ButtonType.submit` correctly
- Build errors from incorrect jaspr imports

## [0.2.1] - 2026-01-28

### Changed
- Removed third-party trademark references from documentation
- Updated README with new module-based structure examples

## [0.2.0] - 2026-01-28

### Changed
- **Module-based architecture** - Opinionated structure
  ```
  lib/
  ├── posts/           # Module
  │   ├── pages/       # Routes: /posts, /posts/:id
  │   ├── components/  # Module components
  │   ├── model.dart   # Data model
  │   └── api.dart     # API calls
  ├── shared/          # Cross-module
  │   └── layouts/
  └── app.dart
  ```

### Added
- **`Api` class** - Simple static HTTP client
  ```dart
  final posts = await Api.get('/posts');
  await Api.post('/posts', body: {'title': 'Hello'});
  ```
- **`DuxtState` mixin** - SPA data loading with loading/error states
- **`DuxtMultiState` mixin** - Multiple data sources
- **`duxt g module <name>`** - Generate new module
- **`duxt g layout <name>`** - Generate layout
- **`duxt --version`** - Show version
- Grouped help output

### Removed
- `duxt add` command (merged into `duxt g`)
- Old flat structure (`lib/pages/`, `lib/components/`, etc.)

### Fixed
- Router generator now scans module-based structure
- Scaffold generates proper module structure

## [0.1.1] - 2026-01-28

### Fixed
- Updated installation instructions for pub.dev
- Updated lints to 6.0.0

## [0.1.0] - 2026-01-28

### Added
- Initial release
- **CLI Commands**
  - `duxt create` - Create new Duxt project
  - `duxt dev` - Start development server with hot reload
  - `duxt start` - Start production server (auto-finds free port)
  - `duxt build` - Build for production
  - `duxt generate` - Generate static site
  - `duxt g` - Generate files with fields (model, page, component, api, middleware, composable)
  - `duxt add` - Add files without fields
  - `duxt scaffold` - Full CRUD generation

- **Project Structure**
  - File-based routing from `lib/pages/`
  - Layouts system in `lib/layouts/`
  - Components in `lib/components/`
  - Models in `lib/models/`
  - API routes in `server/api/`
  - Middleware in `middleware/`
  - Composables in `composables/`

- **Runtime Features**
  - `DuxtPage` - Base page class with layout, middleware, meta
  - `DuxtLayout` - Base layout class
  - `DuxtMiddleware` - Route middleware support
  - `DuxtContext` - Context for asyncData and middleware
  - Composables: `UseState`, `UseFetch`, `UseAsyncData`, `UseRoute`, `UseRouter`

- **API Handler**
  - `ApiHandler` - Base class for API routes
  - `ApiRequest` / `ApiResponse` - Request/response handling
  - `defineEventHandler` - event handler
  - Helper functions: `readBody`, `getQuery`, `sendRedirect`, etc.

- **Integrations**
  - Jaspr ^0.22.1
  - Jaspr Router ^0.8.1
  - Tailwind CSS via jaspr_tailwind
