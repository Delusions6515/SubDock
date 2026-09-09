import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/update/packaged_component_versions.dart';

void main() {
  test(
    'reads the Backend and Frontend versions recorded in the package',
    () async {
      final temp = await Directory.systemTemp.createTemp('subdock_versions_');
      addTearDown(() => temp.delete(recursive: true));
      await _write(temp, 'backend/version', '2.38.4\n');
      await _write(temp, 'frontend/version', '2.31.3\n');

      final versions = await PackagedComponentVersions.read(temp);

      expect(versions.backend, '2.38.4');
      expect(versions.frontend, '2.31.3');
    },
  );

  test('rejects a missing or multiline component version marker', () async {
    final temp = await Directory.systemTemp.createTemp('subdock_versions_');
    addTearDown(() => temp.delete(recursive: true));
    await _write(temp, 'backend/version', '2.38.4\nextra');
    await _write(temp, 'frontend/version', '2.31.3');

    await expectLater(PackagedComponentVersions.read(temp), throwsStateError);
  });
}

Future<void> _write(Directory root, String path, String value) async {
  final file = File.fromUri(root.uri.resolve(path));
  await file.parent.create(recursive: true);
  await file.writeAsString(value);
}
