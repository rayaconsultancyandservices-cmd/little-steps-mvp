
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:little_steps_mvp/config/app_config.dart';
import 'package:little_steps_mvp/app.dart';
import 'package:little_steps_mvp/screens/main_shell.dart';

import 'firebase_options.dart';

// Teacher APK चा entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Teacher App Configuration
  AppConfig.role = AppRole.teacher;
  AppConfig.homeBuilder = () => const MainShell();

  runApp(const LittleStepsApp());
}
