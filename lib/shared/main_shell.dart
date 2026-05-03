import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../features/discover/discover_page.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_page.dart';
import '../features/profile/profile_page.dart';
import '../features/publish/publish_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.enableFeedVideo = true});

  final bool enableFeedVideo;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _pages = <Widget>[
    FeedPage(enableVideo: widget.enableFeedVideo),
    const DiscoverPage(),
    const PublishPage(),
    const MessagesPage(),
    const ProfilePage(),
  ];

  bool get _isFeedTab => _index == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _isFeedTab
            ? Colors.black.withValues(alpha: 0.55)
            : AppColors.cardBackground.withValues(alpha: 0.97),
        selectedItemColor: _isFeedTab ? AppColors.brandGold : AppColors.deepGold,
        unselectedItemColor: _isFeedTab ? Colors.white70 : AppColors.mutedOliveText,
        onTap: (int value) => setState(() => _index = value),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_rounded), label: 'Publish'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
