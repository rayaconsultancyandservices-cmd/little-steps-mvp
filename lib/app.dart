import 'package:flutter/material.dart';
import 'package:little_steps_mvp/config/app_config.dart';
import 'package:little_steps_mvp/screens/splash_screen.dart';
// बदल: जुन्या AdminGate ऐवजी नवीन AdminEntryGate (landing screen सह) वापरतो.
import 'Admin/admin_landing_screen.dart';
import 'Parents/parent_splash_screen.dart';
import 'theme/app_theme.dart';

class LittleStepsApp extends StatelessWidget {
  const LittleStepsApp({super.key});

  Widget _home() {
    switch (AppConfig.role) {
      case AppRole.admin:
      // Web admin panel: login नसेल तर Landing screen, असेल तर थेट panel.
        return const AdminEntryGate();
      case AppRole.parent:
        return const ParentSplashScreen();
      case AppRole.teacher:
        return const SplashScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _home(),
    );
  }
}