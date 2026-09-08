import 'package:flutter/material.dart';

import 'app/app.dart';
import 'runtime/desktop_backend_runtime.dart';
import 'runtime/runtime_directories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directories = await RuntimeDirectories.create();
  runApp(SubDockApp(runtime: DesktopBackendRuntime(directories: directories)));
}
