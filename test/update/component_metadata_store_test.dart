import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/update/component_metadata_store.dart';

void main() {
  test('returns the packaged baseline before a component is updated', () async {
    final temp = await Directory.systemTemp.createTemp('sub_dock_component_');
    addTearDown(() => temp.delete(recursive: true));
    final store = ComponentMetadataStore(temp);

    final metadata = await store.load(
      ComponentKind.backend,
      baseline: '2.38.4',
    );

    expect(metadata.baseline, '2.38.4');
    expect(metadata.active, isNull);
    expect(metadata.previous, isNull);
    expect(metadata.pending, isNull);
  });

  test('atomically persists rollback and pending recovery metadata', () async {
    final temp = await Directory.systemTemp.createTemp('sub_dock_component_');
    addTearDown(() => temp.delete(recursive: true));
    final store = ComponentMetadataStore(temp);
    const metadata = ComponentMetadata(
      baseline: '2.38.4',
      active: '2.39.0',
      previous: '2.38.4',
      pending: ComponentPending(version: '2.39.0', backupId: 'before-2390'),
    );

    await store.save(ComponentKind.backend, metadata);
    final restored = await store.load(
      ComponentKind.backend,
      baseline: 'ignored-when-persisted',
    );

    expect(restored, metadata);
    expect(await File('${temp.path}/backend.json').exists(), isTrue);
    expect(
      await temp.list().where((entity) => entity.path.endsWith('.tmp')).isEmpty,
      isTrue,
    );
    if (!Platform.isWindows) {
      expect(
        (await File('${temp.path}/backend.json').stat()).mode & 0x1ff,
        0x180,
      );
    }
  });
}
