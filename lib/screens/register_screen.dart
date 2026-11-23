import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Field keys (used to scroll to the first field that has an error)
  final _nameKey = GlobalKey<FormFieldState<String>>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _phoneKey = GlobalKey<FormFieldState<String>>();
  final _schoolKey = GlobalKey<FormFieldState<String>>();
  final _employeeKey = GlobalKey<FormFieldState<String>>();
  final _classKey = GlobalKey<FormFieldState<String>>();
  final _passwordKey = GlobalKey<FormFieldState<String>>();
  final _confirmKey = GlobalKey<FormFieldState<String>>();
  final _termsKey = GlobalKey();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final schoolController = TextEditingController();
  final employeeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Same image as the login screen (must be listed under assets in pubspec.yaml)
  static const String heroImage = 'assets/images/teacher_logo.png';
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

  final List<String> classes = const [
    'Nursery A',
    'Nursery B',
    'Junior KG',
    'Senior KG',
  ];

  String? selectedClass;

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool agree = false;
  bool termsError = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    schoolController.dispose();
    employeeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // PASSWORD RULES
  // ---------------------------------------------------------------
  bool get hasMinLength => passwordController.text.length >= 8;
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(passwordController.text);
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(passwordController.text);
  bool get hasSpecial =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(passwordController.text);

  int get passwordStrength {
    if (passwordController.text.isEmpty) return 0;
    int score = 0;
    if (passwordController.text.length >= 6) score++;
    if (hasMinLength) score++;
    if (hasUpper) score++;
    if (hasNumber) score++;
    if (hasSpecial) score++;
    return score;
  }

  String get strengthLabel {
    if (passwordStrength <= 2) return 'Weak';
    if (passwordStrength <= 4) return 'Medium';
    return 'Strong';
  }

  Color get strengthColor {
    if (passwordStrength <= 2) return Colors.redAccent;
    if (passwordStrength <= 4) return Colors.orange;
    return Colors.green;
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  Future<void> registerTeacher() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState!.validate();

    if (!agree) {
      setState(() => termsError = true);
    }

    if (!valid || !agree) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstError();
      });
      return;
    }

    setState(() => isLoading = true);

    // Firebase Authentication मध्ये खरं Teacher account + class बनतो.
    final error = await AuthService.registerTeacher(
      name: nameController.text,
      email: emailController.text,
      phone: phoneController.text,
      school: schoolController.text,
      employeeId: employeeController.text,
      className: selectedClass ?? '',
      password: passwordController.text,
    );
    if (!mounted) return;

    setState(() => isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Account created! You can login after the school Admin approves you.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  void _scrollToFirstError() {
    final keys = <GlobalKey>[
      _nameKey,
      _emailKey,
      _phoneKey,
      _schoolKey,
      _employeeKey,
      _classKey,
      _passwordKey,
      _confirmKey,
    ];

    for (final key in keys) {
      final state = key.currentState;
      if (state is FormFieldState && state.hasError) {
        _ensureVisible(key);
        return;
      }
    }

    if (termsError) _ensureVisible(_termsKey);
  }

  void _ensureVisible(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.25,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _showPolicy(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4E5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: const TextStyle(fontSize: 13, height: 1.6, color: muted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(fieldBorder),
      enabledBorder: border(fieldBorder),
      focusedBorder: border(primary, 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.5),
      errorStyle: const TextStyle(fontSize: 11, height: 1.2),
    );
  }

  Widget _label(String text, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(color: Colors.redAccent, fontSize: 12.5),
            )
          else
            const Text(
              '  (optional)',
              style: TextStyle(color: muted, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1EEEA)),
        boxShadow: [
          BoxShadow(
            color: dark.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: primaryLight.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE4F4F0), Color(0xFFCDEDE5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: dark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _ruleRow(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: ok ? Colors.green : const Color(0xFF9DB0AC),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: ok ? Colors.green.shade700 : muted,
              fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordStrengthWidget() {
    if (passwordController.text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Password strength',
                style: TextStyle(fontSize: 11.5, color: muted),
              ),
              const Spacer(),
              Text(
                strengthLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                  height: 5,
                  decoration: BoxDecoration(
                    color: index < passwordStrength
                        ? strengthColor
                        : const Color(0xFFE1ECE9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          _ruleRow('At least 8 characters', hasMinLength),
          _ruleRow('One uppercase letter (A-Z)', hasUpper),
          _ruleRow('One number (0-9)', hasNumber),
          _ruleRow('One special character (recommended)', hasSpecial),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;
    final width = media.size.width;

    final headerH = safeTop + 250.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(
            children: [
              // ---------- HEADER (gradient, waves, books) ----------
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerH,
                child: _buildHeader(safeTop, width),
              ),

              // ---------- FORM ----------
              Padding(
                padding: EdgeInsets.only(top: headerH - 34),
                child: SizedBox(
                  width: double.infinity,
                  child: _buildBody(safeBottom),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------
  Widget _buildHeader(double safeTop, double width) {
    final imgW = (width * 0.40).clamp(125.0, 165.0);
    final imgH = imgW / heroAspect;
    const imgRight = 12.0;
    final imgTop = safeTop + 64.0;
    final textWidth = width - imgW - imgRight - 22 - 6;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // background gradient
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

        // wave
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 90,
          child: CustomPaint(painter: _TopWavePainter()),
        ),

        // soft glow behind books
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

        // ground shadow
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

        // sparkles
        Positioned(
          right: imgRight + imgW - 6,
          top: imgTop + 6,
          child: const Icon(Icons.auto_awesome_rounded, size: 15, color: gold),
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

        // books image (fixed size, no animation)
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
              child: const Icon(Icons.menu_book_rounded, size: 60, color: primary),
            ),
          ),
        ),

        // title text (left)
        Positioned(
          left: 22,
          top: imgTop + 6,
          width: textWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(
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
              const Text(
                'Join our teaching team and\nmanage your classroom\nwith ease',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: dark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // top bar: back button + brand + chip
        Positioned(
          top: safeTop + 6,
          left: 12,
          right: 14,
          child: Row(
            children: [
              Material(
                color: Colors.white,
                elevation: 3,
                shadowColor: dark.withValues(alpha: 0.25),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    height: 40,
                    width: 40,
                    child: Icon(Icons.arrow_back_rounded, color: dark, size: 22),
                  ),
                ),
              ),
              const Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 22, color: dark),
                    SizedBox(width: 6),
                    Text(
                      'Smart School',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F4EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'NEW ACCOUNT',
                  style: TextStyle(
                    color: primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // BODY (form cards + button + footer)
  // ---------------------------------------------------------------
  Widget _buildBody(double safeBottom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPersonalCard(),
                    const SizedBox(height: 16),
                    _buildSchoolCard(),
                    const SizedBox(height: 16),
                    _buildSecurityCard(),
                    const SizedBox(height: 16),
                    _buildTermsCard(),
                    const SizedBox(height: 18),
                    _buildRegisterButton(),
                    const SizedBox(height: 10),
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // footer wave + powered by
        SizedBox(
          height: 70 + safeBottom,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _BottomWavePainter()),
              ),
              Positioned(
                bottom: safeBottom + 9,
                left: 0,
                right: 0,
                child: const _PoweredBy(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- PERSONAL ----------
  Widget _buildPersonalCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Personal Information',
            'Enter your basic contact details',
            Icons.person_rounded,
          ),
          const SizedBox(height: 18),

          _label('Full Name'),
          TextFormField(
            key: _nameKey,
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            style: const TextStyle(fontSize: 14.5, color: dark),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z .'-]")),
              LengthLimitingTextInputFormatter(40),
            ],
            decoration: fieldDecoration(
              hint: 'Enter your full name',
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Full name is required';
              if (v.length < 3) return 'Name must be at least 3 characters';
              if (!RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(v)) {
                return 'Name can only contain letters and spaces';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          _label('Email Address'),
          TextFormField(
            key: _emailKey,
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(fontSize: 14.5, color: dark),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
            decoration: fieldDecoration(
              hint: 'teacher@gmail.com',
              icon: Icons.email_rounded,
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Email address is required';
              if (!RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
                  .hasMatch(v)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          _label('Mobile Number'),
          TextFormField(
            key: _phoneKey,
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            style: const TextStyle(fontSize: 14.5, color: dark),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: fieldDecoration(
              hint: 'Enter 10 digit mobile number',
              icon: Icons.phone_android_rounded,
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Mobile number is required';
              if (v.length != 10) return 'Mobile number must be 10 digits';
              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(v)) {
                return 'Number must start with 6, 7, 8 or 9';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------- SCHOOL ----------
  Widget _buildSchoolCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'School Information',
            'Add your school and classroom details',
            Icons.account_balance_rounded,
          ),
          const SizedBox(height: 18),

          _label('School Name'),
          TextFormField(
            key: _schoolKey,
            controller: schoolController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14.5, color: dark),
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: fieldDecoration(
              hint: 'Enter school name',
              icon: Icons.school_rounded,
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'School name is required';
              if (v.length < 3) return 'Enter a valid school name';
              return null;
            },
          ),

          const SizedBox(height: 14),

          _label('Employee ID', required: false),
          TextFormField(
            key: _employeeKey,
            controller: employeeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14.5, color: dark),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-/]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: fieldDecoration(
              hint: 'e.g. TCH-1024',
              icon: Icons.badge_rounded,
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return null; // optional
              if (v.length < 3) return 'Employee ID is too short';
              return null;
            },
          ),

          const SizedBox(height: 14),

          _label('Select Class'),
          DropdownButtonFormField<String>(
            key: _classKey,
            initialValue: selectedClass,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: primary,
            ),
            style: const TextStyle(fontSize: 14.5, color: dark),
            decoration: fieldDecoration(
              hint: 'Choose your class',
              icon: Icons.class_rounded,
            ),
            items: classes.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 14.5, color: dark),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedClass = value),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your class';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------- SECURITY ----------
  Widget _buildSecurityCard() {
    final confirmText = confirmPasswordController.text;
    final matches =
        confirmText.isNotEmpty && confirmText == passwordController.text;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Account Security',
            'Create a secure login password',
            Icons.shield_rounded,
          ),
          const SizedBox(height: 18),

          _label('Password'),
          TextFormField(
            key: _passwordKey,
            controller: passwordController,
            obscureText: hidePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            style: const TextStyle(fontSize: 14.5, color: dark),
            onChanged: (_) => setState(() {}),
            decoration: fieldDecoration(
              hint: 'Create your password',
              icon: Icons.lock_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => hidePassword = !hidePassword),
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
              final v = value ?? '';
              if (v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Minimum 8 characters required';
              if (!RegExp(r'[A-Z]').hasMatch(v)) {
                return 'Add at least one uppercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(v)) {
                return 'Add at least one number';
              }
              return null;
            },
          ),

          _passwordStrengthWidget(),

          const SizedBox(height: 16),

          _label('Confirm Password'),
          TextFormField(
            key: _confirmKey,
            controller: confirmPasswordController,
            obscureText: hideConfirmPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            style: const TextStyle(fontSize: 14.5, color: dark),
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => registerTeacher(),
            decoration: fieldDecoration(
              hint: 'Re-enter your password',
              icon: Icons.lock_reset_rounded,
              suffix: IconButton(
                onPressed: () => setState(
                      () => hideConfirmPassword = !hideConfirmPassword,
                ),
                icon: Icon(
                  hideConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: const Color(0xFF5F7A76),
                  size: 20,
                ),
              ),
            ),
            validator: (value) {
              final v = value ?? '';
              if (v.isEmpty) return 'Please confirm your password';
              if (v != passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          if (matches)
            Padding(
              padding: const EdgeInsets.only(top: 7, left: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Passwords match',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- TERMS ----------
  Widget _buildTermsCard() {
    Widget link(String text, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      key: _termsKey,
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: termsError ? Colors.redAccent : const Color(0xFFE1EEEA),
          width: termsError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: agree,
                activeColor: primary,
                side: BorderSide(
                  color: termsError ? Colors.redAccent : primary,
                  width: 1.5,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() {
                  agree = v ?? false;
                  if (agree) termsError = false;
                }),
              ),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'I agree to the',
                      style: TextStyle(fontSize: 12.5, color: dark),
                    ),
                    link(
                      'Terms & Conditions',
                          () => _showPolicy(
                        'Terms & Conditions',
                        'By creating a Smart School teacher account you agree to use '
                            'the app only for school-related work, to keep your login '
                            'details private, and to handle student information '
                            'responsibly. Your school may suspend accounts that are '
                            'misused.',
                      ),
                    ),
                    const Text(
                      'and',
                      style: TextStyle(fontSize: 12.5, color: dark),
                    ),
                    link(
                      'Privacy Policy',
                          () => _showPolicy(
                        'Privacy Policy',
                        'We collect your name, email, mobile number and school '
                            'details only to create and manage your teacher account. '
                            'Student and class data is visible only to authorised '
                            'staff and is never sold or shared with third parties.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (termsError)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text(
                'Please accept the Terms & Conditions to continue',
                style: TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- BUTTON ----------
  Widget _buildRegisterButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
        onPressed: isLoading ? null : registerTeacher,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
              'Create Teacher Account',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Login',
              style: TextStyle(
                fontSize: 13,
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
// PAINTERS (same as the login screen)
// =================================================================
class _TopWavePainter extends CustomPainter {
  const _TopWavePainter();

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