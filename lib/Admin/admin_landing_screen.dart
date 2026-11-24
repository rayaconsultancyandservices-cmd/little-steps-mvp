import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'admin_login_screen.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

// =====================================================================
// ADMIN WEB PANEL - LANDING SCREEN  (login च्या आधीचा पहिला screen)
// ---------------------------------------------------------------------
// फाईलचं स्थान :  lib/Admin/admin_landing_screen.dart   (नवीन file)
//
// यात दोन classes आहेत:
//   1) AdminEntryGate     -> जुन्या AdminGate ची जागा घेतो.
//        - आधी login असेल तर थेट Admin panel (AppConfig.homeBuilder)
//        - नसेल तर AdminLandingScreen
//   2) AdminLandingScreen -> navbar + hero + feature strip + How it works
//        + Insights + Modules + CTA + footer.
//
// Images (assets/images/admin/ मध्ये टाका, pubspec मध्ये नोंद करा):
//   hero_classroom.jpg       (hero फोटो, 1672x941)
//   insights_dashboard.png   (Admin Dashboard screenshot, 1919x945)
//   cta_school.jpg           (शेवटच्या बँडचा फोटो, 1672x941)
// फोटो नसले तरी app चालतो: त्या जागी सुंदर gradient + icon दिसतो.
//
// इथे कोणताही खोटा आकडा नाही: login च्या आधी Firestore rules मुळे
// data वाचता येत नाही, म्हणून सगळा मजकूर स्थिर आहे.
// =====================================================================

const double _maxW = 1100;

class _Img {
  static const hero = 'assets/images/admin/hero_classroom.jpg';
  static const dashboard = 'assets/images/admin/insights_dashboard.png';
  static const cta = 'assets/images/admin/cta_school.jpg';
}

// ---------------------------------------------------------------------
// 1) ENTRY GATE
// ---------------------------------------------------------------------
class AdminEntryGate extends StatefulWidget {
  const AdminEntryGate({super.key});

  @override
  State<AdminEntryGate> createState() => _AdminEntryGateState();
}

class _AdminEntryGateState extends State<AdminEntryGate> {
  bool _checking = true;
  bool _wasReady = false;

  @override
  void initState() {
    super.initState();
    AdminState.instance.addListener(_onAdminState);
    _restore();
  }

  @override
  void dispose() {
    AdminState.instance.removeListener(_onAdminState);
    super.dispose();
  }

  /// Login screen वरून login झालं की (ready false -> true) मधला login
  /// route काढून टाकतो, म्हणजे Admin panel मोकळा दिसतो.
  /// फक्त बदलाच्या क्षणी चालतो; नाहीतर panel मधले dialogs बंद झाले असते.
  void _onAdminState() {
    final ready = AdminState.instance.ready;
    if (ready && !_wasReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _wasReady = ready;
  }

  Future<void> _restore() async {
    try {
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user != null) {
        final err = await AdminState.instance.startSession();
        if (err != null) await AdminState.instance.logout();
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AdminColors.pageBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) => AdminState.instance.ready
          ? AppConfig.homeBuilder()
          : const AdminLandingScreen(),
    );
  }
}

// ---------------------------------------------------------------------
// 2) LANDING SCREEN
// ---------------------------------------------------------------------
class AdminLandingScreen extends StatefulWidget {
  const AdminLandingScreen({super.key});

  @override
  State<AdminLandingScreen> createState() => _AdminLandingScreenState();
}

class _AdminLandingScreenState extends State<AdminLandingScreen> {
  final ScrollController _scroll = ScrollController();

  final GlobalKey _howKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _modulesKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();

  int _active = 0;

  // Navbar च्या क्रमानुसार (page वरचा क्रमही हाच आहे)
  static const _navLabels = [
    'Home',
    'How It Works',
    'Features',
    'Modules',
    'About',
  ];

  List<GlobalKey?> get _keys =>
      [null, _howKey, _featuresKey, _modulesKey, _aboutKey];

  // ---------- data ----------
  static const _features = [
    (Icons.fact_check_rounded, 'Attendance', 'Daily class-wise records'),
    (Icons.payments_rounded, 'Fees', 'Dues, receipts and reports'),
    (Icons.campaign_rounded, 'Circulars', 'Notices to every family'),
    (Icons.forum_rounded, 'Messages', 'Teacher and parent chats'),
  ];

  static const _steps = [
    (
    Icons.meeting_room_rounded,
    'Add Classes',
    'Create each class with its school name.',
    ),
    (
    Icons.badge_rounded,
    'Approve Teachers',
    'Review new teacher sign-ups and assign classes.',
    ),
    (
    Icons.child_care_rounded,
    'Add Students',
    'Enter the parent email and the parent links automatically.',
    ),
    (
    Icons.insights_rounded,
    'Monitor & Report',
    'Track attendance, fees and export reports.',
    ),
  ];

  static const _checks = [
    "Review and correct daily attendance for every class",
    'See pending fees, paid fees and receipts together',
    'Approve teachers and manage parent logins in one place',
  ];

  static final _modules = [
    (Icons.meeting_room_rounded, 'Classes', 'Add classes, assign teachers',
    AdminColors.blue, AdminColors.blueLight),
    (Icons.badge_rounded, 'Teachers', 'Approve and manage staff',
    AdminColors.purple, AdminColors.purpleLight),
    (Icons.child_care_rounded, 'Students', 'Records and parent email',
    AdminColors.orange, AdminColors.orangeLight),
    (Icons.family_restroom_rounded, 'Parents', 'Linked parent logins',
    AdminColors.green, AdminColors.greenLight),
    (Icons.fact_check_rounded, 'Attendance', 'Review and correct daily',
    AppColors.primary, AppColors.primaryLight),
    (Icons.payments_rounded, 'Fees', 'Dues, paid and receipts',
    AdminColors.orange, AdminColors.orangeLight),
    (Icons.campaign_rounded, 'Circulars', 'Send notices to classes',
    AdminColors.red, AdminColors.redLight),
    (Icons.menu_book_rounded, 'Diary', 'Daily class diary',
    AdminColors.blue, AdminColors.blueLight),
    (Icons.photo_library_rounded, 'Photos', 'Class photo gallery',
    AdminColors.purple, AdminColors.purpleLight),
    (Icons.bar_chart_rounded, 'Reports', 'Export CSV reports',
    AppColors.primary, AppColors.primaryLight),
  ];

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll करताना navbar मधला कोणता link "active" ते ठरवतो.
  void _onScroll() {
    var active = 0;
    final keys = _keys;
    for (var i = 1; i < keys.length; i++) {
      final ctx = keys[i]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy <= 170) active = i;
    }
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 4) {
      active = keys.length - 1;
    }
    if (active != _active && mounted) setState(() => _active = active);
  }

  void _goTo(int i) {
    if (i == 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final ctx = _keys[i]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _LoginRoute()),
    );
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final wide = w >= 900;
          final compact = w < 600;
          return Column(
            children: [
              _navBar(wide, compact),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      _hero(wide, compact),
                      // Strip hero वर थोडी "तरंगते" (फक्त wide वर)
                      Transform.translate(
                        offset: Offset(0, wide ? -46 : 0),
                        child: _strip(wide, compact),
                      ),
                      _howSection(wide, compact),
                      _insightsSection(wide, compact),
                      _modulesSection(w, compact),
                      _ctaSection(compact),
                      _footer(compact),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =================================================================
  // NAVBAR
  // =================================================================
  Widget _navBar(bool wide, bool compact) {
    final pad = compact ? 16.0 : 32.0;
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: AdminColors.border)),
        boxShadow: [
          BoxShadow(
            color: AdminColors.dark.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              children: [
                _logo(),
                const Spacer(),
                if (wide) ...[
                  for (var i = 0; i < _navLabels.length; i++) _navLink(i),
                  const SizedBox(width: 18),
                ],
                ElevatedButton(
                  onPressed: _openLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    compact ? 'Login' : 'Admin Login',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!wide)
                  PopupMenuButton<int>(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu_rounded,
                        color: AdminColors.dark),
                    onSelected: _goTo,
                    itemBuilder: (_) => [
                      for (var i = 0; i < _navLabels.length; i++)
                        PopupMenuItem<int>(
                          value: i,
                          child: Text(_navLabels[i]),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo({bool light = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AdminColors.primary, Color(0xFF263D78)],
            ),
          ),
          child: const Icon(Icons.child_care_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          'Little Steps',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: light ? Colors.white : AdminColors.dark,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withOpacity(.16)
                : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'ADMIN',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
              color: light ? Colors.white : AdminColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _navLink(int i) {
    final active = _active == i;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _goTo(i),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Container(
            padding: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AdminColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              _navLabels[i],
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: active ? AdminColors.primary : AdminColors.dark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =================================================================
  // HERO
  // =================================================================
  Widget _heroText(bool wide, bool compact) {
    final headSize = wide ? 52.0 : (compact ? 32.0 : 42.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SCHOOL MANAGEMENT PANEL',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: AdminColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: headSize,
              height: 1.08,
              fontWeight: FontWeight.w900,
              color: AdminColors.dark,
            ),
            children: const [
              TextSpan(text: 'Manage Your School\nwith '),
              TextSpan(
                text: 'One Clear View',
                style: TextStyle(color: AdminColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: const Text(
            'Classes, teachers, students, attendance, fees and notices - '
                'everything your school does every day, organised in one '
                'secure web panel.',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.55,
              color: AdminColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _openLogin,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Admin Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _goTo(1),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 19),
              label: const Text('See How It Works'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminColors.dark,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AdminColors.border),
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Works with',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AdminColors.muted,
              ),
            ),
            _appChip(Icons.badge_rounded, 'Teacher App'),
            _appChip(Icons.family_restroom_rounded, 'Parent App'),
          ],
        ),
      ],
    );
  }

  Widget _appChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.dark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: AdminColors.dark.withOpacity(.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AdminColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_done_rounded,
                color: AdminColors.green, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'REAL-TIME SYNC',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AdminColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Live data',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AdminColors.dark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Secure',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hero(bool wide, bool compact) {
    final pad = compact ? 20.0 : 32.0;

    if (!wide) {
      // Mobile / tablet: वर फोटो (खाली पांढऱ्यात विरघळतो), त्याखाली मजकूर.
      return Column(
        children: [
          SizedBox(
            height: compact ? 210 : 290,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _Photo(_Img.hero),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(0), Colors.white],
                      stops: const [.45, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _heroText(false, compact),
            ),
          ),
        ],
      );
    }

    // Desktop: फोटो उजवीकडे, डावीकडून पांढऱ्या रंगात विरघळतो.
    return SizedBox(
      height: 590,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _Photo(_Img.hero, alignment: Alignment.centerRight),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withOpacity(0),
                ],
                stops: const [0, .40, .74],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: 540, child: _heroText(true, false)),
                    ),
                    Positioned(right: 0, bottom: 78, child: _liveCard()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // FEATURE STRIP (4 कप्पे)
  // =================================================================
  Widget _strip(bool wide, bool compact) {
    final pad = compact ? 20.0 : 32.0;
    final cells = [
      for (final f in _features) _FeatureCell(f.$1, f.$2, f.$3),
    ];

    Widget divider() => Container(width: 1, color: AdminColors.border);

    final Widget body;
    if (wide) {
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              Expanded(child: cells[i]),
              if (i < cells.length - 1) divider(),
            ],
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cells[0]),
                divider(),
                Expanded(child: cells[1]),
              ],
            ),
          ),
          Container(height: 1, color: AdminColors.border),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cells[2]),
                divider(),
                Expanded(child: cells[3]),
              ],
            ),
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000 + 64),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AdminColors.border),
              boxShadow: [
                BoxShadow(
                  color: AdminColors.dark.withOpacity(.08),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: body,
          ),
        ),
      ),
    );
  }

  // =================================================================
  // GENERIC SECTION WRAPPER + HEADINGS
  // =================================================================
  Widget _section({
    Key? key,
    Color? color,
    required bool compact,
    required Widget child,
    double top = 72,
    double bottom = 72,
  }) {
    final pad = compact ? 20.0 : 32.0;
    final k = compact ? .7 : 1.0;
    return Container(
      key: key,
      width: double.infinity,
      color: color,
      padding: EdgeInsets.only(top: top * k, bottom: bottom * k),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle, bool compact) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 26 : 34,
            fontWeight: FontWeight.w900,
            color: AdminColors.dark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AdminColors.muted,
          ),
        ),
      ],
    );
  }

  // =================================================================
  // HOW IT WORKS
  // =================================================================
  Widget _howSection(bool wide, bool compact) {
    return _section(
      key: _howKey,
      compact: compact,
      top: 56,
      child: Column(
        children: [
          _heading(
            'How Little Steps Works',
            'From a new class to a full school report in 4 simple steps',
            compact,
          ),
          SizedBox(height: compact ? 30 : 48),
          if (wide) _stepsWide() else _stepsNarrow(),
        ],
      ),
    );
  }

  Widget _stepCircle(IconData icon, double size) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AdminColors.greenLight,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withOpacity(.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: AdminColors.primary, size: size * .42),
    );
  }

  Widget _stepsWide() {
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            // circles च्या मागे dashed रेषा (circle opaque असल्याने रेषा मधे लपते)
            Positioned(
              top: 37,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: c.maxWidth / 8),
                child: SizedBox(
                  height: 2,
                  child: CustomPaint(
                    painter: _DashedLinePainter(
                      AdminColors.primary.withOpacity(.55),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          _stepCircle(_steps[i].$1, 76),
                          const SizedBox(height: 16),
                          Text(
                            '${i + 1}. ${_steps[i].$2}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.dark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _steps[i].$3,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AdminColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _stepsNarrow() {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepCircle(_steps[i].$1, 58),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${_steps[i].$2}',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: AdminColors.dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _steps[i].$3,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // =================================================================
  // INSIGHTS (फोटो + मजकूर)
  // =================================================================
  Widget _insightsSection(bool wide, bool compact) {
    final image = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminColors.dark.withOpacity(.16),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: const AspectRatio(
        aspectRatio: 1919 / 945, // insights_dashboard.png चं खरं प्रमाण
        child: _Photo(
          _Img.dashboard,
          alignment: Alignment.topLeft,
          icon: Icons.space_dashboard_rounded,
        ),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADMIN DASHBOARD',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: AdminColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'See Your School at a Glance',
          style: TextStyle(
            fontSize: compact ? 26 : 34,
            height: 1.12,
            fontWeight: FontWeight.w900,
            color: AdminColors.dark,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Every class, every teacher and every family update turns into '
              'simple cards and numbers, so you always know what needs your '
              'attention next.',
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AdminColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        for (final t in _checks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.check_circle_outline_rounded,
                      size: 21, color: AdminColors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _openLogin,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Open Admin Panel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );

    return _section(
      key: _featuresKey,
      color: const Color(0xFFEAF5F1),
      compact: compact,
      child: wide
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 11, child: image),
          const SizedBox(width: 60),
          Expanded(flex: 10, child: text),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          const SizedBox(height: 32),
          text,
        ],
      ),
    );
  }

  // =================================================================
  // MODULES GRID
  // =================================================================
  Widget _modulesSection(double w, bool compact) {
    final cols = w >= 900 ? 5 : (w >= 600 ? 3 : 2);
    const gap = 16.0;
    return _section(
      key: _modulesKey,
      compact: compact,
      child: Column(
        children: [
          _heading(
            'Everything You Manage',
            '${_modules.length} modules, one secure panel',
            compact,
          ),
          SizedBox(height: compact ? 26 : 40),
          LayoutBuilder(
            builder: (context, c) {
              final tileW =
              ((c.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final m in _modules)
                    _ModuleTile(
                      width: tileW,
                      icon: m.$1,
                      title: m.$2,
                      subtitle: m.$3,
                      color: m.$4,
                      light: m.$5,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =================================================================
  // CTA BAND
  // =================================================================
  Widget _ctaSection(bool compact) {
    return Container(
      key: _aboutKey,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(child: _Photo(_Img.cta)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1F5E52).withOpacity(.80),
                    const Color(0xFF263D78).withOpacity(.74),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 32,
              vertical: compact ? 52 : 80,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ready to run your school the easy way?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 26 : 36,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sign in with your administrator account to manage '
                          'classes, teachers, students, fees and notices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.55,
                        color: Colors.white.withOpacity(.85),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _openLogin,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Admin Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AdminColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 19),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // FOOTER
  // =================================================================
  Widget _footer(bool compact) {
    final year = DateTime.now().year;
    final left = _logo(light: true);
    final mid = Text(
      '© $year Little Steps. All rights reserved.',
      style: TextStyle(
        fontSize: 12.5,
        color: Colors.white.withOpacity(.7),
      ),
    );
    final right = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 14, color: Colors.white.withOpacity(.7)),
        const SizedBox(width: 6),
        Text(
          'Authorised administrators only',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withOpacity(.7),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      color: const Color(0xFF16222B),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 32,
        vertical: 26,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: compact
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 14),
              mid,
              const SizedBox(height: 8),
              right,
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [left, mid, right],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// LOGIN ROUTE  (Landing वरून उघडतं; वर "Back to home" बटण)
// =====================================================================
class _LoginRoute extends StatelessWidget {
  const _LoginRoute();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AdminLoginScreen(),
        Positioned(
          top: 14,
          left: 14,
          child: SafeArea(
            child: Material(
              color: Colors.white,
              elevation: 2,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          size: 18, color: AdminColors.dark),
                      SizedBox(width: 6),
                      Text(
                        'Back to home',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// SMALL WIDGETS
// =====================================================================

/// फोटो दाखवतो; सापडला नाही तर सुंदर gradient + icon (app crash होत नाही).
class _Photo extends StatelessWidget {
  const _Photo(
      this.asset, {
        this.alignment = Alignment.center,
        this.icon = Icons.school_rounded,
      });

  final String asset;
  final Alignment alignment;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, Color(0xFFBFE3D9)],
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 80,
            color: AdminColors.primary.withOpacity(.35),
          ),
        ),
      ),
    );
  }
}

class _FeatureCell extends StatelessWidget {
  const _FeatureCell(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: const BoxDecoration(
              color: AdminColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AdminColors.primary, size: 23),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: AdminColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.2,
              height: 1.4,
              color: AdminColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.light,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 156,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: light.withOpacity(.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: light),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: AdminColors.dark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: AdminColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 7, size.width), size.height / 2),
        paint,
      );
      x += 13;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}