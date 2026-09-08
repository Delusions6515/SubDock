import 'dart:convert';
import 'dart:io';

import '../runtime/backend_runtime.dart';
import '../runtime/runtime_directories.dart';
import '../runtime/runtime_permissions.dart';
import 'component_metadata_store.dart';
import 'component_resource_resolver.dart';
import 'component_storage.dart';
import 'data_backup_store.dart';
import 'github_release_client.dart';

/// Applies a Backend release as a recoverable, all-or-nothing transaction.
class BackendComponentUpdater {
  BackendComponentUpdater({
    required this.runtime,
    required this.directories,
    required this.metadataStore,
    required this.resources,
    required this.downloads,
    required this.backups,
  });

  static final _versionPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  final BackendRuntime runtime;
  final RuntimeDirectories directories;
  final ComponentMetadataStore metadataStore;
  final ComponentResourceResolver resources;
  final GithubReleaseDownloader downloads;
  final DataBackupStore backups;

  Future<void> update(GithubRelease release) async {
    final version = _safeVersion(release.version);
    final current = await resources.resolve();
    final prior = await metadataStore.load(
      ComponentKind.backend,
      baseline: current.backendVersion,
    );
    if (prior.active == version) return;

    final staged = Directory.fromUri(
      directories.staging.uri.resolve('backend-$version-$pid/'),
    );
    final candidate = Directory.fromUri(
      directories.components.uri.resolve('backend/$version/'),
    );
    if (await candidate.exists()) {
      throw StateError('Backend component candidate already exists: $version');
    }

    String? backupId;
    var pendingSaved = false;
    var runtimeStopped = false;
    try {
      await staged.create(recursive: true);
      await restrictDirectoryToCurrentUser(staged);
      for (final assetName in const [
        'sub-store.bundle.js',
        'runtime-manifest.json',
      ]) {
        await downloads.downloadVerified(
          release.assetNamed(assetName),
          File.fromUri(staged.uri.resolve(assetName)),
        );
      }
      await _validateManifest(
        File.fromUri(staged.uri.resolve('runtime-manifest.json')),
      );

      await runtime.stop();
      runtimeStopped = true;
      backupId = await backups.create(directories.data);
      await candidate.parent.create(recursive: true);
      await restrictDirectoryToCurrentUser(candidate.parent);
      await staged.rename(candidate.path);
      await restrictDirectoryToCurrentUser(candidate);

      final previous = prior.active ?? prior.baseline;
      await metadataStore.save(
        ComponentKind.backend,
        ComponentMetadata(
          baseline: prior.baseline,
          active: version,
          previous: previous,
          pending: ComponentPending(version: version, backupId: backupId),
        ),
      );
      pendingSaved = true;
      await runtime.restart();
      runtimeStopped = false;
      if (!await runtime.isHealthy()) {
        throw StateError('Updated Backend did not become healthy');
      }
      await metadataStore.save(
        ComponentKind.backend,
        ComponentMetadata(
          baseline: prior.baseline,
          active: version,
          previous: previous,
        ),
      );
      await ComponentStorage(directories.components)
          .retain(ComponentKind.backend, [version, previous]);
    } catch (_) {
      if (pendingSaved) {
        await _rollback(prior, backupId!);
      } else if (runtimeStopped) {
        await runtime.start();
      }
      rethrow;
    } finally {
      if (await staged.exists()) await staged.delete(recursive: true);
    }
  }

  Future<void> _rollback(ComponentMetadata prior, String backupId) async {
    try {
      await backups.restore(backupId, directories.data);
      await metadataStore.save(ComponentKind.backend, prior);
      await runtime.restart();
    } catch (_) {
      // Preserve pending metadata so startup recovery can retry safely.
      rethrow;
    }
  }

  String _safeVersion(String version) {
    if (!_versionPattern.hasMatch(version)) {
      throw ArgumentError.value(version, 'release.version');
    }
    return version;
  }

  Future<void> _validateManifest(File manifest) async {
    final decoded = jsonDecode(await manifest.readAsString());
    if (decoded is! Map ||
        decoded['testedNode'] is! String ||
        decoded['externalBinary'] is! List ||
        (decoded['externalBinary'] as List).any((entry) => entry is! String)) {
      throw const FormatException('Backend runtime manifest is invalid');
    }
  }
}
