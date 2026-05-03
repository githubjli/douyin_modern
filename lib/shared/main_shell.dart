import 'package:flutter/material.dart';

import '../features/discover/discover_page.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_page.dart';
import '../features/profile/profile_page.dart';
import '../features/publish/publish_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _pages = const <Widget>[
    FeedPage(),
    DiscoverPage(),
    PublishPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black.withOpacity(0.55),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
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
