import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:little_steps_mvp/Parents/parent_circulars_screen.dart';
import 'package:little_steps_mvp/Parents/parent_child_profile_screen.dart';
import 'package:little_steps_mvp/Parents/parent_diary_screen.dart';
import 'package:little_steps_mvp/Parents/parent_fees_screen.dart';
import 'package:little_steps_mvp/Parents/parent_home_screen.dart';
import 'package:little_steps_mvp/Parents/parent_leave_screen.dart';
import 'package:little_steps_mvp/Parents/parent_message_screen.dart';
import 'package:little_steps_mvp/Parents/parent_photos_screen.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import 'parent_login_screen.dart';

/// Parent app main shell: 5 bottom tabs (light-blue theme).
/// Tabs: Home, Photos, Diary, Circulars, Profile (child profile).
/// Fees / Message Teacher / Calendar are opened from Home.
class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  // 0 Home, 1 Photos, 2 Diary, 3 Circulars, 4 Profile
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  /// Home screen still calls onNavigate(4) for "Fees" (quick action,
  /// fee banner, notifications). Fees is no longer a tab, so open it
  /// as its own screen with a back arrow.
  void _openFromHome(int i) {
    if (i == 6) {
      // Notification / Home card मधून "Leave" उघडतो.
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ParentLeaveScreen()),
      );
    } else if (i == 5) {
      // Notification मधून "Message from teacher" उघडतो.
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ParentMessageScreen()),
      );
    } else if (i == 4) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: ParentColors.pageBg,
            body: SafeArea(child: const ParentFeesScreen()),
          ),
        ),
      );
    } else {
      _go(i);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: ParentColors.dark,
          ),
        ),
        content: const Text(
          'You will return to the login screen.',
          style: TextStyle(color: ParentColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ParentColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: ParentColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Firebase session + live streams खऱ्या अर्थाने बंद करतो (आधी फक्त screen बदलत होता).
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ParentLoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ParentHomeScreen(onNavigate: _openFromHome, onLogout: _logout),
      const ParentPhotosScreen(),
      const ParentDiaryScreen(),
      const ParentCircularsScreen(),
      ParentChildProfileScreen(onBack: () => _go(0)),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _index = 0); // Back -> Home
        },
        child: Scaffold(
          backgroundColor: ParentColors.pageBg,
          // Same light-blue gradient behind every parent tab.
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ParentColors.skyTop, ParentColors.pageBg],
                stops: [0.0, 0.45],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          bottomNavigationBar: _buildNavBar(),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final unread = s.unreadCircularCount;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: ParentColors.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0x142B8FDB),
                blurRadius: 18,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 68,
              indicatorColor: ParentColors.tintStrong,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 24,
                  color: selected ? ParentColors.primary : ParentColors.muted,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? ParentColors.primary : ParentColors.muted,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library_rounded),
                  label: 'Photos',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: 'Diary',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    backgroundColor: ParentColors.danger,
                    label: Text('$unread'),
                    child: const Icon(Icons.description_outlined),
                  ),

                  selectedIcon: Badge(
                    isLabelVisible: unread > 0,
                    backgroundColor: ParentColors.danger,
                    label: Text('$unread'),
                    child: const Icon(Icons.description_rounded),
                  ),
                  label: 'Circulars',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}