/// Pubspec.yaml template
String pubspecTemplate(String projectName, {String mode = 'static'}) => '''
name: $projectName
description: A Duxt project
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  jaspr: ^0.22.1
  jaspr_router: ^0.8.1
  duxt: ^0.4.0
  duxt_ui: ^0.2.3
  duxt_orm: ^0.1.0
  sqlite3: ^2.4.0

dev_dependencies:
  build_runner: ^2.4.0
  build_web_compilers: ^4.4.8
  jaspr_builder: ^0.22.1
  lints: ^4.0.0

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
