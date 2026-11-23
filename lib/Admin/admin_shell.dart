import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'admin_attendance.dart';
import 'admin_circulars.dart';
import 'admin_classes.dart';
import 'admin_dashboard.dart';
import 'admin_diary.dart';
import 'admin_fees.dart';
import 'admin_messages.dart';
import 'admin_parents.dart';
import 'admin_photos.dart';
import 'admin_reports.dart';
import 'admin_state.dart';
import 'admin_students.dart';
import 'admin_teachers.dart';
import 'admin_widgets.dart';

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const Color _sidebarColor = Color(0xFF172D35);
  static const Color _sidebarMuted = Color(0xFF9BB0B5);
  static const Color _accent = Color(0xFF57C5A5);
  static const double _sidebarWidth = 248;

  static const List<_NavItem> _items = [
    _NavItem('Dashboard', Icons.grid_view_rounded),
    _NavItem('Teachers', Icons.badge_rounded),
    _NavItem('Students', Icons.child_care_rounded),
    _NavItem('Classes', Icons.class_rounded),
    _NavItem('Parents', Icons.family_restroom_rounded),
    _NavItem('Attendance', Icons.fact_check_rounded),
    _NavItem('Fees & Payments', Icons.account_balance_wallet_rounded),
    _NavItem('Circulars & Events', Icons.campaign_rounded),
    _NavItem('Daily Diary', Icons.menu_book_rounded),
    _NavItem('Photo Gallery', Icons.photo_library_rounded),
    _NavItem('Messages', Icons.forum_rounded),
    _NavItem('Reports & Export', Icons.download_rounded),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey =
  GlobalKey<ScaffoldState>();

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
      case 8:
        return const AdminDiaryScreen();
      case 9:
        return const AdminPhotosScreen();
      case 10:
        return const AdminMessagesScreen();
      case 11:
        return const AdminReportsScreen();
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

    if (ok && mounted) {
      await AdminState.instance.logout();
    }
  }

  Future<void> _resetMyPassword() async {
    final mail = AdminState.instance.adminEmail;
    if (mail.isEmpty) return;

    final ok = await adminConfirm(
      context,
      title: 'Change password?',
      message: 'A password reset link will be emailed to $mail.',
      confirmText: 'Send link',
      danger: false,
    );

    if (!ok) return;

    final err = await AuthService.resetPassword(mail);

    if (!mounted) return;

    if (err != null) {
      adminSnack(context, err, error: true);
    } else {
      adminSnack(context, 'Password reset email sent to $mail');
    }
  }

  Future<void> _editProfile() async {
    final st = AdminState.instance;
    final formKey = GlobalKey<FormState>();

    final name = TextEditingController(text: st.adminName);
    final school = TextEditingController(text: st.schoolName);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Admin Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AdminColors.dark,
          ),
        ),
        content: SizedBox(
          width: 390,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                dialogField(
                  name,
                  'Admin name',
                  required: true,
                ),
                dialogField(
                  school,
                  'School name',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      st.adminEmail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: adminPrimaryButton(),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );

    if (ok != true) {
      name.dispose();
      school.dispose();
      return;
    }

    try {
      await st.updateAdminProfile(
        name: name.text,
        school: school.text,
      );

      if (mounted) {
        adminSnack(context, 'Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        adminSnack(
          context,
          AdminState.errorText(e),
          error: true,
        );
      }
    } finally {
      name.dispose();
      school.dispose();
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _sidebarMuted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _navTile(int i) {
    final item = _items[i];
    final selected = i == _index;
    final state = AdminState.instance;
    final badgeCount = i == 1
        ? state.pendingTeachersCount
        : i == 10
        ? state.teacherUnreadTotal
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 3,
      ),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _go(i),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? const Border(
                left: BorderSide(
                  color: _accent,
                  width: 3,
                ),
              )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: selected ? _accent : _sidebarMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : _sidebarMuted,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _accent
                          : Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? _sidebarColor : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else if (selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _accent,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(19, 22, 17, 21),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accent.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: _accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Little Steps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'SCHOOL ADMINISTRATION',
                  style: TextStyle(
                    color: _sidebarMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileFooter() {
    final s = AdminState.instance;

    final initial = s.adminName.trim().isEmpty
        ? 'A'
        : s.adminName.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 11, 13),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: _editProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 7,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _accent.withValues(alpha: 0.18),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.adminName.trim().isEmpty ? 'Admin' : s.adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          s.schoolName.trim().isEmpty
                              ? 'School administrator'
                              : s.schoolName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _sidebarMuted.withValues(alpha: 0.9),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    color: _sidebarMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _footerAction(
                  icon: Icons.lock_reset_rounded,
                  label: 'Password',
                  onTap: _resetMyPassword,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _footerAction(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  onTap: _logout,
                  danger: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 7,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: danger ? const Color(0xFFFF928A) : _sidebarMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: danger ? const Color(0xFFFF928A) : _sidebarMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: _sidebarWidth,
      color: _sidebarColor,
      child: SafeArea(
        child: Column(
          children: [
            _brand(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _sectionLabel('Overview'),
                  _navTile(0),
                  _sectionLabel('School management'),
                  for (int i = 1; i <= 4; i++) _navTile(i),
                  _sectionLabel('Daily operations'),
                  for (int i = 5; i <= 6; i++) _navTile(i),
                  _sectionLabel('Communication & activities'),
                  for (int i = 7; i <= 10; i++) _navTile(i),
                  const SizedBox(height: 15),
                ],
              ),
            ),
            _profileFooter(),
          ],
        ),
      ),
    );
  }

  Widget _topHeader({bool mobile = false}) {
    final s = AdminState.instance;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 26,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AdminColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (mobile) ...[
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
              color: AdminColors.dark,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _items[_index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.dark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.schoolName.isEmpty
                      ? 'Welcome to your school management workspace'
                      : s.schoolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!mobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: AdminColors.greenLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: AdminColors.green,
                    size: 8,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Admin workspace',
                    style: TextStyle(
                      color: AdminColors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
          ],
          Tooltip(
            message: 'Edit admin profile',
            child: InkWell(
              onTap: _editProfile,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  s.adminName.trim().isEmpty
                      ? 'A'
                      : s.adminName.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: AdminColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final width = MediaQuery.of(context).size.width;
        final wide = width >= 900;

        if (wide) {
          return Scaffold(
            backgroundColor: AdminColors.pageBg,
            body: Row(
              children: [
                _sidebar(),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AdminColors.border,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _topHeader(),
                      Expanded(child: _page()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }


        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AdminColors.pageBg,
          drawer: Drawer(
            width: _sidebarWidth,
            backgroundColor: _sidebarColor,
            child: _sidebar(),
          ),
          body: Column(
            children: [
              _topHeader(mobile: true),
              Expanded(child: _page()),
            ],
          ),
        );
      },
    );
  }
}