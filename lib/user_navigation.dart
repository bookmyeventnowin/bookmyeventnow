import 'package:flutter/material.dart';

const Color _navBackground = Colors.black;

/// Shared notifier so any part of the user experience can switch tabs.
final ValueNotifier<int> userNavIndex = ValueNotifier<int>(0);

void navigateUserTab(BuildContext context, int index) {
  userNavIndex.value = index;
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
}

class UserBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int index)? onNavigate;
  const UserBottomNav({
    super.key,
    required this.currentIndex,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: _navBackground,
      currentIndex: currentIndex,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      showUnselectedLabels: true,
      onTap: (index) {
        if (onNavigate != null) {
          onNavigate!(index);
        } else {
          navigateUserTab(context, index);
        }
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
