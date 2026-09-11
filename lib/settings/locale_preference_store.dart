import 'dart:convert';
import 'dart:io';

import '../runtime/runtime_directories.dart';
import '../runtime/runtime_permissions.dart';

/// File-backed persistence for the UI language preference.
///
/// Mirrors [ThemeModeStore]: construct with [RuntimeDirectories], atomic save
/// with user-only permissions, and a lenient [load] — a missing file and a
/// corrupt file both yield `null` (meaning "follow the system") so a broken
/// preference file can never block startup.
class LocalePreferenceStore {
  const LocalePreferenceStore(this.directories);

  final RuntimeDirectories directories;

  /// The two languages the shell can show; an unknown persisted value
  /// degrades to following the system.
  static const supported = ['zh', 'en'];

  File get file =>
      File.fromUri(directories.config.uri.resolve('locale_preference.json'));

  Future<String?> load() async {
    if (!await file.exists()) return null;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! String || !supported.contains(value)) return null;
      return value;
    } on Object {
      // Corrupt or unreadable file degrades to follow-system.
      return null;
    }
  }

  Future<void> save(String language) async {
    if (!supported.contains(language)) {
      throw ArgumentError.value(language, 'language', 'must be zh or en');
    }
    final temporary = File(
      '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(language)}\n',
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

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
