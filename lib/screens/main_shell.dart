import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import 'home_screen.dart';
import 'attendance_screen.dart';
import 'photos_screen.dart';
import 'diary_screen.dart';
import 'circular_screen.dart';
import 'messages_screen.dart';
import 'teacher_profile_screen.dart';
import 'fees_screen.dart';
import 'events_screen.dart';
import 'leave_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Screen indexes:
  // 0 Home
  // 1 Attendance
  // 2 Photos
  // 3 Diary
  // 4 Circulars
  // 5 Messages   (Home वरून उघडतो)
  // 6 My Profile  (Home वरून उघडतो)
  // 7 Fees       (Home वरून उघडतो) - नवीन
  // 8 Events     (Home वरून उघडतो) - नवीन
  // 9 Leave      (Home वरून उघडतो) - नवीन

  int _selectedIndex = 0;

  void _goToTab(int index) {
    if (index < 0 || index > 9) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  void _goHome() {
    _goToTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onNavigate: _goToTab),
      AttendanceScreen(onBack: _goHome),
      PhotosScreen(onBack: _goHome),
      DiaryScreen(onBack: _goHome),
      CircularScreen(onBack: _goHome),
      MessagesScreen(onBack: _goHome),
      TeacherProfileScreen(onBack: _goHome),
      // नवीन: Fees आणि Events — फक्त उघडल्यावर तयार होतात (लगेच fresh data).
      _selectedIndex == 7
          ? TeacherFeesScreen(onBack: _goHome)
          : const SizedBox.shrink(),
      _selectedIndex == 8
          ? TeacherEventsScreen(onBack: _goHome)
          : const SizedBox.shrink(),
      _selectedIndex == 9
          ? TeacherLeaveScreen(onBack: _goHome)
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),

      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    // Messages आणि My Profile Home वरून उघडतात, म्हणून Home highlighted राहतो.
    final activeIndex = _selectedIndex > 4 ? 0 : _selectedIndex;

    const items = [
      _NavItem(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _NavItem(
        label: 'Attendance',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check_rounded,
      ),
      _NavItem(
        label: 'Photos',
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library_rounded,
      ),
      _NavItem(
        label: 'Diary',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
      ),
      _NavItem(
        label: 'Circulars',
        icon: Icons.description_outlined,
        selectedIcon: Icons.description_rounded,
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(
              color: Color(0xFFE9EFEB),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = activeIndex == index;

            return Expanded(
              child: _buildNavItem(
                item: item,
                selected: selected,
                onTap: () => _goToTab(index),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                key: ValueKey(selected),
                size: 21,
                color: selected
                    ? AppColors.primary
                    : AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.muted,
                fontSize: 9,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 15 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}