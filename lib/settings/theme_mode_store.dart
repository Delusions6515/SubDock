import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../runtime/runtime_directories.dart';
import '../runtime/runtime_permissions.dart';

/// File-backed persistence for the three-state theme preference.
///
/// Follows the existing `lib/settings/*_store.dart` shape (construct with
/// [RuntimeDirectories], atomic save), with one deliberate deviation:
/// [load] is lenient — a missing file and a corrupt file both yield `null`
/// (meaning "follow the system") so a broken preference file can never block
/// startup.
class ThemeModeStore {
  const ThemeModeStore(this.directories);

  final RuntimeDirectories directories;

  File get file => File.fromUri(directories.config.uri.resolve('theme_mode.json'));

  Future<ThemeMode?> load() async {
    if (!await file.exists()) return null;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! String) return null;
      return ThemeMode.values.byName(value);
    } on Object {
      // Corrupt or unreadable file degrades to follow-system.
      return null;
    }
  }

  Future<void> save(ThemeMode mode) async {
    final temporary = File(
      '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(mode.name)}\n',
        encoding: utf8,
        flush: true,
      );
      await restrictFileToCurrentUser(temporary);
      await temporary.rename(file.path);
      await restrictFileToCurrentUser(file);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
}
