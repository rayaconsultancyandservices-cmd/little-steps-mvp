
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:little_steps_mvp/Parents/parent_shell.dart';
import 'package:little_steps_mvp/config/app_config.dart';
import 'package:little_steps_mvp/app.dart';
import 'firebase_options.dart';

// Parent APK चा entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  AppConfig.role = AppRole.parent;
  AppConfig.homeBuilder = () => const ParentShell();

  runApp(const LittleStepsApp());
}
