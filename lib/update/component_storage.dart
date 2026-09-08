import 'dart:io';

import 'component_metadata_store.dart';

/// Owns cleanup of downloaded component directories under Application Support.
class ComponentStorage {
  ComponentStorage(this._componentsDirectory);

  static final _versionPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  final Directory _componentsDirectory;

  Future<void> retain(ComponentKind kind, Iterable<String?> versions) async {
    final retained = versions.whereType<String>().toSet();
    if (retained.any((version) => !_versionPattern.hasMatch(version))) {
      throw ArgumentError.value(versions, 'versions');
    }
    final directory = Directory.fromUri(
      _componentsDirectory.uri.resolve('${kind.name}/'),
    );
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      final name = _nameOf(entity.uri);
      if (!_versionPattern.hasMatch(name) || retained.contains(name)) continue;
      if (entity is! Directory) {
        throw StateError(
          'Component storage contains an unexpected entry: ${entity.path}',
        );
      }
      await entity.delete(recursive: true);
    }
  }

  String _nameOf(Uri uri) =>
      uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);
}
