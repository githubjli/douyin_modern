import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../app/theme/app_colors.dart';
import '../core/network/connectivity_provider.dart';
import '../features/creator_studio/pages/create_drama_page.dart';
import '../features/creator_studio/pages/upload_video_page.dart';
import '../features/feed/feed_page.dart';
import '../features/home/home_page.dart';
import '../features/home/domain/home_repository.dart';
import '../features/live/go_live_page.dart';
import '../features/membership/membership_page.dart';
import '../features/profile/profile_page.dart';
import 'shell_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    this.enableFeedVideo = true,
    this.enableRemoteFeed = true,
    this.enableRemoteHome = true,
    this.enableRemoteMembership = true,
    this.homeRepository,
  });

  final bool enableFeedVideo;
  final bool enableRemoteFeed;
  final bool enableRemoteHome;
  final bool enableRemoteMembership;
  final HomeRepository? homeRepository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(selectedTabProvider);

    // Fire a refresh trigger whenever the device regains connectivity.
    ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityProvider,
      (previous, next) {
        final bool wasOnline =
            previous?.value?.any((r) => r != ConnectivityResult.none) ?? true;
        final bool isOnline =
            next.value?.any((r) => r != ConnectivityResult.none) ?? true;
        if (!wasOnline && isOnline) {
          ref.read(networkRefreshTriggerProvider.notifier).increment();
        }
      },
    );

    void goToTab(int value) {
      final NavigatorState navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      ref.read(selectedTabProvider.notifier).set(value);
    }

    Future<void> onTapTab(int value) async {
      if (value == 2) {
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.cardBackground,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext sheetContext) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading:
                        const Icon(Icons.live_tv, color: AppColors.deepGold),
                    title: const Text('Go Live'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const GoLivePage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.ondemand_video,
                        color: AppColors.deepGold),
                    title: const Text('Publish Video'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push<bool?>(
                        MaterialPageRoute<bool?>(
                          builder: (_) => const UploadVideoPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.video_collection,
                        color: AppColors.deepGold),
                    title: const Text('Upload Short'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push<bool?>(
                        MaterialPageRoute<bool?>(
                          builder: (_) => const CreateDramaPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
        return;
      }
      ref.read(selectedTabProvider.notifier).set(value);
    }

    final int displayIndex = index >= 2 ? index - 1 : index;
    final int networkTrigger = ref.watch(networkRefreshTriggerProvider);
    final List<Widget> displayPages = <Widget>[
      HomePage(
        useRemote: enableRemoteHome,
        remoteRepository: homeRepository,
        onSignInPressed: () => goToTab(4),
        onSubscribePressed: () => goToTab(3),
        networkRefreshTrigger: networkTrigger,
      ),
      FeedPage(
        enableVideo: enableFeedVideo,
        enableRemoteFeed: enableRemoteFeed,
        isActive: index == 1,
        networkRefreshTrigger: networkTrigger,
      ),
      MembershipPage(
        useRemote: enableRemoteMembership,
        isActive: index == 3,
        onSignInPressed: () => goToTab(4),
        onSubscribePressed: () => goToTab(3),
      ),
      ProfilePage(networkRefreshTrigger: networkTrigger),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: displayIndex, children: displayPages),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.40),
              border: Border(
                top: BorderSide(
                  color: AppColors.softBorder.withValues(alpha: 0.36),
                  width: 0.5,
                ),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 55,
                child: BottomNavigationBar(
                  currentIndex: index,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconSize: 24,
                  selectedItemColor: AppColors.brandGold,
                  unselectedItemColor: AppColors.cocoaText,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedLabelStyle: const TextStyle(height: 0.95),
                  unselectedLabelStyle: const TextStyle(height: 0.95),
                  showUnselectedLabels: true,
                  onTap: onTapTab,
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.play_circle_outline_rounded),
                      activeIcon: Icon(Icons.play_circle_fill_rounded),
                      label: 'Shorts',
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
