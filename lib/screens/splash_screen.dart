import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Books illustration (must be listed under assets in pubspec.yaml).
  static const String booksAsset = 'assets/images/smart_school_splash_books.png';

  // Width / height of the books image. Change this if the picture looks
  // stretched or has empty space around it.
  static const double booksAspect = 1.17;

  // ---- Same teal palette as the Login screen ----
  static const Color dark = Color(0xFF183B45);
  static const Color primary = Color(0xFF168C80);
  static const Color primaryLight = Color(0xFF1FA896);
  static const Color muted = Color(0xFF6C807C);
  static const Color gold = Color(0xFFF2B233);
  static const Color pageBg = Color(0xFFF3F8F7);

  static const Duration splashTime = Duration(milliseconds: 4300);

  // The books picture is revealed from the bottom in 4 steps:
  // 1st book, then the 2nd on top, then the 3rd, then the 4th + cap + pencils.
  // Each number = how much of the picture (from the bottom) is visible after
  // that step. Tune these if a step cuts a book in half.
  static const List<double> _stageHeights = [0.0, 0.30, 0.48, 0.66, 1.0];

  late final AnimationController _scene;
  late final AnimationController _loading;

  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();

    _scene = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..forward();

    _loading = AnimationController(vsync: this, duration: splashTime)
      ..forward().whenComplete(_goNext);

    _brandOpacity = CurvedAnimation(
      parent: _scene,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, .18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(0.0, .2, curve: Curves.easeOutCubic),
    ));
    _titleOpacity = CurvedAnimation(
      parent: _scene,
      curve: const Interval(.08, .32, curve: Curves.easeOut),
    );
  }

  Future<void> _goNext() async {
    if (!mounted) return;
    // आधी login केलेला असेल तर थेट home, नाहीतर login screen.
    final loggedIn = await AuthService.restoreSession('teacher');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) =>
        loggedIn ? AppConfig.homeBuilder() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _scene.dispose();
    _loading.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
    ),
  );

  /// How much of the picture (0..1, from the bottom) is visible right now.
  double _revealHeight(double v) {
    // Time slots for the 4 steps (fractions of the 3.4 s scene).
    const starts = [0.10, 0.27, 0.44, 0.61];
    const length = 0.19;

    var h = 0.0;
    for (var i = 0; i < 4; i++) {
      final t = ((v - starts[i]) / length).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final eased = Curves.easeOutBack.transform(t);
      h = _stageHeights[i] +
          (_stageHeights[i + 1] - _stageHeights[i]) * eased;
    }
    return h.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF168C80),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: Stack(
          children: [
            // Same background gradient as the Login screen.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFCDEDE5), pageBg],
                  ),
                ),
              ),
            ),
            Positioned(left: -70, top: -50, child: _orb(210, const Color(0x40A5DCCF))),
            Positioned(right: -60, top: screen.height * .17,
                child: _orb(220, const Color(0x40A5DCCF))),
            Positioned(right: 34, top: screen.height * .12,
                child: const _Sparkle(size: 15, color: gold)),
            Positioned(left: 45, top: screen.height * .2,
                child: const _Sparkle(size: 12, color: gold)),
            Positioned(left: screen.width * .22, top: screen.height * .29,
                child: const _Sparkle(size: 8, color: primaryLight)),

            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: compact ? 14 : 30),
                  FadeTransition(
                    opacity: _brandOpacity,
                    child: SlideTransition(
                      position: _brandSlide,
                      child: const _BrandMark(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: Column(
                      children: const [
                        Text(
                          'Smart School',
                          style: TextStyle(
                            fontSize: 31,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.6,
                            color: dark,
                          ),
                        ),
                        SizedBox(height: 9),
                        _Tagline(),
                        SizedBox(height: 17),
                        Text(
                          'TEACHER APP',
                          style: TextStyle(
                            color: primary,
                            fontSize: 13,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Your classroom. Your progress.\nAll in one place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 15),

                  // Books picture: smaller, and stacked step by step.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Smaller than before (was ~91% of screen width).
                        final maxH = box.maxHeight * .92;
                        final artW = math.min(
                          math.min(screen.width * .62, 245.0),
                          maxH * booksAspect,
                        );
                        final artH = artW / booksAspect;

                        return Center(
                          child: AnimatedBuilder(
                            animation: _scene,
                            builder: (context, _) {
                              final v = _scene.value;
                              final reveal = _revealHeight(v);
                              final fade = Curves.easeIn.transform(
                                ((v - .08) / .14).clamp(0.0, 1.0),
                              );
                              // Gentle float once everything is in place.
                              final floatT = ((v - .82) / .18).clamp(0.0, 1.0);
                              final float =
                                  math.sin(floatT * math.pi * 2) * 3.0;

                              return SizedBox(
                                width: artW * 1.5,
                                height: artH * 1.15,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Soft glow behind the books (like Login).
                                    Positioned(
                                      bottom: -artH * .1,
                                      child: Opacity(
                                        opacity: fade,
                                        child: Container(
                                          width: artW * 1.35,
                                          height: artW * 1.0,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                Color(0xCCFFFFFF),
                                                Color(0x66B5E8DC),
                                                Color(0x00B5E8DC),
                                              ],
                                              stops: [0.0, 0.55, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Ground shadow under the books.
                                    Positioned(
                                      bottom: -4,
                                      child: Opacity(
                                        opacity: fade * .9,
                                        child: Container(
                                          width: artW * .8,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(40),
                                            boxShadow: [
                                              BoxShadow(
                                                color: dark
                                                    .withOpacity(.28),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // The books, revealed from the bottom up.
                                    Positioned(
                                      bottom: 0,
                                      child: Opacity(
                                        opacity: fade,
                                        child: Transform.translate(
                                          offset: Offset(0, float),
                                          child: SizedBox(
                                            width: artW,
                                            height: artH,
                                            child: ClipRect(
                                              child: Align(
                                                alignment:
                                                Alignment.bottomCenter,
                                                heightFactor:
                                                reveal <= 0 ? 0.001 : reveal,
                                                child: Image.asset(
                                                  booksAsset,
                                                  fit: BoxFit.contain,
                                                  alignment:
                                                  Alignment.bottomCenter,
                                                  width: artW,
                                                  height: artH,
                                                  errorBuilder: (_, __, ___) =>
                                                  const _FallbackBooks(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _loading,
                          builder: (context, _) => Container(
                            width: 154,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4E5E1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _loading.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [primary, primaryLight],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33168C80),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 11),
                        const Text(
                          'Preparing your classroom...',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11.5,
                            letterSpacing: .25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _Footer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.72),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C183B45),
              blurRadius: 24,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_stories_rounded,
          size: 43,
          color: Color(0xFF183B45),
        ),
      ),
    ],
  );
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: const [
      SizedBox(width: 25, child: Divider(color: Color(0xFF8FC9BF))),
      SizedBox(width: 9),
      Text(
        'LEARN  •  GROW  •  EXCEL',
        style: TextStyle(
          color: Color(0xFF4F7A74),
          fontSize: 10,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(width: 9),
      SizedBox(width: 25, child: Divider(color: Color(0xFF8FC9BF))),
    ],
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      SizedBox(width: 25, child: Divider(color: Color(0xFFB5D6CF))),
      SizedBox(width: 9),
      Text('POWERED BY ',
          style: TextStyle(fontSize: 9.5, color: Color(0xFF7E918D),
              letterSpacing: 1.1)),
      Text('SMART SCHOOL',
          style: TextStyle(fontSize: 9.5, color: Color(0xFF183B45),
              fontWeight: FontWeight.w900, letterSpacing: .7)),
      SizedBox(width: 9),
      SizedBox(width: 25, child: Divider(color: Color(0xFFB5D6CF))),
    ],
  );
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.star_rounded,
    size: size,
    color: color,
    shadows: const [Shadow(color: Color(0x55FFFFFF), blurRadius: 5)],
  );
}

class _FallbackBooks extends StatelessWidget {
  const _FallbackBooks();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.menu_book_rounded,
    size: 180,
    color: Color(0xFF168C80),
  );
}