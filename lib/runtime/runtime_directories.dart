import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RuntimeDirectories {
  const RuntimeDirectories._({
    required this.data,
    required this.logs,
    required this.backups,
  });

  final Directory data;
  final Directory logs;
  final Directory backups;

  static Future<RuntimeDirectories> create() async {
    final applicationSupport = await getApplicationSupportDirectory();
    return fromBaseDirectory(
      Directory.fromUri(applicationSupport.uri.resolve('SubDock/')),
    );
  }

  static Future<RuntimeDirectories> fromBaseDirectory(Directory base) async {
    final data = Directory.fromUri(base.uri.resolve('data/'));
    final logs = Directory.fromUri(base.uri.resolve('logs/'));
    final backups = Directory.fromUri(base.uri.resolve('backups/'));
    await Future.wait([
      data.create(recursive: true),
      logs.create(recursive: true),
      backups.create(recursive: true),
    ]);
    return RuntimeDirectories._(data: data, logs: logs, backups: backups);
  }
}
