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

class HttpMetaResources {
  const HttpMetaResources({
    required this.directory,
    required this.bundle,
    required this.metaDirectory,
    required this.version,
    required this.mihomoVersion,
  });

  final Directory directory;
  final File bundle;
  final Directory metaDirectory;
  final String version;
  final String mihomoVersion;
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

  Future<PackagedComponentVersions> packagedVersions() =>
      PackagedComponentVersions.read(_dataDirectory);

  Future<ComponentResources> resolve() async {
    final packaged = await packagedVersions();
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

  Future<HttpMetaResources> resolveHttpMeta() async {
    final directory = Directory.fromUri(
      _dataDirectory.uri.resolve('http-meta/'),
    );
    final bundle = File.fromUri(directory.uri.resolve('http-meta.bundle.js'));
    final meta = Directory.fromUri(directory.uri.resolve('meta/'));
    final tpl = File.fromUri(meta.uri.resolve('tpl.yaml'));
    final mihomoName = Platform.isWindows ? 'mihomo.exe' : 'mihomo';
    final mihomo = File.fromUri(meta.uri.resolve(mihomoName));
    final version = await _readVersion(
      File.fromUri(directory.uri.resolve('version')),
    );
    final mihomoVersion = await _readVersion(
      File.fromUri(meta.uri.resolve('mihomo-version')),
    );
    for (final file in <File>[bundle, tpl, mihomo]) {
      if (!await file.exists()) {
        throw StateError(
          'Packaged http-meta resource is missing: ${file.path}',
        );
      }
    }
    if (!Platform.isWindows && ((await mihomo.stat()).mode & 0x49) == 0) {
      throw StateError('Packaged mihomo is not executable: ${mihomo.path}');
    }
    return HttpMetaResources(
      directory: directory,
      bundle: bundle,
      metaDirectory: meta,
      version: version,
      mihomoVersion: mihomoVersion,
    );
  }

  Future<String> _readVersion(File file) async {
    if (!await file.exists()) {
      throw StateError('Packaged version marker is missing: ${file.path}');
    }
    final raw = await file.readAsString();
    final value = raw.endsWith('\n') ? raw.substring(0, raw.length - 1) : raw;
    if (value.isEmpty || value.contains('\n') || value.trim() != value) {
      throw StateError('Packaged version marker is invalid: ${file.path}');
    }
    return value;
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
