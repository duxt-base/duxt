/// Duxt configuration
class DuxtConfig {
  static const app = (
    name: 'test_desktop',
    description: 'A Duxt application',
  );

  /// Rendering mode: 'static', 'server', 'client'
  static const String mode = 'client';

  /// API base URL
  static const String apiBase = '/api';

  /// Development server port
  static const int port = 3000;
}
