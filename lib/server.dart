/// Duxt Server - Shelf-based HTTP server utilities
///
/// Import this for server-side API routes:
/// ```dart
/// import 'package:duxt/server.dart';
///
/// void main() async {
///   final server = DuxtServer(port: 3000);
///
///   server.get('/api/hello', (req) => json({'message': 'Hello!'}));
///
///   server.get('/api/users/:id', (req) {
///     final id = req.param('id');
///     return json({'id': id});
///   });
///
///   await server.start();
/// }
/// ```
library duxt.server;

export 'src/server/api_handler.dart';
export 'src/server/duxt_server.dart';
