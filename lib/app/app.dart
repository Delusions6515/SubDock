import 'package:flutter/material.dart';

class SubDockApp extends StatelessWidget {
  const SubDockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubDock',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('SubDock'))),
    );
  }
}
