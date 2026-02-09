/// Static HTML error pages for CLI commands and servers.
///
/// These are standalone HTML strings with inline styles (no Tailwind dependency)
/// for use in static file servers, preview servers, and build output.
class DuxtErrorHtml {
  const DuxtErrorHtml._();

  /// Maximum path length displayed in error pages to prevent abuse.
  static const int _maxPathLength = 500;

  /// Returns a self-contained HTML string for a 404 Not Found page.
  static String notFound({String? path}) {
    var displayPath = path;
    if (displayPath != null && displayPath.length > _maxPathLength) {
      displayPath = '${displayPath.substring(0, _maxPathLength)}...';
    }
    final escapedPath = displayPath != null ? _escapeHtml(displayPath) : null;
    return _buildPage(
      statusCode: 404,
      title: 'Page Not Found',
      description: 'The page you are looking for does not exist or has been moved.',
      path: escapedPath,
      accentColor: '#06b6d4',
      accentGlow: 'rgba(6, 182, 212, 0.15)',
    );
  }

  /// Returns a self-contained HTML string for a 500 Internal Server Error page.
  static String serverError() {
    return _buildPage(
      statusCode: 500,
      title: 'Internal Server Error',
      description: 'Something went wrong on our end. Please try again later.',
      accentColor: '#ef4444',
      accentGlow: 'rgba(239, 68, 68, 0.15)',
    );
  }

  /// HTML-escape a string to prevent XSS.
  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  static String _buildPage({
    required int statusCode,
    required String title,
    required String description,
    String? path,
    required String accentColor,
    required String accentGlow,
  }) {
    final pathSection = path != null
        ? '<p style="margin-top:1.5rem;padding:0.75rem 1.5rem;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:8px;font-family:monospace;font-size:0.875rem;color:#94a3b8;word-break:break-all;">$path</p>'
        : '';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$statusCode - $title</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: system-ui, -apple-system, sans-serif;
      background: #030712;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #e2e8f0;
    }
    .container {
      text-align: center;
      padding: 2rem;
      max-width: 480px;
    }
    .status-code {
      font-size: 8rem;
      font-weight: 800;
      line-height: 1;
      color: $accentColor;
      text-shadow: 0 0 80px $accentGlow;
      margin-bottom: 1rem;
    }
    h1 {
      font-size: 1.5rem;
      font-weight: 600;
      margin-bottom: 0.75rem;
    }
    .description {
      color: #94a3b8;
      font-size: 1rem;
      line-height: 1.6;
    }
    .home-link {
      display: inline-block;
      margin-top: 2rem;
      padding: 0.75rem 2rem;
      background: $accentColor;
      color: white;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 500;
      font-size: 0.875rem;
      transition: opacity 0.2s;
    }
    .home-link:hover { opacity: 0.85; }
  </style>
</head>
<body>
  <div class="container">
    <div class="status-code">$statusCode</div>
    <h1>$title</h1>
    <p class="description">$description</p>
    $pathSection
    <a href="/" class="home-link">Go Home</a>
  </div>
</body>
</html>''';
  }
}
