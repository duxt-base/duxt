# Changelog

All notable changes to this project will be documented in this file.

## [0.6.2] - 2026-02-18

### Fixed
- Windows `duxt dev` could fail with `jaspr cli not found` due to Unix-only path assumptions.
- Switched remaining CLI jaspr invocations to cross-platform execution via `dart pub global run jaspr_cli:jaspr`.

## [0.6.1] - 2026-02-14

### Fixed
- Upgraded `analyzer` to `^10.0.2` and `build` to `^4.0.4` for full latest-version compatibility on pub.dev
- Migrated `analyze_builder.dart` to analyzer v10 API (fragments, nullable names, `formalParameters`, `Metadata` wrapper)
- Fixed doc comment angle brackets causing pub.dev static analysis warnings

## [0.6.0] - 2026-02-14

### Added
- **`--perf` flag for `duxt dev`** — Print rebuild stage timings (save → build start → compile complete → reload complete) to diagnose slow rebuilds
- **`--reload` flag for `duxt dev`** — Use Jaspr's module reload mode for faster hot reloads (experimental)
- **`--open` flag for `duxt start`** — Open browser automatically after starting production server
- **Auto port finding** — `duxt start` finds a free port automatically if none is specified

### Changed
- **Cross-platform Jaspr CLI resolver** — New `JasprCli` utility resolves the jaspr executable across platforms (PUB_CACHE, Windows, snapshot paths). Replaces fragile hardcoded path lookups in dev, build, and start commands.
- **Smarter file watcher** — Batch dispatch with 100ms debounce. Change type awareness (add/remove/modify) prevents unnecessary route regeneration on file edits. Only structural changes (add/remove) trigger route regeneration.
- **Structured PackageSync results** — `PackageSync.sync()` returns `PackageSyncResult` with `packageConfigFound` and `syncedPackages` for better diagnostics and error messages.
- **Structured Tailwind results** — `Tailwind.compile()` returns `TailwindCompileResult` with differentiated failure reasons (`noInputFile`, `binaryNotFound`, `compileFailed`).
- **Tailwind executable finder** — Multi-path search for `tailwindcss` binary (PATH, /usr/local/bin, homebrew, npm-global).
- **Router skip-write optimization** — Route generator compares output before writing. If routes are unchanged, the file is not rewritten, preventing unnecessary build_runner rebuild cycles.
- **HttpClient-based update checker** — `duxt update` uses Dart's `HttpClient` instead of shelling out to `curl`. Proper timeout handling and robust semver parsing.
- **Better process lifecycle** — SIGTERM → SIGKILL escalation with 6-second timeout. Handles SIGINT, SIGTERM, and SIGHUP signals. Stale build_runner cleanup on startup.
- **Stream buffering** — stdout/stderr parsing handles partial chunks with separate line buffers, preventing garbled output.

### Fixed
- Fixed potential race condition in dev tools WebSocket broadcast (defensive `.toList()` copy)
- Fixed route regeneration triggering on `.generated/` directory changes
- Improved handling of content and layout file changes in watcher

## [0.5.7] - 2026-02-11

- fix version display in duxt update/version commands

## [0.5.6] - 2026-02-11

### Added
- **Namespace support** — `duxt g module Admin/Post` creates `lib/admin/post/pages/` routing to `/admin/posts`. Namespace layouts auto-wrap all routes in a namespace.
- **Theme namespace** — `lib/theme/` strips prefix from routes: `theme/home` → `/`, `theme/blog` → `/blog`
- **Namespace scaffolding** — `duxt scaffold Admin/Post title:String` generates full CRUD inside a namespace
- **Namespace layout generator** — `duxt g layout Admin` creates `lib/admin/layouts/default.dart`
- **Database configuration docs** — `duxt.config.dart` templates now include documented database config with commented-out examples for MySQL/PostgreSQL on client/static templates

### Changed
- **Dev server: run multiple apps** — each `duxt dev --port=N` gets unique ports for all services including jaspr's internal proxy (`--proxy-port`). Requires jaspr_cli ^0.22.2.
- **DevTools merged into proxy** — WebSocket overlay now runs on the same port as the proxy at `/_duxt/ws` instead of a separate port. One fewer port per dev instance.
- **`duxt build` desktop is optional** — `duxt build` defaults to web, `duxt build desktop` for Tauri. No longer requires a subcommand.
- **Router import aliases** — module names with hyphens (e.g. `duxt-ui`) now produce valid Dart identifiers in generated routes
- **Config templates** — all `duxt.config.dart` templates include a header comment explaining the file's purpose and linking to docs

### Fixed
- Fixed `duxt build` failing when BuildDesktopCommand was registered as a subcommand (args package required subcommand)
- Fixed generated import aliases containing hyphens causing Dart compilation errors
- File watcher now watches `lib/` recursively for namespace support

## [0.5.5] - 2026-02-11

- Add Tauri desktop support: `duxt build desktop`, `duxt create --desktop`, `duxt dev --desktop`
- Bundled squircle icon asset for desktop apps (generates all icon sizes via `cargo tauri icon`)
- Fixed client-mode template to use `runApp(App())` instead of `runApp(const ClientApp())` — fixes blank page in SPA mode
- Changed `<script type="module">` to `<script defer>` in index.html template for DDC compatibility
- Dev server: auto-retry on DevTools port conflict, wait for web assets before launching Tauri window

## [0.5.1] - 2026-02-10

### Changed
- **Simplified templates to 3** — replaced 6 templates (default, minimal, marketing, blog, html, saas) with 3 clean templates matching rendering modes:
  - `static` (SSG) — marketing sites, landing pages, docs. Hero + features + CTA + about page.
  - `server` (SSR) — dynamic apps with blog, Post model, API routes, DuxtORM, Docker.
  - `client` (SPA) — interactive apps with reactive counter, form validation, duxt_signals.
- **All generated code uses duxt_html** — `Div()`, `Text()`, `Button()`, `className:`, `children:` instead of Jaspr's `div()`, `Component.text()`, `classes:`, positional args.
- **Template = mode** — single selection prompt instead of separate template + mode choices. The `--mode` flag is removed; use `--template` (or `-t`) instead.
- **Fixed duxt.config.dart** — each template generates the correct mode (`static`, `server`, `client`) instead of hardcoded `spa`.

### Removed
- Old template files: `minimal.dart`, `marketing.dart`, `html.dart`, `blog.dart`
- `ProjectMode` enum and separate mode selection prompt
- `--mode` CLI flag (template selection now determines the mode)

## [0.5.0] - 2026-02-09

### Added
- **Security middleware suite** - New production-ready middleware for DuxtServer:
  - `securityHeaders()` - X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy
  - `bodyLimit()` - Reject oversized request bodies (default 1 MB)
  - `rateLimit()` - Per-IP rate limiting (default 100 req/min)
  - `timeout()` - Request timeout with 504 response (default 30s)
  - `csrf()` - CSRF token validation on state-changing requests
- **Graceful shutdown** - DuxtServer handles SIGINT/SIGTERM for clean process termination
- **Request timeout** - Configurable `requestTimeout` on DuxtServer with idle connection timeout
- **Built-in error pages** - Styled 404/500 pages for all contexts:
  - `DuxtErrorPage` Jaspr component with Tailwind CSS (SPA router errors)
  - `DuxtErrorHtml` static HTML generator (CLI servers, static hosting)
  - All templates wire `Router(errorBuilder: DuxtErrorPage.routerErrorBuilder)`
  - `duxt build` generates `404.html` for static hosting (Netlify, Vercel, GitHub Pages, Cloudflare)
- **Security documentation** - New `/duxt/security` docs page with production checklist
- **SECURITY.md** - Security policy and vulnerability reporting

### Changed
- **BREAKING: `cors()` now requires explicit `origins` parameter** - No more default `['*']`. You must specify allowed origins explicitly.
- All generated server templates now include `securityHeaders()`, `bodyLimit()`, and explicit CORS origins
- `duxt build` excludes `.env`, `.env.local`, `.env.production`, `.env.development`, `.git`, `node_modules` from output
- Docker image pinned to `dart:3.7` instead of `dart:stable` for reproducible builds
- `pkill` in `duxt dev` scoped to current project directory (no longer kills unrelated processes)

### Fixed
- **Path traversal protection** on `duxt start` and `duxt preview` static file serving (canonicalization + prefix check)
- **Content loader path traversal** in `readPartial()` — validates paths stay within project directory
- **Template injection** in scaffold command — module names, field names, and relation models validated with regex
- **Exception information disclosure** in generated server templates — `e.toString()` replaced with generic messages, full errors logged server-side
- **XSS prevention** in error pages — all reflected paths HTML-escaped and truncated to 500 chars
- **Server fingerprinting** removed "Powered by Duxt" from error page footers
- **Double-slash bug** in DuxtServer 404 path

### Security
- Content-negotiated 404 responses with `Vary: Accept` header (prevents cache poisoning)
- Security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`) on all server responses
- Generic error messages to clients with full error logging server-side

## [0.4.15] - 2026-02-05

### Added
- **Jaspr version check** - CLI now requires Jaspr 0.22.2 or higher and shows helpful update message
- **displayLabel getter** - Scaffold-generated models include `displayLabel` for dropdown display

### Fixed
- **Build always rebuilds** - `duxt build` now always rebuilds frontend instead of skipping if output exists
- **Scaffold boolean handling** - API routes properly handle bool/int/string conversion for checkboxes
- **Scaffold plural routes** - Routes now use correct plural form (e.g., `/categories` not `/categorys`)

## [0.4.10] - 2026-02-05

### Fixed
- **Scaffold creates API server** - When using `--orm`, scaffold now auto-creates `server/main.dart` and `server/db.dart` if missing
- **API routes properly registered** - First scaffold properly registers routes in server/main.dart

## [0.4.9] - 2026-02-05

### Fixed
- **Auto-migration on server start** - Server mode now runs `DuxtOrm.migrate()` automatically to create tables
- **Version display** - Fixed `duxt version` showing stale version

## [0.4.8] - 2026-02-05

### Fixed
- **Server mode now includes ORM initialization** - Projects created with `--mode=server` now have `DuxtOrm.init()` in `main.server.dart`
- **Scaffold properly registers models** - Model registration is added to `main.server.dart` for SSR data fetching

## [0.4.7] - 2026-02-05

### Fixed
- **Browser stuck on "Building..." after build completes** - Fixed race condition where browser connects to WebSocket after build finished. Now sends current state to new clients immediately on connect.
- **Templates missing duxt_orm for server mode** - Minimal and marketing templates now include `duxt_orm` and `sqlite3` when created with `--mode=server`
- **Scaffold auto-adds duxt_orm** - When using `duxt scaffold --orm`, the dependency is automatically added to pubspec.yaml if missing

## [0.4.6] - 2026-02-05

### Fixed
- **Dev server "Building..." stuck** - Browser overlay now correctly shows "Ready!" when first build completes
- Added first-build message explaining 1-2 minute wait time
- Increased build timeout from 120s to 180s for slower machines
- Added suggestion to run with `--verbose` for build progress details

## [0.4.5] - 2026-02-04

### Added
- **DuxtUI form components in scaffold** - Generated forms now use `DInput`, `DSwitch`, `DSelect`, `DCheckboxGroup`
- **Relation dropdowns** - BelongsTo relations generate `DSelect` dropdowns with related model options
- **Many-to-many support** - ToMany relations generate `DCheckboxGroup` for multi-select
- **Relation syntax** - Parse `field:belongsTo:Model` and `field:toMany:Model` in scaffold command
- **Pivot table generation** - Automatically generate pivot tables for many-to-many relations
- **SSR relation loading** - List and detail pages load related models for form dropdowns

### Changed
- Forms include foreign key fields in JavaScript submission
- Detail pages pass selected relation IDs to edit form
- API routes handle foreign key updates

## [0.4.4] - 2026-02-03

### Changed
- **Removed version constraints from templates** - All project templates now use flexible dependency versions
- New projects will always get the latest compatible versions of duxt, duxt_ui, duxt_orm, jaspr, etc.

## [0.4.3] - 2026-02-03

### Changed
- **Scaffold uses duxt_ui DModal** - Modal forms now use the `DModal` component from duxt_ui instead of built-in modal implementation
- Removed `d_modal.dart` from duxt package (use `duxt_ui` instead)
- Cleaner generated code with proper component separation

## [0.4.2] - 2026-02-03

### Added
- **Modal-based CRUD** - Scaffold generates modal forms instead of separate `/new` and `/edit` pages
  - List page has "New" button that opens modal form
  - Detail page has "Edit" button that opens pre-populated modal form
  - Reduced from 4 routes to 2 routes per module (list + detail)
- `DModal` component with HTML `<dialog>` element for accessible modals
- Form data pre-population for edit mode via JavaScript

### Changed
- Scaffold-generated pages use `AsyncStatelessComponent` for SSR data loading
- Forms submit via fetch API with JSON, then refresh page
- Navigation links auto-added to default layout

## [0.4.1] - 2026-02-03

### Added
- **Scaffold relation syntax** - Generate models with relationships
  - `belongsTo:Model` - Creates foreign key and BelongsTo relation
  - `toMany:Model` - Creates pivot table and BelongsToMany relation
  - Example: `duxt scaffold posts category:belongsTo:Category tags:toMany:Tag --orm`
- **New field types** for scaffold command
  - `text` - TEXT column for long content
  - `email` - VARCHAR with email validation in UI
  - `image` - Image upload field (VARCHAR 500)
  - `attachment` - File upload field (VARCHAR 500)
  - `datetime` - DateTime picker
- **`--no-api` flag** - Generate SSR-only models without REST endpoints
- **Tag model template** - Many-to-many relationship support with Posts
- **Interactive blog tutorial** - `/blog` shows step-by-step scaffolding guide
- **`duxt docs` command** - Documentation generation
  - `duxt docs generate` - Generate API docs from code comments
  - `duxt docs page <name>` - Create documentation page
  - `duxt docs tutorial <name>` - Create tutorial with template

### Changed
- Blog template now includes Tag model with BelongsToMany relation
- Post model template includes `attach()`, `detach()`, `sync()` for tags
- Updated blog index to show interactive tutorial by default

## [0.4.0] - 2026-02-02

### Added
- **`--template` flag** for `duxt create` - Choose from multiple project templates
  - `default` - Full-featured demo (existing behavior)
  - `minimal` - Clean starting point with just home page and layout
  - `marketing` - Landing page with hero, features, pricing, testimonials
  - `blog` - Focused blog with DuxtORM backend
  - `saas` - Coming soon (requires duxt_auth)
- Interactive template selection when no `--template` flag provided
- **Blog template now demonstrates DuxtORM relations**
  - Post → Category relationship with `BelongsTo`
  - Category → Posts relationship with `HasMany`
  - Eager loading with `.with_(['category'])` to prevent N+1 queries
  - Category badges displayed on blog post cards

### Changed
- `duxt create` now shows both template and mode selection
- Blog template includes Category model and API
- Posts API now returns category data via eager loading

## [0.3.11] - 2026-01-31

### Changed
- Updated all documentation and examples to use `_id_` syntax instead of `[id]`
- Scaffold command now generates `_id_.dart` files for dynamic routes

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
