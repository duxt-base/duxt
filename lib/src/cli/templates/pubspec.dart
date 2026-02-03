/// Pubspec.yaml template
String pubspecTemplate(String projectName, {String mode = 'static'}) => '''
name: $projectName
description: A Duxt project
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  jaspr:
  jaspr_router:
  duxt:
  duxt_ui:
  duxt_orm:
  sqlite3:

dev_dependencies:
  build_runner:
  build_web_compilers:
  jaspr_builder:
  lints:

jaspr:
  mode: $mode
''';

/// duxt.config.dart template
String configTemplate(String projectName) => '''
/// Duxt configuration
class DuxtConfig {
  static const app = (
    name: '$projectName',
    description: 'A Duxt application',
  );

  /// Rendering mode: 'spa', 'ssr', 'static'
  static const String mode = 'spa';

  /// API base URL
  static const String apiBase = '/api';

  /// Development server port
  static const int port = 3000;

  /// Database configuration
  static const database = (
    driver: String.fromEnvironment('DB_DRIVER', defaultValue: 'sqlite'),
    host: String.fromEnvironment('DB_HOST', defaultValue: 'localhost'),
    port: int.fromEnvironment('DB_PORT', defaultValue: 5432),
    database: String.fromEnvironment('DB_NAME', defaultValue: '$projectName'),
    username: String.fromEnvironment('DB_USER', defaultValue: ''),
    password: String.fromEnvironment('DB_PASS', defaultValue: ''),
    path: String.fromEnvironment('DB_PATH', defaultValue: 'data/$projectName.db'),
    ssl: bool.fromEnvironment('DB_SSL', defaultValue: false),
  );
}
''';

/// build.yaml template for client mode entry point
const buildYamlTemplate = '''
targets:
  \$default:
    builders:
      build_web_compilers:entrypoint:
        generate_for:
          - web/main.client.dart
''';

/// .gitignore template
const gitignoreTemplate = '''
# Dart/Flutter
.dart_tool/
.packages
build/
pubspec.lock

# Duxt
.duxt/

# IDE
.idea/
*.iml
.vscode/

# Database
*.db
*.db-journal

# OS
.DS_Store
Thumbs.db

# Generated
*.g.dart
*.freezed.dart
''';
