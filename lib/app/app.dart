import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../shared/main_shell.dart';

class MeowMediaApp extends StatelessWidget {
  const MeowMediaApp({
    super.key,
    this.enableFeedVideo = true,
    this.enableRemoteFeed = true,
    this.enableRemoteHome = true,
    this.enableRemoteMembership = true,
  });

  final bool enableFeedVideo;
  final bool enableRemoteFeed;
  final bool enableRemoteHome;
  final bool enableRemoteMembership;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meow Media',
      theme: AppTheme.lightTheme(),
      home: MainShell(
        enableFeedVideo: enableFeedVideo,
        enableRemoteFeed: enableRemoteFeed,
        enableRemoteHome: enableRemoteHome,
        enableRemoteMembership: enableRemoteMembership,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
