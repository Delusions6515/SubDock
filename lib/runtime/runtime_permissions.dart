import 'dart:io';

Future<void> restrictDirectoryToCurrentUser(Directory directory) =>
    _restrict(directory.path, isDirectory: true);

Future<void> restrictFileToCurrentUser(File file) =>
    _restrict(file.path, isDirectory: false);

Future<void> _restrict(String path, {required bool isDirectory}) async {
  if (Platform.isWindows) {
    final user = Platform.environment['USERNAME'];
    if (user == null || user.isEmpty) {
      throw StateError('Unable to determine the current Windows user');
    }
    final result = await Process.run('icacls', [
      path,
      '/inheritance:r',
      '/grant:r',
      '$user:(F)',
    ]);
    if (result.exitCode != 0) {
      throw StateError('Unable to restrict access to $path: ${result.stderr}');
    }
    return;
  }

  final result = await Process.run('chmod', [
    isDirectory ? '700' : '600',
    path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Unable to restrict access to $path: ${result.stderr}');
  }
}
