import 'package:flutter/material.dart';

const Color _navBackground = Color(0xFFF4F1FF);

/// Shared notifier so any part of the user experience can switch tabs.
final ValueNotifier<int> userNavIndex = ValueNotifier<int>(0);

void navigateUserTab(BuildContext context, int index) {
  userNavIndex.value = index;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class UserBottomNav extends StatelessWidget {
  final int currentIndex;
  const UserBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: _navBackground,
      currentIndex: currentIndex,
      selectedItemColor: Colors.black87,
      unselectedItemColor: Colors.black54,
      showUnselectedLabels: true,
      onTap: (index) {
        if (index == currentIndex) return;
        navigateUserTab(context, index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_note_outlined),
          activeIcon: Icon(Icons.event_note),
          label: 'My Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
