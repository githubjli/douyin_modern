import 'package:flutter/material.dart';

import '../shared/main_shell.dart';

class DouyinModernApp extends StatelessWidget {
  const DouyinModernApp({super.key, this.enableFeedVideo = true});

  final bool enableFeedVideo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Douyin Modern',
      theme: ThemeData.dark(useMaterial3: true),
      home: MainShell(enableFeedVideo: enableFeedVideo),
      debugShowCheckedModeBanner: false,
    );
  }
}
