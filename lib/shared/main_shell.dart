import 'dart:ui';

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
    this.enableRemoteHome = true,
  });

  final bool enableFeedVideo;
  final bool enableRemoteFeed;
  final bool enableRemoteHome;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
      HomePage(useRemote: widget.enableRemoteHome),
      FeedPage(
        enableVideo: widget.enableFeedVideo,
        enableRemoteFeed: widget.enableRemoteFeed,
        isActive: _index == 1,
      ),
      const MembershipPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: displayIndex, children: displayPages),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.62),
              border: Border(
                top: BorderSide(
                  color: AppColors.softBorder.withValues(alpha: 0.42),
                  width: 0.5,
                ),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: BottomNavigationBar(
                  currentIndex: _index,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconSize: 25,
                  selectedItemColor: AppColors.brandGold,
                  unselectedItemColor: AppColors.cocoaText,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedLabelStyle: const TextStyle(height: 1.1),
                  unselectedLabelStyle: const TextStyle(height: 1.1),
                  showUnselectedLabels: true,
                  onTap: _onTapTab,
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.play_circle_outline_rounded),
                      activeIcon: Icon(Icons.play_circle_fill_rounded),
                      label: 'Short',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.add_circle,
                        size: 32,
                        color: AppColors.brandGold,
                      ),
                      label: '',
                      tooltip: 'Create',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.star_border_rounded),
                      activeIcon: Icon(Icons.star_rounded),
                      label: 'Member',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded),
                      activeIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
