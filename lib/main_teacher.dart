import 'package:flutter/material.dart';
import 'package:little_steps_mvp/config/app_config.dart';
import 'package:little_steps_mvp/app.dart';
import 'package:little_steps_mvp/screens/main_shell.dart';

// Teacher APK चा entry point.
void main() {
  AppConfig.role = AppRole.teacher;
  AppConfig.homeBuilder = () => const MainShell();
  runApp(const LittleStepsApp());
}