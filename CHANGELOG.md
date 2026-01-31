# Changelog

All notable changes to this project will be documented in this file.

## [0.3.10] - 2026-01-31

### Fixed
- Template: app.dart now passes DuxtPageConfig with layouts to generatedRoutes()
- Template: DefaultPageLayout uses proper prose styling with !important variants
- Template: Readable text colors for all markdown elements (paragraphs, lists, headings)

## [0.3.9] - 2026-01-31

### Fixed
- Template: Improved default layout - sticky header with backdrop blur, proper footer
- Template: Fixed markdown content pages to use dark theme consistently
- Template: Added prose-invert styling for markdown with cyan accents

## [0.3.8] - 2026-01-31

### Added
- `--mode` flag for `duxt create` - Allows non-interactive project creation

### Fixed
- Template: Fixed `app.dart` - removed undefined `DefaultPageLayout()` call
- Template: Fixed showcase page - changed `DTabs` to `DControlledTabs` with correct props
- Template: Fixed `server/main.dart` - removed `staticDir` parameter not in published API
- Documentation: Updated all dynamic route examples to use `_param_` syntax

### Changed
- Updated template dependencies to use latest duxt version

## [0.3.7] - 2026-01-30

### Added
- `duxt doctor` command - Shows environment and project diagnostics, wraps `jaspr doctor`
- `duxt version` command
- Added `example/example.dart` for pub.dev scoring

### Fixed
- `duxt update` now shows correct current version (was hardcoded to 0.3.2)
- `duxt clean` now also runs `jaspr clean` for complete cleanup
- Removed `web/index.html` from project template - allows SSR/SSG to work correctly
- SSR now works properly with `duxt dev` (jaspr serve)

### Changed
- Improved README with latest features documentation
- Updated CLI help to show jaspr command mappings

## [0.3.6] - 2026-01-29

### Fixed
- Fixed @source paths in styles.tw.css (relative to web/ directory)
- `duxt dev` now runs `dart pub get` automatically if pubspec.lock missing

## [0.3.5] - 2026-01-29

### Added
- **Built-in Tailwind CSS compilation** - `duxt dev` and `duxt build` now compile Tailwind directly
- No need for `jaspr_tailwind` dependency - Duxt handles everything
- Tailwind watch mode during development with live recompilation

### Changed
- Removed `jaspr_tailwind` from template dev_dependencies
- Template styles.tw.css now uses @source directives for Tailwind v4

## [0.3.4] - 2026-01-29

### Added
- `duxt dev` now syncs duxt_ui package to `.duxt/packages/` for Tailwind CSS scanning
- Cross-platform support for Tailwind class scanning (works on Windows, macOS, Linux)
- Template now includes `.gitignore` with common exclusions

### Fixed
- duxt_ui Tailwind classes now work correctly when installed from pub.dev

## [0.3.3] - 2026-01-29

### Fixed
- Updated duxt_ui dependency to ^0.2.3 (fixes unstyled components)

## [0.3.2] - 2026-01-29

### Fixed
- Template now correctly includes Blog, Company modules
- Dark theme with cyan color scheme applied

## [0.3.1] - 2026-01-29

### Added
- `duxt update` command to update CLI to latest version
- Automatic update check on CLI startup (non-blocking)

### Fixed
- Removed compiled binary from package (was causing UTF-8 decode error)

## [0.3.0] - 2026-01-29

### Added
- **Fullstack template** - New projects include a complete blog example with SQLite
- **Server API structure** - `server/db.dart`, `server/models/`, `server/api/`
- **Multi-target builds** - `duxt build --target=linux-arm64`
- **Cross-compilation** - Docker-based Linux builds from any platform
- **Nested routing example** - `/company/team/engineering` demonstrates deep nesting

### Changed
- `duxt dev` now starts both frontend (4000) and API server (3001)
- `duxt build` compiles server binary with architecture suffix
- Template includes Blog, Showcase, Company, About modules
- Default layout uses Duxt logo from duxt.dev

### New CLI Options
- `duxt dev --api-port=3001` - Set API server port
- `duxt dev --no-api` - Skip API server
- `duxt build --target=<platform>` - Target platform (linux-x64, linux-arm64, macos-x64, macos-arm64)
- `duxt build --all-targets` - Build for all platforms

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
