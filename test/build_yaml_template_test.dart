import 'package:test/test.dart';
import 'package:duxt/src/cli/templates/pubspec.dart';

void main() {
  group('buildYamlTemplate', () {
    test('scopes jaspr_builder module builders to lib/ only', () {
      expect(buildYamlTemplate, contains('jaspr_builder|codec_module'));
      expect(buildYamlTemplate, contains('jaspr_builder|styles_module'));
      expect(buildYamlTemplate, contains('jaspr_builder|client_module'));
      expect(buildYamlTemplate, contains('lib/**/*.dart'));
    });

    test('excludes generated files from jaspr_builder', () {
      expect(buildYamlTemplate, contains('lib/.generated/**'));
    });

    test('does not restrict entrypoint builder', () {
      expect(buildYamlTemplate, isNot(contains('build_web_compilers|entrypoint')));
    });
  });

  group('pubspecTemplate', () {
    test('generates valid pubspec with project name', () {
      final result = pubspecTemplate('my_app');
      expect(result, contains('name: my_app'));
      expect(result, contains('jaspr:'));
      expect(result, contains('duxt:'));
    });

    test('uses provided mode', () {
      final result = pubspecTemplate('my_app', mode: 'server');
      expect(result, contains('mode: server'));
    });

    test('defaults to static mode', () {
      final result = pubspecTemplate('my_app');
      expect(result, contains('mode: static'));
    });
  });

  group('configTemplate', () {
    test('generates config with project name', () {
      final result = configTemplate('my_app');
      expect(result, contains("name: 'my_app'"));
      expect(result, contains('DuxtConfig'));
    });
  });

  group('client JS script tag stripping', () {
    // The regex used in dev_command.dart to strip Jaspr's client JS script
    // tag from SSR HTML responses (DDC dev mode uses modules, not standalone JS)
    final clientJsPattern = RegExp(
      r'<script[^>]+src="[^"]*\.client\.dart\.js"[^>]*>\s*</script>',
    );

    test('strips deferred client JS script tag', () {
      const html = '<head><script defer src="/main.client.dart.js"></script></head>';
      final result = html.replaceAll(clientJsPattern, '');
      expect(result, equals('<head></head>'));
    });

    test('strips client JS script tag without defer', () {
      const html = '<head><script src="/main.client.dart.js"></script></head>';
      final result = html.replaceAll(clientJsPattern, '');
      expect(result, equals('<head></head>'));
    });

    test('does not strip non-client JS script tags', () {
      const html = '<head><script src="/other.js"></script></head>';
      final result = html.replaceAll(clientJsPattern, '');
      expect(result, equals(html));
    });

    test('does not strip inline scripts', () {
      const html = '<head><script>console.log("hello")</script></head>';
      final result = html.replaceAll(clientJsPattern, '');
      expect(result, equals(html));
    });
  });
}
