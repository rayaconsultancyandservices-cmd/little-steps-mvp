import 'package:flutter/widgets.dart';

/// कोणता app चालू आहे: Teacher / Parent (Android) किंवा Admin (Web).
enum AppRole { teacher, parent, admin }

/// main_teacher.dart / main_parent.dart / main_admin.dart मध्ये हे सेट केलं जातं.
class AppConfig {
  static AppRole role = AppRole.teacher;

  /// Login यशस्वी झाल्यावर उघडणारा पहिला screen.
  /// (Teacher साठी MainShell, Parent साठी ParentShell, Admin साठी AdminShell)
  static Widget Function() homeBuilder = () => const SizedBox.shrink();

  static bool get isParent => role == AppRole.parent;
  static bool get isAdmin => role == AppRole.admin;

  static String get appTitle {
    switch (role) {
      case AppRole.parent:
        return 'Little Steps Parent';
      case AppRole.admin:
        return 'Little Steps Admin';
      case AppRole.teacher:
        return 'Little Steps Teacher';
    }
  }
}