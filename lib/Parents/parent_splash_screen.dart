import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'parent_login_screen.dart';

/// Splash screen for the PARENT app only.
/// (Teacher app keeps using lib/screens/splash_screen.dart)
///
/// Put this file at: lib/Parents/parent_splash_screen.dart
class ParentSplashScreen extends StatefulWidget {
  const ParentSplashScreen({super.key});

  @override
  State<ParentSplashScreen> createState() => _ParentSplashScreenState();
}

class _ParentSplashScreenState extends State<ParentSplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Must be listed under assets in pubspec.yaml.
  static const String heroAsset = 'assets/images/parent_splash_pencil.png';

  // Width / height of the transparent PNG (1200 x 653).
  static const double heroAspect = 1200 / 653;

  // ---- Light-blue palette (same as ParentLoginScreen) ----
  static const Color dark = Color(0xFF14375A);
  static const Color primary = Color(0xFF2B8FDB);
  static const Color primaryLight = Color(0xFF4FB3F2);
  static const Color muted = Color(0xFF6B8399);
  static const Color gold = Color(0xFFF2B233);
  static const Color pageBg = Color(0xFFF2F9FF);

  // Total time the splash stays on screen.
  static const Duration splashTime = Duration(milliseconds: 4300);

  late final AnimationController _scene; // entrance (plays once)
  late final AnimationController _float; // gentle up/down loop
  late final AnimationController _twinkle; // stars blinking loop
  late final AnimationController _loading; // progress bar + navigation

  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroTilt;
  late final Animation<double> _trailOpacity;
  late final Animation<double> _bottomOpacity;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // IMPORTANT: AnimationBehavior.preserve makes the animation ALWAYS run
    // for its full time. Without it, when the phone has "Remove animations" /
    // battery-saver turned on, Flutter plays forward() animations almost
    // instantly (the pencil just appears) while repeat() loops (the slow
    // up/down) still move. That is exactly the bug of "only slow up and down".
    _scene = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
      animationBehavior: AnimationBehavior.preserve,
    );

    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
      animationBehavior: AnimationBehavior.preserve,
    )..repeat(reverse: true);

    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      animationBehavior: AnimationBehavior.preserve,
    )..repeat();

    _loading = AnimationController(
      vsync: this,
      duration: splashTime,
      animationBehavior: AnimationBehavior.preserve,
    );

    // --- Top brand + titles ---
    _brandOpacity = CurvedAnimation(
      parent: _scene,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, -.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
    ));
    _titleOpacity = CurvedAnimation(
      parent: _scene,
      curve: const Interval(.12, .4, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, .25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(.12, .42, curve: Curves.easeOutCubic),
    ));

    // --- Pencil rocket flies in from the bottom-left ---
    const heroCurveStart = .18;
    _heroFade = CurvedAnimation(
      parent: _scene,
      curve: const Interval(heroCurveStart, .45, curve: Curves.easeIn),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(-1.1, .45),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(heroCurveStart, .8, curve: Curves.easeOutCubic),
    ));
    _heroScale = Tween<double>(begin: .55, end: 1.0).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(heroCurveStart, .88, curve: Curves.easeOutBack),
    ));
    _heroTilt = Tween<double>(begin: -.22, end: 0.0).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(heroCurveStart, .9, curve: Curves.easeOutCubic),
    ));
    // Speed lines behind the pencil (fade in, then disappear).
    _trailOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _scene,
      curve: const Interval(heroCurveStart, .85),
    ));

    _bottomOpacity = CurvedAnimation(
      parent: _scene,
      curve: const Interval(.6, 1.0, curve: Curves.easeOut),
    );
  }

  bool _started = false;
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Load + decode the picture BEFORE the entrance animation starts, so the
    // flying-in is never skipped or janky while the image is still loading.
    precacheImage(const AssetImage(heroAsset), context, onError: (_, __) {})
        .timeout(const Duration(milliseconds: 1200), onTimeout: () {})
        .catchError((_) {})
        .whenComplete(() {
      if (!mounted) return;
      // Wait one frame so the first frame is already on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    });
  }

  /// Plays the whole splash from the beginning (entrance + progress bar).
  void _play() {
    if (!mounted || _gone) return;
    _scene.forward(from: 0);
    _loading.forward(from: 0).whenComplete(_goNext);
  }

  /// If the app is sent to background and opened again while the splash is
  /// still showing, play the entrance animation again from the start.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _started && !_gone) {
      _play();
    }
  }

  /// Debug only: hot reload keeps old state, so restart the animation.
  @override
  void reassemble() {
    super.reassemble();
    if (_started && !_gone) _play();
  }

  Future<void> _goNext() async {
    if (!mounted || _gone) return;
    _gone = true;
    // आधी login केलेला असेल तर थेट home, नाहीतर login screen.
    final loggedIn = await AuthService.restoreSession('parent');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) =>
        loggedIn ? AppConfig.homeBuilder() : const ParentLoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scene.dispose();
    _float.dispose();
    _twinkle.dispose();
    _loading.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _star(double left, double top, double size, Color color,
      double phase) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (context, child) {
          final t = (_twinkle.value + phase) % 1.0;
          final wave = (math.sin(t * math.pi * 2) + 1) / 2; // 0..1
          return Opacity(
            opacity: .35 + .65 * wave,
            child: Transform.scale(
              scale: .75 + .45 * wave,
              child: Transform.rotate(angle: wave * .5, child: child),
            ),
          );
        },
        child: _Sparkle(size: size, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: pageBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: Stack(
          children: [
            // Background gradient (same family as Login screen).
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFCDE9FB), pageBg],
                  ),
                ),
              ),
            ),

            // Soft floating orbs.
            AnimatedBuilder(
              animation: _float,
              builder: (context, _) {
                final dy = (_float.value - .5) * 16;
                return Stack(
                  children: [
                    Positioned(
                      left: -70,
                      top: -50 + dy,
                      child: _orb(210, const Color(0x40A8D8F5)),
                    ),
                    Positioned(
                      right: -60,
                      top: screen.height * .17 - dy,
                      child: _orb(220, const Color(0x40A8D8F5)),
                    ),
                    Positioned(
                      left: -40,
                      bottom: screen.height * .08 + dy,
                      child: _orb(150, const Color(0x30A8D8F5)),
                    ),
                  ],
                );
              },
            ),

            // Twinkling stars.
            _star(screen.width * .08, screen.height * .13, 14, gold, 0.0),
            _star(screen.width * .86, screen.height * .10, 16, gold, .3),
            _star(screen.width * .18, screen.height * .36, 9, primaryLight, .55),
            _star(screen.width * .80, screen.height * .40, 11, gold, .8),
            _star(screen.width * .50, screen.height * .06, 8, primaryLight, .15),
            _star(screen.width * .92, screen.height * .66, 9, primaryLight, .45),
            _star(screen.width * .06, screen.height * .70, 11, gold, .7),

            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: compact ? 14 : 30),

                  // Brand badge.
                  FadeTransition(
                    opacity: _brandOpacity,
                    child: SlideTransition(
                      position: _brandSlide,
                      child: const _BrandMark(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Titles.
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
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
                            'PARENT APP',
                            style: TextStyle(
                              color: primary,
                              fontSize: 13,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Every little step of your child.\nRight in your hands.',
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
                  ),

                  // Hero illustration (boy on flying pencil).
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final maxH = box.maxHeight * .9;
                        final artW = math.min(
                          math.min(screen.width * .92, 440.0),
                          maxH * heroAspect,
                        );
                        final artH = artW / heroAspect;

                        return Center(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_scene, _float]),
                            builder: (context, _) {
                              // Floating once the pencil has landed.
                              final settle = Curves.easeIn.transform(
                                ((_scene.value - .75) / .25).clamp(0.0, 1.0),
                              );
                              final bob = math.sin(_float.value * math.pi) *
                                  9 *
                                  settle;
                              final sway =
                                  (_float.value - .5) * .035 * settle;

                              return SizedBox(
                                width: artW * 1.1,
                                height: artH * 1.25,
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Glow behind the picture.
                                    Opacity(
                                      opacity: _heroFade.value,
                                      child: Container(
                                        width: artW * .95,
                                        height: artW * .95,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Color(0xCCFFFFFF),
                                              Color(0x66B9E0F8),
                                              Color(0x00B9E0F8),
                                            ],
                                            stops: [0.0, 0.55, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Speed lines while the pencil flies in.
                                    Positioned(
                                      left: 0,
                                      bottom: artH * .12,
                                      child: Opacity(
                                        opacity: _trailOpacity.value,
                                        child: _SpeedLines(width: artW * .38),
                                      ),
                                    ),

                                    // Ground shadow that shrinks when pencil rises.
                                    Positioned(
                                      bottom: artH * .02,
                                      child: Opacity(
                                        opacity: _heroFade.value * .8,
                                        child: Container(
                                          width: artW * (.5 - bob.abs() / 160),
                                          height: 10,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(40),
                                            boxShadow: [
                                              BoxShadow(
                                                color: dark.withValues(
                                                    alpha: .22),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // The picture itself.
                                    FractionalTranslation(
                                      translation: _heroSlide.value,
                                      child: Opacity(
                                        opacity: _heroFade.value,
                                        child: Transform.translate(
                                          offset: Offset(0, -bob),
                                          child: Transform.rotate(
                                            angle: _heroTilt.value + sway,
                                            child: Transform.scale(
                                              scale: _heroScale.value,
                                              child: Image.asset(
                                                heroAsset,
                                                width: artW,
                                                height: artH,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) =>
                                                const _FallbackHero(),
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

                  // Progress bar + footer.
                  FadeTransition(
                    opacity: _bottomOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _loading,
                            builder: (context, _) => Container(
                              width: 154,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD3E6F5),
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
                                          color: Color(0x332B8FDB),
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
                            'Getting things ready for you...',
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1C14375A),
          blurRadius: 24,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: const Icon(
      Icons.family_restroom_rounded,
      size: 43,
      color: Color(0xFF14375A),
    ),
  );
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: const [
      SizedBox(width: 25, child: Divider(color: Color(0xFF8EC6EC))),
      SizedBox(width: 9),
      Text(
        'LEARN  •  GROW  •  EXCEL',
        style: TextStyle(
          color: Color(0xFF4F7391),
          fontSize: 10,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(width: 9),
      SizedBox(width: 25, child: Divider(color: Color(0xFF8EC6EC))),
    ],
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      SizedBox(width: 25, child: Divider(color: Color(0xFFB3D4EC))),
      SizedBox(width: 9),
      Text(
        'POWERED BY ',
        style: TextStyle(
          fontSize: 9.5,
          color: Color(0xFF7D92A6),
          letterSpacing: 1.1,
        ),
      ),
      Text(
        'SMART SCHOOL',
        style: TextStyle(
          fontSize: 9.5,
          color: Color(0xFF14375A),
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      ),
      SizedBox(width: 9),
      SizedBox(width: 25, child: Divider(color: Color(0xFFB3D4EC))),
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

/// Three little "whoosh" lines shown behind the pencil while it flies in.
class _SpeedLines extends StatelessWidget {
  const _SpeedLines({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget line(double w, double opacity) => Container(
      width: w,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            const Color(0x004FB3F2),
            const Color(0xFF4FB3F2).withValues(alpha: opacity),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(width, .55),
        line(width * .7, .4),
        line(width * .85, .5),
      ],
    );
  }
}

class _FallbackHero extends StatelessWidget {
  const _FallbackHero();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.edit_rounded,
    size: 160,
    color: Color(0xFFF2B233),
  );
}