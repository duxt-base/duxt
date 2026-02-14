import 'package:test/test.dart';
import 'package:duxt/src/core/error_html.dart';

void main() {
  group('DuxtErrorHtml.notFound', () {
    test('returns valid HTML with 404 status', () {
      final html = DuxtErrorHtml.notFound();
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('404'));
      expect(html, contains('Page Not Found'));
    });

    test('includes path when provided', () {
      final html = DuxtErrorHtml.notFound(path: '/missing/page');
      expect(html, contains('/missing/page'));
    });

    test('escapes HTML in path to prevent XSS', () {
      final html = DuxtErrorHtml.notFound(path: '<script>alert("xss")</script>');
      expect(html, isNot(contains('<script>alert("xss")</script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&quot;'));
    });

    test('truncates very long paths', () {
      final longPath = '/' + 'a' * 600;
      final html = DuxtErrorHtml.notFound(path: longPath);
      // Should be truncated to 500 chars + "..."
      expect(html, contains('...'));
      // Should not contain the full 600-char path
      expect(html, isNot(contains(longPath)));
    });

    test('handles null path', () {
      final html = DuxtErrorHtml.notFound();
      expect(html, contains('404'));
      expect(html, contains('Page Not Found'));
    });

    test('includes Go Home link', () {
      final html = DuxtErrorHtml.notFound();
      expect(html, contains('href="/"'));
      expect(html, contains('Go Home'));
    });

    test('escapes ampersands in path', () {
      final html = DuxtErrorHtml.notFound(path: '/page?a=1&b=2');
      expect(html, contains('&amp;'));
    });

    test('escapes single quotes in path', () {
      final html = DuxtErrorHtml.notFound(path: "/it's-a-page");
      expect(html, contains('&#x27;'));
    });
  });

  group('DuxtErrorHtml.serverError', () {
    test('returns valid HTML with 500 status', () {
      final html = DuxtErrorHtml.serverError();
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('500'));
      expect(html, contains('Internal Server Error'));
    });

    test('includes error description', () {
      final html = DuxtErrorHtml.serverError();
      expect(html, contains('Something went wrong'));
    });

    test('includes Go Home link', () {
      final html = DuxtErrorHtml.serverError();
      expect(html, contains('href="/"'));
    });
  });
}
