/// Base class for Duxt layouts
///
/// Similar to Rails's layout system
abstract class DuxtLayout {
  /// The default slot where page content is rendered
  /// In Jaspr, this will be the child component
}

/// Mixin for layouts that need to provide data to children
mixin LayoutDataMixin {
  /// Data that will be available to all pages using this layout
  Map<String, dynamic> get layoutData => {};
}
