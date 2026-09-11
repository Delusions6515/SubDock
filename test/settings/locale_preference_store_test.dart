import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/runtime/runtime_directories.dart';
import 'package:subdock/settings/locale_preference_store.dart';

void main() {
  test('load returns null when no file exists', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);

    expect(await LocalePreferenceStore(directories).load(), isNull);
  });

  test('save then load round-trips the language', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = LocalePreferenceStore(directories);

    await store.save('en');
    expect(await store.load(), 'en');

    await store.save('zh');
    expect(await store.load(), 'zh');
  });

  test('save writes private file permissions', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = LocalePreferenceStore(directories);

    await store.save('en');

    if (!Platform.isWindows) {
      expect((await store.file.stat()).mode & 0x1ff, 0x180);
    }
  });

  test('corrupt JSON degrades to null instead of throwing', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = LocalePreferenceStore(directories);
    await store.file.writeAsString('{not json');

    expect(await store.load(), isNull);
  });

  test('unknown string value degrades to null', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = LocalePreferenceStore(directories);
    await store.file.writeAsString('"fr"');

    expect(await store.load(), isNull);
  });

  test('save rejects a language outside zh/en', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = LocalePreferenceStore(directories);

    expect(() => store.save('fr'), throwsArgumentError);
  });

  test('clear removes the preference file', () async {
    final temp = await Directory.systemTemp.createTemp(
      'locale_preference_store_test_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final directories = await RuntimeDirectories.fromBaseDirectory(temp);
    final store = LocalePreferenceStore(directories);

    await store.save('en');
    expect(await store.load(), 'en');

    await store.clear();
    expect(await store.load(), isNull);
    expect(await store.file.exists(), isFalse);
  });
}
