# Changelog

All notable changes to this project will be documented in this file.

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
  - `duxt scaffold` - Rails-like full CRUD generation

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
  - `defineEventHandler` - Nuxt-style event handler
  - Helper functions: `readBody`, `getQuery`, `sendRedirect`, etc.

- **Integrations**
  - Jaspr ^0.22.1
  - Jaspr Router ^0.8.1
  - Tailwind CSS via jaspr_tailwind
