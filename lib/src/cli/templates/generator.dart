import 'static_template.dart';
import 'server_template.dart';
import 'client_template.dart';

/// Generates a new Duxt project from templates
class TemplateGenerator {
  static Future<void> generate(
    String projectName,
    String targetDir, {
    String template = 'static',
  }) async {
    final dartName = projectName.replaceAll('-', '_').replaceAll(' ', '_');

    switch (template) {
      case 'server':
        await ServerTemplate.generate(dartName, targetDir);
      case 'client':
        await ClientTemplate.generate(dartName, targetDir);
      default:
        await StaticTemplate.generate(dartName, targetDir);
    }
  }
}
