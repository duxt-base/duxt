# Security Policy

## Built-in Protections

Duxt includes the following security features out of the box:

- **Path traversal protection** on static file serving
- **HTML-escaped error pages** (XSS-safe)
- **Parameterized SQL queries** in DuxtOrm
- **SQL identifier sanitization** in all database adapters
- **Input validation** on CLI commands (scaffold, create)
- **Sensitive file exclusion** during build (`.env` files never copied to output)
- **Generic error messages** to clients (full details logged server-side only)

## Security Middleware

Available via `import 'package:duxt/server.dart'`:

| Middleware | Purpose |
|-----------|---------|
| `securityHeaders()` | X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy |
| `bodyLimit()` | Reject oversized request bodies (default 1 MB) |
| `rateLimit()` | Per-IP rate limiting (default 100 req/min) |
| `cors(origins: [...])` | CORS with explicit origin allowlist |
| `auth(verify)` | Custom authentication verification |
| `csrf()` | CSRF token validation on state-changing requests |
| `timeout()` | Request timeout (default 30s) |

## Production Recommendations

1. Always use `securityHeaders()`, `bodyLimit()`, and `rateLimit()` middleware
2. Set explicit CORS origins (never `['*']` for authenticated endpoints)
3. Use HTTPS via a reverse proxy (nginx, Caddy, Cloudflare)
4. Add authentication to API endpoints that modify data
5. Sanitize user-submitted markdown content before storing
6. Keep `.env` files out of version control

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly:

- Email: security@duxt.dev
- Do not open a public GitHub issue for security vulnerabilities
- We will acknowledge receipt within 48 hours
- We aim to release patches within 7 days of confirmed vulnerabilities
