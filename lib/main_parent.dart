import 'package:flutter/material.dart';
import 'package:little_steps_mvp/Parents/parent_shell.dart';
import 'package:little_steps_mvp/config/app_config.dart';
import 'package:little_steps_mvp/app.dart';

// Parent APK चा entry point.
void main() {
  AppConfig.role = AppRole.parent;
  AppConfig.homeBuilder = () => const ParentShell();
  runApp(const LittleStepsApp());
}