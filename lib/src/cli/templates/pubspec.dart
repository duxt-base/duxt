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
/// Duxt application configuration.
///
/// Central config file for your Duxt project. All application settings
/// live here: app metadata, rendering mode, API base, server port, and
/// database connection. Values use String.fromEnvironment so you can
/// set defaults for development and override via environment variables
/// in production.
///
/// Usage: import this file and access DuxtConfig.* anywhere in your app.
/// Docs: https://duxt.dev/duxt/configuration
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

  /// Database configuration — passed to DuxtOrm.init(DuxtConfig.database).
  /// Defaults to SQLite. Set environment variables to switch:
  ///
  /// MySQL:
  ///   DB_DRIVER=mysql DB_HOST=localhost DB_PORT=3306 DB_NAME=$projectName DB_USER=root DB_PASS=secret duxt dev
  ///
  /// PostgreSQL:
  ///   DB_DRIVER=postgres DB_HOST=localhost DB_PORT=5432 DB_NAME=$projectName DB_USER=postgres DB_PASS=secret duxt dev
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

/// Optimized build.yaml template
/// - Scopes all jaspr_builder modules to lib/ only (excludes server/, test/)
/// - Limits entrypoint builder to web/main.client.dart
const buildYamlTemplate = '''
targets:
  \$default:
    builders:
      # Scope Jaspr module builders to lib/ only — the heavy ones (3000+ inputs → ~100)
      jaspr_builder|codec_module:
        generate_for:
          include:
            - lib/**/*.dart
          exclude:
            - lib/.generated/**
      jaspr_builder|styles_module:
        generate_for:
          include:
            - lib/**/*.dart
          exclude:
            - lib/.generated/**
      jaspr_builder|client_module:
        generate_for:
          include:
            - lib/**/*.dart
          exclude:
            - lib/.generated/**
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
src-tauri/target/

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
