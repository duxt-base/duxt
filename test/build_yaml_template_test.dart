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

    test('scopes entrypoint builder', () {
      expect(buildYamlTemplate, contains('build_web_compilers|entrypoint'));
      expect(buildYamlTemplate, contains('web/main.client.dart'));
      expect(buildYamlTemplate, contains('lib/main.client.dart'));
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
}
