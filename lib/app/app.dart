import 'package:flutter/material.dart';

import '../shared/main_shell.dart';

class DouyinModernApp extends StatelessWidget {
  const DouyinModernApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Douyin Modern',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
