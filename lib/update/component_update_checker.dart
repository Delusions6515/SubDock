import 'component_metadata_store.dart';
import 'component_resource_resolver.dart';
import 'github_release_client.dart';

class ComponentUpdate {
  const ComponentUpdate({
    required this.kind,
    required this.currentVersion,
    required this.availableVersion,
    required this.release,
  });

  final ComponentKind kind;
  final String currentVersion;
  final String availableVersion;
  final GithubRelease release;

  bool get isAvailable =>
      _compareVersions(availableVersion, currentVersion) > 0;
}

class ComponentUpdateChecker {
  ComponentUpdateChecker({required this.resources, required this.releases});

  final ComponentResourceResolver resources;
  final GithubReleaseSource releases;

  Future<ComponentUpdate> check(ComponentKind kind) async {
    final current = await resources.resolve();
    final repository = switch (kind) {
      ComponentKind.backend => 'sub-store-org/Sub-Store',
      ComponentKind.frontend => 'sub-store-org/Sub-Store-Front-End',
    };
    final release = await releases.latest(repository);
    for (final name in switch (kind) {
      ComponentKind.backend => const [
        'sub-store.bundle.js',
        'runtime-manifest.json',
      ],
      ComponentKind.frontend => const ['dist.zip'],
    }) {
      release.assetNamed(name);
    }
    return ComponentUpdate(
      kind: kind,
      currentVersion: switch (kind) {
        ComponentKind.backend => current.backendVersion,
        ComponentKind.frontend => current.frontendVersion,
      },
      availableVersion: release.version,
      release: release,
    );
  }
}

int _compareVersions(String first, String second) {
  final firstParts = _versionParts(first);
  final secondParts = _versionParts(second);
  for (var index = 0; index < firstParts.length; index++) {
    final comparison = firstParts[index].compareTo(secondParts[index]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}

List<int> _versionParts(String version) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
  if (match == null) {
    throw StateError('Component version is not semantic: $version');
  }
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}
