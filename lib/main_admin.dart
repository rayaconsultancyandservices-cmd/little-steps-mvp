import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:little_steps_mvp/config/app_config.dart';
import 'package:little_steps_mvp/app.dart';

import 'Admin/admin_shell.dart';
import 'firebase_options.dart';

// Admin WEB panel चा entry point.
//   चालवण्यासाठी:  flutter run -d chrome -t lib/main_admin.dart
//   build:        flutter build web -t lib/main_admin.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  AppConfig.role = AppRole.admin;
  AppConfig.homeBuilder = () => const AdminShell();

  runApp(const LittleStepsApp());
}