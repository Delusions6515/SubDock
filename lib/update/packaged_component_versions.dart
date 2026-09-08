import 'dart:io';

class PackagedComponentVersions {
  const PackagedComponentVersions({
    required this.backend,
    required this.frontend,
  });

  final String backend;
  final String frontend;

  static Future<PackagedComponentVersions> read(Directory dataDirectory) async {
    final versions = await Future.wait([
      _readMarker(dataDirectory, 'backend'),
      _readMarker(dataDirectory, 'frontend'),
    ]);
    return PackagedComponentVersions(
      backend: versions[0],
      frontend: versions[1],
    );
  }

  static Future<String> _readMarker(
    Directory dataDirectory,
    String component,
  ) async {
    final file = File.fromUri(dataDirectory.uri.resolve('$component/version'));
    if (!await file.exists()) {
      throw StateError(
        'Packaged $component version marker is missing: ${file.path}',
      );
    }
    final raw = await file.readAsString();
    final lines = raw.split(RegExp(r'\r?\n'));
    if (raw.endsWith('\n')) lines.removeLast();
    if (lines.length != 1 ||
        lines.single.isEmpty ||
        lines.single != lines.single.trim()) {
      throw StateError(
        'Packaged $component version marker is invalid: ${file.path}',
      );
    }
    return lines.single;
  }
}
