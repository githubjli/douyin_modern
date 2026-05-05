import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../shared/main_shell.dart';

class MeowMediaApp extends StatelessWidget {
  const MeowMediaApp({
    super.key,
    this.enableFeedVideo = true,
    this.enableRemoteFeed = true,
  });

  final bool enableFeedVideo;
  final bool enableRemoteFeed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meow Media',
      theme: AppTheme.lightTheme(),
      home: MainShell(
        enableFeedVideo: enableFeedVideo,
        enableRemoteFeed: enableRemoteFeed,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
