import 'dart:async';

import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../manifest.dart';
import '../plugin.dart';

/// Phase 1 Builder: Analyzes each .dart file and classifies components.
///
/// For every .dart file in lib/, this builder:
/// 1. Uses the Dart analyzer via BuildStep.resolver to get LibraryElement
/// 2. Finds all classes that extend Jaspr's StatelessComponent or StatefulComponent
/// 3. Classifies each as static / island / interactive / dynamicData
/// 4. Outputs a .duxt.json with the analysis results
///
/// Registered in build.yaml with runs_before: [duxt|manifest]
class AnalyzeBuilder implements Builder {
  final List<DuxtPlugin> plugins;

  AnalyzeBuilder({List<DuxtPlugin>? plugins}) : plugins = plugins ?? [];

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.duxt.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    // Skip generated files
    if (inputId.path.contains('.g.dart') ||
        inputId.path.contains('.duxt.dart') ||
        inputId.path.contains('.freezed.dart') ||
        inputId.path.contains('.generated/')) {
      return;
    }

    // Resolve the library to get full analyzer access
    final LibraryElement library;
    try {
      library = await buildStep.resolver.libraryFor(inputId);
    } catch (_) {
      // Not a valid library (part file, etc.)
      return;
    }

    final analysis = ComponentAnalysis(
      assetPath: inputId.uri.toString(),
    );

    // Find all top-level classes
    for (final unit in library.units) {
      for (final cls in unit.classes) {
        final componentInfo = _classifyComponent(cls, library);
        if (componentInfo != null) {
          analysis.components.add(componentInfo);
        }
      }
    }

    // Skip files with no components
    if (analysis.components.isEmpty) return;

    // Let plugins analyze
    for (final plugin in plugins) {
      await plugin.analyze(analysis);
    }

    // Write output
    final outputId = inputId.changeExtension('.duxt.json');
    await buildStep.writeAsString(outputId, analysis.toJson());
  }

  /// Classify a class as a Jaspr component and determine its kind.
  ComponentInfo? _classifyComponent(ClassElement cls, LibraryElement library) {
    if (cls.isPrivate) return null;

    // Check if this class extends a Jaspr component
    if (!_isComponent(cls)) return null;

    // Collect annotations
    final annotations = <String>{};
    for (final annotation in cls.metadata) {
      final name = annotation.element?.displayName ?? '';
      if (name.isNotEmpty) annotations.add(name);
    }

    // Determine component kind
    final kind = _determineKind(cls, annotations, library);

    // Collect constructor parameters
    final params = <ParamInfo>[];
    final constructor = cls.unnamedConstructor;
    if (constructor != null) {
      for (final param in constructor.parameters) {
        params.add(ParamInfo(
          name: param.name,
          type: param.type.getDisplayString(withNullability: true),
          isRequired: param.isRequired,
          isNamed: param.isNamed,
        ));
      }
    }

    return ComponentInfo(
      name: cls.name,
      import_: library.source.uri.toString(),
      kind: kind,
      params: params,
      annotations: annotations,
      hasState: _hasState(cls),
      hasAsyncData: _hasAsyncData(cls),
      usesBrowserAPIs: _usesBrowserAPIs(library),
    );
  }

  /// Check if a class extends StatelessComponent, StatefulComponent, or similar
  bool _isComponent(ClassElement cls) {
    return _extendsJasprComponent(cls);
  }

  /// Walk the supertype chain looking for Jaspr component base classes
  bool _extendsJasprComponent(ClassElement cls) {
    final componentTypes = {
      'StatelessComponent',
      'StatefulComponent',
      'InheritedComponent',
    };

    InterfaceType? current = cls.supertype;
    while (current != null) {
      final name = current.element.name;
      if (componentTypes.contains(name)) return true;

      // Check if we've reached Object
      if (name == 'Object') break;
      current = current.element.supertype;
    }

    // Also check mixins
    for (final mixin in cls.mixins) {
      if (mixin.element.name.contains('Component')) return true;
    }

    return false;
  }

  /// Determine the ComponentKind based on annotations and class structure
  ComponentKind _determineKind(
    ClassElement cls,
    Set<String> annotations,
    LibraryElement library,
  ) {
    // @island → island boundary
    if (annotations.contains('island')) return ComponentKind.island;

    // @client → interactive (Jaspr's own hydration)
    if (annotations.contains('client')) return ComponentKind.interactive;

    // Has AsyncDataMixin → dynamic data
    if (_hasAsyncData(cls)) return ComponentKind.dynamicData;

    // Has @sync fields or stateful behavior → interactive
    if (_hasState(cls)) return ComponentKind.interactive;
    if (_hasSyncFields(cls)) return ComponentKind.interactive;

    // Uses browser APIs → interactive
    if (_usesBrowserAPIs(library)) return ComponentKind.interactive;

    // Default: static (no client JS needed)
    return ComponentKind.static_;
  }

  /// Check if the component has stateful behavior
  bool _hasState(ClassElement cls) {
    // StatefulComponent subclasses are inherently stateful
    InterfaceType? current = cls.supertype;
    while (current != null) {
      if (current.element.name == 'StatefulComponent') return true;
      if (current.element.name == 'Object') break;
      current = current.element.supertype;
    }
    return false;
  }

  /// Check for AsyncDataMixin
  bool _hasAsyncData(ClassElement cls) {
    for (final mixin in cls.mixins) {
      if (mixin.element.name == 'AsyncDataMixin') return true;
    }
    return false;
  }

  /// Check for @sync annotated fields
  bool _hasSyncFields(ClassElement cls) {
    for (final field in cls.fields) {
      for (final annotation in field.metadata) {
        if (annotation.element?.displayName == 'sync') return true;
      }
    }
    return false;
  }

  /// Check if the library imports browser-only APIs
  bool _usesBrowserAPIs(LibraryElement library) {
    final browserPackages = {'dart:html', 'dart:js', 'package:web/'};

    for (final import in library.libraryImports) {
      final uri = import.importedLibrary?.source.uri.toString() ?? '';
      if (browserPackages.any((pkg) => uri.startsWith(pkg))) return true;
    }

    return false;
  }
}
