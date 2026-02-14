import 'package:build/build.dart';

import 'phases/analyze_builder.dart';
import 'phases/manifest_builder.dart';
import 'plugins/static_detection.dart';

/// Default plugins shipped with Duxt v2
final _defaultPlugins = [
  StaticDetectionPlugin(),
];

/// Phase 1: Per-file component analysis via Dart analyzer.
/// Outputs .duxt.json for each .dart file containing components.
Builder buildAnalyzer(BuilderOptions options) =>
    AnalyzeBuilder(plugins: _defaultPlugins);

/// Phase 2: Aggregate all analyses into a project manifest.
/// Outputs lib/.duxt/manifest.json with full project analysis.
Builder buildManifest(BuilderOptions options) =>
    ManifestBuilder(plugins: _defaultPlugins);
