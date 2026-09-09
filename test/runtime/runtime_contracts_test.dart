import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/runtime/backend_runtime.dart';
import 'package:subdock/runtime/runtime_directories.dart';

void main() {
  test('runtime state retains status and diagnostics', () {
    final changedAt = DateTime.utc(2026, 9, 6);
    final state = RuntimeState(
      status: RuntimeStatus.crashed,
      changedAt: changedAt,
      message: 'Backend exited with code 1',
    );

    expect(state.status, RuntimeStatus.crashed);
    expect(state.changedAt, changedAt);
    expect(state.message, 'Backend exited with code 1');
  });

  test('runtime directories keep writable state separate', () async {
    final temp = await Directory.systemTemp.createTemp('subdock_test_');
    addTearDown(() => temp.delete(recursive: true));

    final directories = await RuntimeDirectories.fromBaseDirectory(temp);

    expect(await directories.data.exists(), isTrue);
    expect(await directories.logs.exists(), isTrue);
    expect(await directories.backups.exists(), isTrue);
    expect(await directories.config.exists(), isTrue);
    expect(await directories.components.exists(), isTrue);
    expect(await directories.staging.exists(), isTrue);
    expect({
      directories.data.path,
      directories.logs.path,
      directories.backups.path,
      directories.config.path,
      directories.components.path,
      directories.staging.path,
    }, hasLength(6));
    if (!Platform.isWindows) {
      for (final directory in [
        directories.data,
        directories.logs,
        directories.backups,
        directories.config,
        directories.components,
        directories.staging,
      ]) {
        expect((await directory.stat()).mode & 0x1ff, 0x1c0);
      }
    }
  });
}
