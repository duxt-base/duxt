import 'dart:io';
import 'package:path/path.dart' as p;
import 'error_html.dart';

/// Shared static file server used by `duxt start` and `duxt preview`.
///
/// Serves pre-built files from a directory with SPA routing fallback,
/// security headers, path traversal protection, and correct MIME types.
class StaticFileServer {
  final String buildDir;

  const StaticFileServer(this.buildDir);

  /// Handle an incoming HTTP request by serving static files.
  Future<void> handleRequest(HttpRequest request) async {
    // Security headers on all responses
    request.response.headers
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('X-Frame-Options', 'DENY');

    var path = request.uri.path;

    // Default to index.html
    if (path == '/' || path.isEmpty) {
      path = '/index.html';
    }

    // Try to serve the file
    var file = File('$buildDir$path');

    // Path traversal protection: verify resolved path stays within buildDir
    if (!_isWithinDir(file)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType.html
        ..write(DuxtErrorHtml.notFound(path: request.uri.path));
      await request.response.close();
      return;
    }

    // If file doesn't exist and doesn't have extension, try .html
    if (!file.existsSync() && !path.contains('.')) {
      file = File('$buildDir$path.html');
    }

    // Try index.html in subdirectory
    if (!file.existsSync() && !path.endsWith('.html')) {
      file = File('$buildDir$path/index.html');
    }

    // For SPA routing, serve index.html for non-file routes
    if (!file.existsSync()) {
      file = File('$buildDir/index.html');
    }

    if (file.existsSync()) {
      final contentType = getContentType(file.path);
      request.response
        ..headers.contentType = contentType
        ..add(await file.readAsBytes());
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.html
        ..write(DuxtErrorHtml.notFound(path: request.uri.path));
    }

    await request.response.close();
  }

  /// Verify that a file path resolves to within the build directory.
  bool _isWithinDir(File file) {
    final canonicalDir = p.canonicalize(buildDir);
    final canonicalFile = p.canonicalize(file.path);
    return canonicalFile.startsWith(canonicalDir);
  }

  /// Get the content type for a file based on its extension.
  static ContentType getContentType(String path) {
    final ext = p.extension(path).toLowerCase();
    return _mimeTypes[ext] ?? ContentType.binary;
  }

  static final _mimeTypes = {
    '.html': ContentType.html,
    '.css': ContentType('text', 'css'),
    '.js': ContentType('application', 'javascript'),
    '.json': ContentType.json,
    '.png': ContentType('image', 'png'),
    '.jpg': ContentType('image', 'jpeg'),
    '.jpeg': ContentType('image', 'jpeg'),
    '.gif': ContentType('image', 'gif'),
    '.svg': ContentType('image', 'svg+xml'),
    '.webp': ContentType('image', 'webp'),
    '.woff': ContentType('font', 'woff'),
    '.woff2': ContentType('font', 'woff2'),
    '.ttf': ContentType('font', 'ttf'),
    '.ico': ContentType('image', 'x-icon'),
  };
}
