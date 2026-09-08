import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RuntimeDirectories {
  const RuntimeDirectories._({
    required this.data,
    required this.logs,
    required this.backups,
    required this.config,
    required this.components,
    required this.staging,
  });

  final Directory data;
  final Directory logs;
  final Directory backups;
  final Directory config;
  final Directory components;
  final Directory staging;

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
    final config = Directory.fromUri(base.uri.resolve('config/'));
    final components = Directory.fromUri(base.uri.resolve('components/'));
    final staging = Directory.fromUri(base.uri.resolve('staging/'));
    await Future.wait([
      data.create(recursive: true),
      logs.create(recursive: true),
      backups.create(recursive: true),
      config.create(recursive: true),
      components.create(recursive: true),
      staging.create(recursive: true),
    ]);
    return RuntimeDirectories._(
      data: data,
      logs: logs,
      backups: backups,
      config: config,
      components: components,
      staging: staging,
    );
  }
}
