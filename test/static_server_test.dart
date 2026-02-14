import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:duxt/src/core/static_server.dart';

void main() {
  group('StaticFileServer.getContentType', () {
    test('returns correct type for common extensions', () {
      expect(StaticFileServer.getContentType('style.css').mimeType, 'text/css');
      expect(StaticFileServer.getContentType('app.js').mimeType, 'application/javascript');
      expect(StaticFileServer.getContentType('index.html').mimeType, 'text/html');
      expect(StaticFileServer.getContentType('data.json').mimeType, 'application/json');
      expect(StaticFileServer.getContentType('logo.png').mimeType, 'image/png');
      expect(StaticFileServer.getContentType('photo.jpg').mimeType, 'image/jpeg');
      expect(StaticFileServer.getContentType('photo.jpeg').mimeType, 'image/jpeg');
      expect(StaticFileServer.getContentType('icon.svg').mimeType, 'image/svg+xml');
      expect(StaticFileServer.getContentType('image.webp').mimeType, 'image/webp');
      expect(StaticFileServer.getContentType('font.woff').mimeType, 'font/woff');
      expect(StaticFileServer.getContentType('font.woff2').mimeType, 'font/woff2');
      expect(StaticFileServer.getContentType('font.ttf').mimeType, 'font/ttf');
      expect(StaticFileServer.getContentType('favicon.ico').mimeType, 'image/x-icon');
      expect(StaticFileServer.getContentType('anim.gif').mimeType, 'image/gif');
    });

    test('returns binary for unknown extensions', () {
      expect(StaticFileServer.getContentType('file.xyz').mimeType, 'application/octet-stream');
      expect(StaticFileServer.getContentType('archive.tar').mimeType, 'application/octet-stream');
    });

    test('is case-insensitive for extensions', () {
      expect(StaticFileServer.getContentType('style.CSS').mimeType, 'text/css');
      expect(StaticFileServer.getContentType('app.JS').mimeType, 'application/javascript');
    });
  });

  group('StaticFileServer.handleRequest', () {
    late Directory tempDir;
    late StaticFileServer server;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duxt_static_test_');
      server = StaticFileServer(tempDir.path);

      // Create test files
      File(p.join(tempDir.path, 'index.html')).writeAsStringSync('<html>home</html>');
      File(p.join(tempDir.path, 'about.html')).writeAsStringSync('<html>about</html>');
      Directory(p.join(tempDir.path, 'blog')).createSync();
      File(p.join(tempDir.path, 'blog', 'index.html')).writeAsStringSync('<html>blog</html>');
      File(p.join(tempDir.path, 'style.css')).writeAsStringSync('body{}');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('serves index.html for root path', () async {
      final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen((req) => server.handleRequest(req));

      final client = HttpClient();
      final request = await client.get('localhost', httpServer.port, '/');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, 200);
      expect(body, '<html>home</html>');

      client.close();
      await httpServer.close();
    });

    test('serves subdirectory index.html', () async {
      final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen((req) => server.handleRequest(req));

      final client = HttpClient();
      final request = await client.get('localhost', httpServer.port, '/blog');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, 200);
      expect(body, '<html>blog</html>');

      client.close();
      await httpServer.close();
    });

    test('falls back to index.html for SPA routes', () async {
      final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen((req) => server.handleRequest(req));

      final client = HttpClient();
      final request = await client.get('localhost', httpServer.port, '/nonexistent/page');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, 200);
      expect(body, '<html>home</html>');

      client.close();
      await httpServer.close();
    });

    test('sets security headers', () async {
      final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen((req) => server.handleRequest(req));

      final client = HttpClient();
      final request = await client.get('localhost', httpServer.port, '/');
      final response = await request.close();
      await response.drain<void>();

      expect(response.headers.value('X-Content-Type-Options'), 'nosniff');
      expect(response.headers.value('X-Frame-Options'), 'DENY');

      client.close();
      await httpServer.close();
    });

    test('serves files with correct content type', () async {
      final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen((req) => server.handleRequest(req));

      final client = HttpClient();
      final request = await client.get('localhost', httpServer.port, '/style.css');
      final response = await request.close();
      await response.drain<void>();

      expect(response.headers.contentType?.mimeType, 'text/css');

      client.close();
      await httpServer.close();
    });
  });
}
