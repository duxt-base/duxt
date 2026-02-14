/// Duxt v2 Compiler — compile-time optimization layer
///
/// Provides a plugin-based build pipeline that analyzes Dart source code
/// and generates optimized output:
/// - Static page detection (zero JS)
/// - Island hydration boundaries
/// - Route-level code splitting
/// - SSR data injection
library;

export 'manifest.dart';
export 'plugin.dart';
export 'plugins/static_detection.dart';
export 'phases/analyze_builder.dart';
export 'phases/manifest_builder.dart';
export 'duxt_builder.dart';
