import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../features/feed/feed_page.dart';
import '../features/home/home_page.dart';
import '../features/membership/membership_page.dart';
import '../features/profile/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.enableFeedVideo = true,
    this.enableRemoteFeed = true,
  });

  final bool enableFeedVideo;
  final bool enableRemoteFeed;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _pages = <Widget>[
    const HomePage(),
    FeedPage(
      enableVideo: widget.enableFeedVideo,
      enableRemoteFeed: widget.enableRemoteFeed,
    ),
    const SizedBox.shrink(),
    const MembershipPage(),
    const ProfilePage(),
  ];

  bool get _isShortsTab => _index == 1;

  Future<void> _onTapTab(int value) async {
    if (value == 2) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.cardBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.live_tv, color: AppColors.deepGold),
                  title: const Text('Go Live'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.ondemand_video,
                      color: AppColors.deepGold),
                  title: const Text('Publish Video'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.video_collection,
                      color: AppColors.deepGold),
                  title: const Text('Upload Short'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final int displayIndex = _index >= 2 ? _index - 1 : _index;
    final List<Widget> displayPages = <Widget>[
      _pages[0],
      _pages[1],
      _pages[3],
      _pages[4],
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: displayIndex, children: displayPages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _isShortsTab
            ? Colors.black.withValues(alpha: 0.55)
            : AppColors.cardBackground.withValues(alpha: 0.97),
        selectedItemColor:
            _isShortsTab ? AppColors.brandGold : AppColors.deepGold,
        unselectedItemColor:
            _isShortsTab ? Colors.white70 : AppColors.mutedOliveText,
        onTap: _onTapTab,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.play_arrow_rounded), label: 'Shorts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 34),
            label: '',
            tooltip: 'Create',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium), label: 'Membership'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
