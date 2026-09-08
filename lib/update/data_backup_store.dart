import 'dart:io';

import '../runtime/runtime_permissions.dart';

class DataBackupStore {
  DataBackupStore({
    required this.backupsDirectory,
    required this.stagingDirectory,
  });

  static const _prefix = 'data-';
  static const _retainedBackups = 3;

  final Directory backupsDirectory;
  final Directory stagingDirectory;

  Future<String> create(Directory dataDirectory) async {
    if (!await dataDirectory.exists()) {
      throw StateError(
        'Backend data directory is missing: ${dataDirectory.path}',
      );
    }
    await Future.wait([
      backupsDirectory.create(recursive: true),
      stagingDirectory.create(recursive: true),
    ]);
    await Future.wait([
      restrictDirectoryToCurrentUser(backupsDirectory),
      restrictDirectoryToCurrentUser(stagingDirectory),
    ]);
    final id = '$_prefix${DateTime.now().microsecondsSinceEpoch}-$pid';
    final staging = Directory.fromUri(stagingDirectory.uri.resolve('$id/'));
    final target = Directory.fromUri(backupsDirectory.uri.resolve('$id/'));
    try {
      await _copyDirectory(dataDirectory, staging);
      await staging.rename(target.path);
      await restrictDirectoryToCurrentUser(target);
      await _prune();
      return id;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<List<String>> list() async {
    if (!await backupsDirectory.exists()) return const <String>[];
    final ids = <String>[];
    await for (final entity in backupsDirectory.list(followLinks: false)) {
      if (entity is Directory) {
        final name = _nameOf(entity.uri);
        if (name.startsWith(_prefix)) ids.add(name);
      }
    }
    ids.sort();
    return ids;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await restrictDirectoryToCurrentUser(destination);
    await for (final entity in source.list(followLinks: false)) {
      final target =
          '${destination.path}${Platform.pathSeparator}${_nameOf(entity.uri)}';
      if (entity is Link) {
        throw StateError(
          'Data backup does not follow symlinks: ${entity.path}',
        );
      }
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(target));
      } else if (entity is File) {
        final copied = await entity.copy(target);
        await restrictFileToCurrentUser(copied);
      } else {
        throw StateError(
          'Data backup found an unsupported entry: ${entity.path}',
        );
      }
    }
  }

  Future<void> _prune() async {
    final ids = await list();
    if (ids.length <= _retainedBackups) return;
    for (final id in ids.take(ids.length - _retainedBackups)) {
      await Directory.fromUri(backupsDirectory.uri.resolve('$id/'))
          .delete(recursive: true);
    }
  }

  String _nameOf(Uri uri) =>
      uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);
}
