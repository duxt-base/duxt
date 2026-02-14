import '../manifest.dart';
import '../plugin.dart';

/// Plugin that detects static (zero-JS) pages.
///
/// A page is static if:
/// - Its component is classified as [ComponentKind.static_]
/// - All of its transitive dependencies are also static
///
/// Static routes get [RenderMode.static_] — the server renders pure HTML
/// with no client JavaScript shipped.
class StaticDetectionPlugin extends DuxtPlugin {
  @override
  String get name => 'static-detection';

  @override
  void processManifest(DuxtManifest manifest) {
    for (final route in manifest.routes) {
      final component = manifest.componentFor(route);
      if (component == null) continue;

      // If the component itself is not static, skip
      if (component.kind != ComponentKind.static_) continue;

      // Check all transitive dependencies
      final deps = manifest.allDependenciesOf(component.name);
      final allStatic = deps.every((d) => d.kind == ComponentKind.static_);

      if (allStatic) {
        route.renderMode = RenderMode.static_;
      }
    }
  }
}
