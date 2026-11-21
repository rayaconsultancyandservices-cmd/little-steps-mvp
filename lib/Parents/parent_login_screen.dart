import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';

/// Login screen for the PARENT app only (light-blue theme).
/// (Teacher app keeps using lib/screens/login_screen.dart)
///
/// Put this file at: lib/Parents/parent_login_screen.dart
class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  // Must be listed under assets in pubspec.yaml.
  static const String heroAsset = 'assets/images/parent_splash_pencil.png';
  // Width / height of the transparent PNG (1200 x 653).
  static const double heroAspect = 1200 / 653;

  // ---- Light-blue palette (same as ParentSplashScreen) ----
  static const Color dark = Color(0xFF14375A);
  static const Color primary = Color(0xFF2B8FDB);
  static const Color primaryLight = Color(0xFF4FB3F2);
  static const Color muted = Color(0xFF6B8399);
  static const Color gold = Color(0xFFF2B233);
  static const Color pageBg = Color(0xFFF2F9FF);
  static const Color fieldFill = Color(0xFFF3F9FE);
  static const Color fieldBorder = Color(0xFFD3E6F5);

  late final AnimationController _intro; // entrance (plays once)
  late final AnimationController _float; // hero bobbing loop
  late final AnimationController _twinkle; // stars loop

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, .35, curve: Curves.easeOut),
    );
    _heroFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(.05, .45, curve: Curves.easeIn),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(.9, -.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(.05, .7, curve: Curves.easeOutBack),
    ));
    _cardFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(.3, .75, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, .18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(.3, .85, curve: Curves.easeOutCubic),
    ));
    _footerFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(.7, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    _twinkle.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  void login() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Demo login. Firebase Authentication is not connected yet.
    setState(() => isLoading = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo Parent Login Successful!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Opens this APK's own home screen (AppConfig.homeBuilder).
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AppConfig.homeBuilder()),
      );
    });
  }

  void forgotPassword() {
    _snack('Password reset needs Firebase integration.');
  }

  void googleLogin() {
    _snack('Google sign-in needs Firebase integration.');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------
  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF7D92A6), fontSize: 14),
      prefixIcon: Icon(icon, color: primary, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: fieldFill,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(fieldBorder),
      enabledBorder: border(fieldBorder),
      focusedBorder: border(primary, 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.5),
      errorStyle: const TextStyle(fontSize: 10.5, height: 1.1),
    );
  }

  Widget _circle(double size, Color color) => Container(
    height: size,
    width: size,
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
          final wave = (math.sin(t * math.pi * 2) + 1) / 2;
          return Opacity(
            opacity: .35 + .65 * wave,
            child: Transform.scale(
              scale: .75 + .45 * wave,
              child: Transform.rotate(angle: wave * .5, child: child),
            ),
          );
        },
        child: Icon(
          Icons.star_rounded,
          size: size,
          color: color,
          shadows: const [Shadow(color: Color(0x55FFFFFF), blurRadius: 5)],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

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
            // Background gradient.
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

            // Soft floating circles.
            AnimatedBuilder(
              animation: _float,
              builder: (context, _) {
                final dy = (_float.value - .5) * 14;
                return Stack(
                  children: [
                    Positioned(
                      left: -70,
                      top: -50 + dy,
                      child: _circle(210, const Color(0x40A8D8F5)),
                    ),
                    Positioned(
                      right: -60,
                      top: screen.height * .22 - dy,
                      child: _circle(200, const Color(0x40A8D8F5)),
                    ),
                    Positioned(
                      left: -50,
                      bottom: 40 + dy,
                      child: _circle(150, const Color(0x30A8D8F5)),
                    ),
                  ],
                );
              },
            ),

            // Twinkling stars.
            _star(screen.width * .08, screen.height * .08, 13, gold, 0.0),
            _star(screen.width * .90, screen.height * .07, 15, gold, .3),
            _star(screen.width * .20, screen.height * .30, 9, primaryLight, .55),
            _star(screen.width * .93, screen.height * .36, 10, gold, .8),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heroW = math.min(screen.width * .78, 330.0);
                  final heroH = heroW / heroAspect;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            // ----- Title -----
                            FadeTransition(
                              opacity: _titleFade,
                              child: Column(
                                children: const [
                                  Text(
                                    'Smart School',
                                    style: TextStyle(
                                      fontSize: 26,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.5,
                                      color: dark,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'PARENT APP',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 12.5,
                                      letterSpacing: 2.4,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ----- Hero picture (floating) -----
                            const SizedBox(height: 6),
                            SlideTransition(
                              position: _heroSlide,
                              child: FadeTransition(
                                opacity: _heroFade,
                                child: AnimatedBuilder(
                                  animation: _float,
                                  builder: (context, child) {
                                    final bob =
                                        math.sin(_float.value * math.pi) * 7;
                                    final sway = (_float.value - .5) * .03;
                                    return Transform.translate(
                                      offset: Offset(0, -bob),
                                      child: Transform.rotate(
                                        angle: sway,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    heroAsset,
                                    width: heroW,
                                    height: heroH,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.edit_rounded,
                                      size: 110,
                                      color: gold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ----- Login card -----
                            FadeTransition(
                              opacity: _cardFade,
                              child: SlideTransition(
                                position: _cardSlide,
                                child: _buildCard(),
                              ),
                            ),

                            const SizedBox(height: 18),
                            FadeTransition(
                              opacity: _footerFade,
                              child: const _PoweredBy(),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3F0FA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2B8FDB),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: dark,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sign in to continue as Parent',
              style: TextStyle(
                fontSize: 13,
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            // Email
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 14.5, color: dark),
              decoration: fieldDecoration(
                hint: 'Email Address',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty || !text.contains('@') || !text.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 13),

            // Password
            TextFormField(
              controller: passwordController,
              obscureText: hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => login(),
              style: const TextStyle(fontSize: 14.5, color: dark),
              decoration: fieldDecoration(
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  splashRadius: 20,
                  onPressed: () =>
                      setState(() => hidePassword = !hidePassword),
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: muted,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Remember me + Forgot password
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: rememberMe,
                    activeColor: primary,
                    side: const BorderSide(color: Color(0xFFA9C7DF), width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (v) => setState(() => rememberMe = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember Me',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sign In button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primary, primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x442B8FDB),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isLoading
                        ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                        : Row(
                      key: const ValueKey('label'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            size: 19, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Divider "or"
            Row(
              children: const [
                Expanded(child: Divider(color: Color(0xFFD3E6F5))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7D92A6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFD3E6F5))),
              ],
            ),
            const SizedBox(height: 14),

            // Google button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: googleLogin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: dark,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD3E6F5), width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'G',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Info note (parent accounts are created by the school)
            Center(
              child: Text(
                'Parent account is created by the school office.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: muted.withValues(alpha: .95),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

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