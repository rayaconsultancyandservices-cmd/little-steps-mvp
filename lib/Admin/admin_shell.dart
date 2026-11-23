import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'admin_attendance.dart';
import 'admin_circulars.dart';
import 'admin_classes.dart';
import 'admin_dashboard.dart';
import 'admin_fees.dart';
import 'admin_parents.dart';
import 'admin_state.dart';
import 'admin_students.dart';
import 'admin_teachers.dart';
import 'admin_widgets.dart';

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Admin web panel: डावीकडे sidebar + उजवीकडे selected page.
/// (छोट्या screen वर sidebar drawer मध्ये जातो.)
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _items = [
    _NavItem('Dashboard', Icons.dashboard_rounded),
    _NavItem('Teachers', Icons.badge_rounded),
    _NavItem('Students', Icons.child_care_rounded),
    _NavItem('Classes', Icons.class_rounded),
    _NavItem('Parents', Icons.family_restroom_rounded),
    _NavItem('Attendance', Icons.fact_check_rounded),
    _NavItem('Fees', Icons.payments_rounded),
    _NavItem('Circulars & Events', Icons.campaign_rounded),
  ];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  void _go(int i) {
    setState(() => _index = i);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return const AdminTeachersScreen();
      case 2:
        return const AdminStudentsScreen();
      case 3:
        return const AdminClassesScreen();
      case 4:
        return const AdminParentsScreen();
      case 5:
        return const AdminAttendanceScreen();
      case 6:
        return const AdminFeesScreen();
      case 7:
        return const AdminCircularsScreen();
      default:
        return AdminDashboardScreen(onNavigate: _go);
    }
  }

  Future<void> _logout() async {
    final ok = await adminConfirm(
      context,
      title: 'Logout?',
      message: 'You will need to sign in again to use the admin panel.',
      confirmText: 'Logout',
      danger: false,
    );
    if (ok) await AdminState.instance.logout();
  }

  Widget _sidebar() {
    final s = AdminState.instance;
    return Container(
      width: 250,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: AdminColors.primary),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Little Steps\nAdmin',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.15,
                        color: AdminColors.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _navTile(i, _items[i]),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      s.adminName.isEmpty ? 'A' : s.adminName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AdminColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          s.adminEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        size: 20, color: AdminColors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(int i, _NavItem item) {
    final selected = i == _index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _go(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AdminColors.primary : AdminColors.muted,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AdminColors.primary : AdminColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final wide = MediaQuery.of(context).size.width >= 900;

        if (wide) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AdminColors.pageBg,
            body: Row(
              children: [
                _sidebar(),
                const VerticalDivider(width: 1, color: AdminColors.border),
                Expanded(child: _page()),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AdminColors.pageBg,
          appBar: AppBar(
            title: Text(_items[_index].label),
            backgroundColor: Colors.white,
          ),
          drawer: Drawer(child: _sidebar()),
          body: _page(),
        );
      },
    );
  }
}