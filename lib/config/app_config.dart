import 'package:flutter/widgets.dart';

/// कोणता app चालू आहे: Teacher की Parent.
enum AppRole { teacher, parent }

/// main_teacher.dart / main_parent.dart मध्ये हे सेट केलं जातं.
class AppConfig {
  static AppRole role = AppRole.teacher;

  /// Login यशस्वी झाल्यावर उघडणारा पहिला screen.
  /// (Teacher साठी MainShell, Parent साठी ParentShell)
  static Widget Function() homeBuilder = () => const SizedBox.shrink();

  static bool get isParent => role == AppRole.parent;
  static String get appTitle =>
      isParent ? 'Little Steps Parent' : 'Little Steps Teacher';
}