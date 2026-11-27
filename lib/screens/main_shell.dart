import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import 'home_screen.dart';
import 'attendance_screen.dart';
import 'photos_screen.dart';
import 'diary_screen.dart';
import 'circular_screen.dart';
import 'messages_screen.dart';
import 'teacher_profile_screen.dart';
import 'leave_screen.dart';
import 'my_students_screen.dart';

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
  // 7 (रिकामा)   - आधी Fees होता. बदल (Step 6): Fees फक्त Admin बघतो, Teacher app मधून काढला.
  // 8 (रिकामा)   - आधी Events होता. बदल (Step 6): Events फक्त Admin टाकतो, Teacher app मधून काढला.
  // 9 Leave      (Home वरून उघडतो) - नवीन
  // 10 My Students (Home वरून उघडतो) - नवीन; मुलावर टॅप = Student Profile

  int _selectedIndex = 0;

  void _goToTab(int index) {
    if (index < 0 || index > 10) return;

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
      // 7 आणि 8: जागा रिकामी ठेवली आहे, म्हणजे बाकी screens चे index (9 Leave,
      // 10 My Students) तसेच राहतात आणि Home / Notifications चे दुवे बदलावे लागत नाहीत.
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      _selectedIndex == 9
          ? TeacherLeaveScreen(onBack: _goHome)
          : const SizedBox.shrink(),
      // नवीन: My Students — फक्त उघडल्यावर तयार होतो.
      _selectedIndex == 10
          ? MyStudentsScreen(onBack: _goHome)
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
    // Bottom bar चे 5 tabs आणि ते उघडणारे page index:
    //   Home=0, Attendance=1, Photos=2, Diary=3, Profile=6
    // Circulars / Messages / Leave / My Students Home वरून उघडतात,
    // म्हणून त्यावेळी Home highlighted राहतो.
    const tabPages = [0, 1, 2, 3, 6];
    final activeIndex =
    tabPages.contains(_selectedIndex) ? tabPages.indexOf(_selectedIndex) : 0;

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
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle_rounded,
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
                onTap: () => _goToTab(tabPages[index]),
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