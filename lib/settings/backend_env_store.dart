import 'dart:convert';
import 'dart:io';

import '../runtime/runtime_directories.dart';
import '../runtime/runtime_permissions.dart';
import 'backend_env.dart';
import 'config_error.dart';

class BackendEnvStore {
  const BackendEnvStore(this.directories);

  final RuntimeDirectories directories;

  File get file => File.fromUri(directories.config.uri.resolve('backend.env'));

  Future<BackendEnvDocument> load() async {
    if (!await file.exists()) return BackendEnvDocument.parse('');
    return BackendEnvDocument.parse(await file.readAsString(encoding: utf8));
  }

  Future<void> save(BackendEnvDocument document) async {
    final issues = BackendEnvPolicy.validate(document);
    if (issues.isNotEmpty) {
      throw AppConfigError(
        AppConfigErrorCode.environmentInvalid,
        issue: issues.first,
      );
    }
    final temporary = File(
      '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(
        document.rawText,
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
