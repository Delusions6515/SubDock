import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/runtime/backend_runtime.dart';
import 'package:sub_dock/runtime/runtime_directories.dart';

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
    final temp = await Directory.systemTemp.createTemp('sub_dock_test_');
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
  });
}
