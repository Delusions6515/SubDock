import 'dart:io';

import 'component_metadata_store.dart';
import 'packaged_component_versions.dart';

class ComponentResources {
  const ComponentResources({
    required this.backend,
    required this.frontend,
    required this.backendVersion,
    required this.frontendVersion,
  });

  final Directory backend;
  final Directory frontend;
  final String backendVersion;
  final String frontendVersion;
}

class ComponentResourceResolver {
  ComponentResourceResolver({
    required Directory bundleDirectory,
    required this.componentsDirectory,
    required this.metadataStore,
  }) : _dataDirectory = Directory.fromUri(bundleDirectory.uri.resolve('data/'));

  static final _versionPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  final Directory _dataDirectory;
  final Directory componentsDirectory;
  final ComponentMetadataStore metadataStore;

  Future<ComponentResources> resolve() async {
    final packaged = await PackagedComponentVersions.read(_dataDirectory);
    final metadata = await Future.wait([
      metadataStore.load(ComponentKind.backend, baseline: packaged.backend),
      metadataStore.load(ComponentKind.frontend, baseline: packaged.frontend),
    ]);
    final backend = await _resolveDirectory(
      ComponentKind.backend,
      metadata[0],
      Directory.fromUri(_dataDirectory.uri.resolve('backend/')),
    );
    final frontend = await _resolveDirectory(
      ComponentKind.frontend,
      metadata[1],
      Directory.fromUri(_dataDirectory.uri.resolve('frontend/')),
    );
    return ComponentResources(
      backend: backend,
      frontend: frontend,
      backendVersion: metadata[0].active ?? packaged.backend,
      frontendVersion: metadata[1].active ?? packaged.frontend,
    );
  }

  Future<Directory> _resolveDirectory(
    ComponentKind kind,
    ComponentMetadata metadata,
    Directory packaged,
  ) async {
    final active = metadata.active;
    if (active == null) {
      return _requireFiles(kind, packaged);
    }
    if (!_versionPattern.hasMatch(active)) {
      throw StateError('Active ${kind.name} version is invalid: $active');
    }
    return _requireFiles(
      kind,
      Directory.fromUri(
        componentsDirectory.uri.resolve('${kind.name}/$active/'),
      ),
    );
  }

  Future<Directory> _requireFiles(
    ComponentKind kind,
    Directory directory,
  ) async {
    final requiredFiles = switch (kind) {
      ComponentKind.backend => const [
        'sub-store.bundle.js',
        'runtime-manifest.json',
      ],
      ComponentKind.frontend => const ['index.html'],
    };
    for (final name in requiredFiles) {
      if (!await File.fromUri(directory.uri.resolve(name)).exists()) {
        throw StateError(
          'Active ${kind.name} component is incomplete: ${directory.path}',
        );
      }
    }
    return directory;
  }
}
