import 'package:flutter/material.dart';

import 'app_colors.dart';

const Color _navBackground = Colors.white;

/// Shared notifier so any part of the user experience can switch tabs.
final ValueNotifier<int> userNavIndex = ValueNotifier<int>(0);

void navigateUserTab(BuildContext context, int index) {
  userNavIndex.value = index;
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const List<_NavItemData> _navItems = [
  _NavItemData(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
  ),
  _NavItemData(
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
    label: 'My bookings',
  ),
  _NavItemData(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profile',
  ),
];

const List<_NavItemData> _vendorNavItems = [
  _NavItemData(
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
    label: 'Home',
  ),
  _NavItemData(
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
    label: 'Bookings',
  ),
  _NavItemData(
    icon: Icons.workspace_premium_outlined,
    activeIcon: Icons.workspace_premium,
    label: 'Subscription',
  ),
];

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
    return _PillNavBar(
      items: _navItems,
      currentIndex: currentIndex,
      onTap: (index) {
        if (onNavigate != null) {
          onNavigate!(index);
        } else {
          navigateUserTab(context, index);
        }
      },
    );
  }
}

/// Same floating pill-style bottom nav as [UserBottomNav], for the vendor
/// (admin) home screens: Home, Bookings, Subscription.
class VendorBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int index) onNavigate;
  const VendorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return _PillNavBar(
      items: _vendorNavItems,
      currentIndex: currentIndex,
      onTap: onNavigate,
    );
  }
}

class _PillNavBar extends StatelessWidget {
  const _PillNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavItemData> items;
  final int currentIndex;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _navBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavPillItem(
                    data: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  const _NavPillItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? data.activeIcon : data.icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
