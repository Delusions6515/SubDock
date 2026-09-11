import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/runtime/runtime_directories.dart';
import 'package:subdock/settings/theme_mode_store.dart';

void main() {
  test('load returns null when no file exists', () async {
    final temp = await Directory.systemTemp.createTemp(
      'theme_mode_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);

    expect(await ThemeModeStore(directories).load(), isNull);
  });

  test('save then load round-trips the mode', () async {
    final temp = await Directory.systemTemp.createTemp(
      'theme_mode_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = ThemeModeStore(directories);

    await store.save(ThemeMode.system);
    expect(await store.load(), ThemeMode.system);

    await store.save(ThemeMode.light);
    expect(await store.load(), ThemeMode.light);

    await store.save(ThemeMode.dark);
    expect(await store.load(), ThemeMode.dark);
  });

  test('save writes private file permissions', () async {
    final temp = await Directory.systemTemp.createTemp(
      'theme_mode_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = ThemeModeStore(directories);

    await store.save(ThemeMode.dark);

    if (!Platform.isWindows) {
      expect((await store.file.stat()).mode & 0x1ff, 0x180);
    }
  });

  test('corrupt JSON degrades to null instead of throwing', () async {
    final temp = await Directory.systemTemp.createTemp(
      'theme_mode_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = ThemeModeStore(directories);
    await store.file.writeAsString('{not json');

    expect(await store.load(), isNull);
  });

  test('unknown string value degrades to null', () async {
    final temp = await Directory.systemTemp.createTemp(
      'theme_mode_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = ThemeModeStore(directories);
    await store.file.writeAsString('"blue"');

    expect(await store.load(), isNull);
  });
}
