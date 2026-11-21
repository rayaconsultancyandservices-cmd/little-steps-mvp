import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  // Role आता APK नुसार ठरतो (main_teacher / main_parent मधून).
  final bool isParent = AppConfig.isParent;

  // Animations
  late final AnimationController _introController; // card entrance

  // Image used on this screen (must be listed under assets in pubspec.yaml)
  static const String heroImage = 'assets/images/teacher_logo.png';
  // Width / height of the cropped, transparent books image (1137 x 976)
  static const double heroAspect = 1137 / 976;

  // Smart School palette (same teal colours as the Home screen)
  static const Color dark = Color(0xFF183B45);
  static const Color primary = Color(0xFF168C80);
  static const Color primaryLight = Color(0xFF1FA896);
  static const Color fieldFill = Color(0xFFF4F9F8);
  static const Color fieldBorder = Color(0xFFD4E5E1);
  static const Color muted = Color(0xFF6C807C);
  static const Color gold = Color(0xFFF2B233);
  static const Color pageBg = Color(0xFFF3F8F7);

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
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
        SnackBar(
          content: Text(
            isParent
                ? 'Demo Parent Login Successful!'
                : 'Demo Teacher Login Successful!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // या APK चा स्वतःचा home screen उघडतो (AppConfig.homeBuilder).
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
      hintStyle: const TextStyle(color: Color(0xFF7E918D), fontSize: 14),
      prefixIcon: Icon(icon, color: primary, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(fieldBorder),
      enabledBorder: border(fieldBorder),
      focusedBorder: border(primary, 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.5),
      errorStyle: const TextStyle(fontSize: 10.5, height: 1.1),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Fits one screen on normal phones; scrolls only on very small
            // screens or when the keyboard is open.
            final minH = 750.0 + safeTop + safeBottom;
            final contentH = math.max(constraints.maxHeight, minH);
            final extra = contentH - minH;

            // ----- Login card position -----
            final cardTop = safeTop + 300 + extra * 0.45;

            // ----- Books image (right side of the Teacher App text) -----
            // Fixed size, no animation. Kept small enough that its top edge
            // stays BELOW the "Learn • Grow • Excel" line of the brand.
            final imgW = (constraints.maxWidth * 0.42).clamp(130.0, 162.0);
            final imgH = imgW / heroAspect;
            // The top edge stays where it was (below the tagline line);
            // the bigger image grows downward onto the wave.
            final baseW = (constraints.maxWidth * 0.36).clamp(115.0, 145.0);
            // Raise this number to move the books UP, lower it to move them DOWN.
            const imgLift = 18.0;
            final imgTop = cardTop - 32 - baseW / heroAspect - imgLift;
            const imgRight = 14.0;

            // ----- Teacher App text (left side) -----
            final textTop = imgTop + 2;
            final textWidth = constraints.maxWidth - imgW - imgRight - 24 - 6;

            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              child: SizedBox(
                height: contentH,
                width: double.infinity,
                child: Stack(
                  children: [
                    // ---------- BACKGROUND ----------
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFCDEDE5), pageBg],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -70,
                      top: -50,
                      child: _circle(210, const Color(0x40A5DCCF)),
                    ),
                    Positioned(
                      right: -60,
                      top: 40,
                      child: _circle(190, const Color(0x40A5DCCF)),
                    ),

                    // ---------- PAPER PLANE ----------
                    Positioned(
                      left: 22,
                      top: safeTop + 54,
                      child: SizedBox(
                        height: 70,
                        width: 70,
                        child: CustomPaint(
                          painter: _PlaneTrailPainter(),
                          child: Align(
                            alignment: const Alignment(0.7, -0.7),
                            child: Transform.rotate(
                              angle: -0.35,
                              child: const Icon(
                                Icons.send_outlined,
                                size: 26,
                                color: primaryLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ---------- BRAND ----------
                    Positioned(
                      top: safeTop + 4,
                      left: 0,
                      right: 0,
                      child: _buildBrand(),
                    ),

                    // ---------- WAVES ----------
                    Positioned(
                      top: cardTop - 56,
                      left: 0,
                      right: 0,
                      height: 90,
                      child: CustomPaint(painter: _TopWavePainter()),
                    ),
                    Positioned(
                      top: cardTop + 33,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(color: pageBg),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 70 + safeBottom,
                      child: const CustomPaint(painter: _BottomWavePainter()),
                    ),

                    // ---------- SOFT GLOW BEHIND BOOKS ----------
                    Positioned(
                      right: imgRight - imgW * 0.18,
                      top: imgTop - imgH * 0.18,
                      child: IgnorePointer(
                        child: Container(
                          width: imgW * 1.36,
                          height: imgW * 1.36,
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

                    // ---------- GROUND SHADOW UNDER BOOKS ----------
                    Positioned(
                      right: imgRight + imgW * 0.08,
                      top: imgTop + imgH - 6,
                      child: IgnorePointer(
                        child: Container(
                          width: imgW * 0.84,
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: dark.withValues(alpha: 0.28),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ---------- SPARKLES ----------
                    Positioned(
                      right: imgRight + imgW - 6,
                      top: imgTop + 6,
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: gold,
                      ),
                    ),
                    Positioned(
                      right: imgRight - 4,
                      top: imgTop + imgH * 0.42,
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 11,
                        color: primaryLight,
                      ),
                    ),

                    // ---------- BOOKS IMAGE (fixed, no animation) ----------
                    Positioned(
                      right: imgRight,
                      top: imgTop,
                      child: Image.asset(
                        heroImage,
                        width: imgW,
                        height: imgH,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: imgW,
                          height: imgH,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 60,
                            color: primary,
                          ),
                        ),
                      ),
                    ),

                    // ---------- TEACHER APP TEXT ----------
                    Positioned(
                      left: 24,
                      top: textTop,
                      width: textWidth,
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _introController,
                          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isParent ? 'Parent App' : 'Teacher App',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: dark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 3,
                              width: 38,
                              decoration: BoxDecoration(
                                color: gold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              isParent
                                  ? 'See Photos, Diary,\nCirculars and Fees\nof Your Child'
                                  : 'Manage Classes,\nTrack Progress and\nStay Connected',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: dark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ---------- LOGIN CARD ----------
                    Positioned(
                      top: cardTop,
                      left: 22,
                      right: 22,
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _introController,
                          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _introController,
                              curve: const Interval(0.2, 1.0,
                                  curve: Curves.easeOutCubic),
                            ),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _buildCard(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ---------- GOOGLE + REGISTER ----------
                    Positioned(
                      bottom: safeBottom + 40,
                      left: 22,
                      right: 22,
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _introController,
                          curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _buildAlternatives(),
                          ),
                        ),
                      ),
                    ),

                    // ---------- FOOTER ----------
                    Positioned(
                      bottom: safeBottom + 9,
                      left: 0,
                      right: 0,
                      child: const _PoweredBy(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // BRAND
  // ---------------------------------------------------------------
  Widget _buildBrand() {
    return Column(
      children: [
        const Icon(Icons.star_rounded, size: 15, color: gold),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.rotate(
              angle: -0.35,
              child: const Icon(Icons.eco_rounded, size: 30, color: gold),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.auto_stories_rounded, size: 58, color: dark),
            const SizedBox(width: 2),
            Transform.rotate(
              angle: 0.35,
              child: Transform.scale(
                scaleX: -1,
                child: const Icon(Icons.eco_rounded, size: 30, color: gold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Smart School',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: dark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 34, child: Divider(color: dark, thickness: 1)),
            SizedBox(width: 8),
            Text(
              'Learn • Grow • Excel',
              style: TextStyle(
                fontSize: 12,
                color: dark,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 8),
            SizedBox(width: 34, child: Divider(color: dark, thickness: 1)),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // SMALL LOGIN CARD
  // ---------------------------------------------------------------
  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1EEEA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183B45).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF1FA896).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: dark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isParent
                  ? 'Sign in to continue as Parent'
                  : 'Sign in to continue as Teacher',
              style: const TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 12),

            // EMAIL
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              style: const TextStyle(fontSize: 14.5, color: dark),
              decoration: fieldDecoration(
                hint: 'Email Address',
                icon: Icons.person_rounded,
              ),
              validator: (value) {
                if (value == null ||
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: 10),

            // PASSWORD
            TextFormField(
              controller: passwordController,
              obscureText: hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => login(),
              style: const TextStyle(fontSize: 14.5, color: dark),
              decoration: fieldDecoration(
                hint: 'Password',
                icon: Icons.lock_rounded,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => hidePassword = !hidePassword),
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF5F7A76),
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

            const SizedBox(height: 2),

            // REMEMBER + FORGOT
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => rememberMe = !rememberMe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: rememberMe,
                        activeColor: primary,
                        side: const BorderSide(color: primary, width: 1.5),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) =>
                            setState(() => rememberMe = v ?? false),
                      ),
                      const Text(
                        'Remember Me',
                        style: TextStyle(fontSize: 12.5, color: dark),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: forgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 2),

            // LOGIN BUTTON (gradient)
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: isLoading
                      ? const [Color(0xFF8ABCB4), Color(0xFF8ABCB4)]
                      : const [Color(0xFF1FA896), Color(0xFF0E7C73)],
                ),
                boxShadow: isLoading
                    ? null
                    : [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // OR + GOOGLE + REGISTER (below the card)
  // ---------------------------------------------------------------
  Widget _buildAlternatives() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFCFE3DE))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 11.5,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFCFE3DE))),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: googleLogin,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: dark,
              side: const BorderSide(color: primary, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const SweepGradient(
                    colors: [
                      Color(0xFFEA4335),
                      Color(0xFFFBBC05),
                      Color(0xFF34A853),
                      Color(0xFF4285F4),
                      Color(0xFFEA4335),
                    ],
                  ).createShader(rect),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (isParent)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Parent account is created by the school office.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          )
        else
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'New teacher?',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 13,
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// =================================================================
// FOOTER
// =================================================================
class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 40, child: Divider(color: Color(0x99FFFFFF))),
        SizedBox(width: 8),
        Text(
          'Powered by ',
          style: TextStyle(fontSize: 11.5, color: Color(0xE6FFFFFF)),
        ),
        Text(
          'Smart School',
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: 8),
        SizedBox(width: 40, child: Divider(color: Color(0x99FFFFFF))),
      ],
    );
  }
}

// =================================================================
// PAINTERS
// =================================================================
class _TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // deep teal wave
    final deep = Path()
      ..moveTo(0, 28)
      ..cubicTo(w * 0.25, -4, w * 0.55, 58, w, 12)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      deep,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2BB39D), Color(0xFF0E7C73)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // light teal ribbon
    final ribbon = Path()
      ..moveTo(0, 40)
      ..cubicTo(w * 0.28, 12, w * 0.58, 66, w, 26)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(ribbon, Paint()..color = const Color(0xFF9AD9CB));

    // page-colour wave (top edge of the lower area)
    final base = Path()
      ..moveTo(0, 50)
      ..cubicTo(w * 0.3, 24, w * 0.6, 74, w, 38)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(base, Paint()..color = const Color(0xFFF3F8F7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWavePainter extends CustomPainter {
  const _BottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final light = Path()
      ..moveTo(0, 38)
      ..cubicTo(w * 0.3, 8, w * 0.6, 58, w, 22)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(light, Paint()..color = const Color(0xFFD8F0EA));

    final deep = Path()
      ..moveTo(0, 56)
      ..cubicTo(w * 0.3, 36, w * 0.7, 72, w, 46)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      deep,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0E7C73), Color(0xFF2BB39D)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _PlaneTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.65, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.0,
        size.height * 0.35,
        size.width * 0.12,
        size.height * 0.95,
      );

    final paint = Paint()
      ..color = const Color(0xFF1FA896).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}