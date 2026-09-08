import 'dart:convert';
import 'dart:io';

import '../runtime/runtime_permissions.dart';

enum ComponentKind { backend, frontend }

class ComponentPending {
  const ComponentPending({required this.version, this.backupId});

  final String version;
  final String? backupId;

  Map<String, String> toJson() => {'version': version, 'backupId': ?backupId};

  factory ComponentPending.fromJson(Object? value) {
    if (value is! Map ||
        value['version'] is! String ||
        (value['backupId'] != null && value['backupId'] is! String)) {
      throw const FormatException('组件 pending 元数据无效');
    }
    return ComponentPending(
      version: value['version'] as String,
      backupId: value['backupId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComponentPending &&
      other.version == version &&
      other.backupId == backupId;

  @override
  int get hashCode => Object.hash(version, backupId);
}

class ComponentMetadata {
  const ComponentMetadata({
    required this.baseline,
    this.active,
    this.previous,
    this.pending,
  });

  final String baseline;
  final String? active;
  final String? previous;
  final ComponentPending? pending;

  Map<String, Object> toJson() => {
    'baseline': baseline,
    'active': ?active,
    'previous': ?previous,
    'pending': ?pending?.toJson(),
  };

  factory ComponentMetadata.fromJson(Object? value) {
    if (value is! Map ||
        value['baseline'] is! String ||
        (value['active'] != null && value['active'] is! String) ||
        (value['previous'] != null && value['previous'] is! String)) {
      throw const FormatException('组件元数据无效');
    }
    return ComponentMetadata(
      baseline: value['baseline'] as String,
      active: value['active'] as String?,
      previous: value['previous'] as String?,
      pending: value['pending'] == null
          ? null
          : ComponentPending.fromJson(value['pending']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComponentMetadata &&
      other.baseline == baseline &&
      other.active == active &&
      other.previous == previous &&
      other.pending == pending;

  @override
  int get hashCode => Object.hash(baseline, active, previous, pending);
}

class ComponentMetadataStore {
  ComponentMetadataStore(this._directory);

  final Directory _directory;

  Future<ComponentMetadata> load(
    ComponentKind kind, {
    required String baseline,
  }) async {
    final file = _fileFor(kind);
    if (!await file.exists()) return ComponentMetadata(baseline: baseline);
    return ComponentMetadata.fromJson(jsonDecode(await file.readAsString()));
  }

  Future<void> save(ComponentKind kind, ComponentMetadata metadata) async {
    await _directory.create(recursive: true);
    await restrictDirectoryToCurrentUser(_directory);
    final target = _fileFor(kind);
    final temporary = File(
      '${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(jsonEncode(metadata.toJson()), flush: true);
      await restrictFileToCurrentUser(temporary);
      await temporary.rename(target.path);
      await restrictFileToCurrentUser(target);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  File _fileFor(ComponentKind kind) =>
      File('${_directory.path}/${kind.name}.json');
}
