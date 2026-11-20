
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final schoolController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  static const Color primary = Color(0xFF168C80);
  static const Color dark = Color(0xFF183B45);
  static const Color background = Color(0xFFF3F8F7);

  String selectedClass = 'Nursery A';

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool agree = false;
  bool isLoading = false;

  final List<String> classes = [
    'Nursery A',
    'Nursery B',
    'Junior KG',
    'Senior KG',
  ];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    schoolController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  int get passwordStrength {
    final password = passwordController.text;
    if (password.isEmpty) return 0;

    int score = 0;

    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    return score;
  }

  String get strengthLabel {
    if (passwordStrength <= 1) return 'Weak';
    if (passwordStrength <= 3) return 'Medium';
    return 'Strong';
  }

  Color get strengthColor {
    if (passwordStrength <= 1) return Colors.redAccent;
    if (passwordStrength <= 3) return Colors.orange;
    return Colors.green;
  }

  void registerTeacher() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms & Conditions'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration Demo Successful!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    });
  }

  Widget sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F4F0),
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
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF899694),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget inputLabel(String label, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  InputDecoration decoration(
      String hint,
      IconData icon, {
        Widget? suffix,
      }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFFA3AEAB),
      ),
      prefixIcon: Icon(icon, color: primary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7FAF9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE4ECE9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE4ECE9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget sectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: dark.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget passwordStrengthWidget() {
    if (passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Password strength',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                strengthLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
                  margin: const EdgeInsets.only(right: 4),
                  height: 5,
                  decoration: BoxDecoration(
                    color: index < passwordStrength
                        ? strengthColor
                        : const Color(0xFFE7ECEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          const Text(
            'Use uppercase, numbers and special characters.',
            style: TextStyle(
              color: Color(0xFF98A29F),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // TOP APP BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: dark,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Teacher Registration',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(19, 8, 19, 25),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // HERO HEADER
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF168C80),
                                  Color(0xFF36B6A0),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Join Our Teaching Team!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Create your account and manage your classroom with ease.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 13),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Teacher Registration',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  height: 76,
                                  width: 76,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    size: 43,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // PERSONAL INFORMATION
                          sectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionTitle(
                                  'Personal Information',
                                  'Enter your basic contact details',
                                  Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 22),

                                inputLabel('Full Name'),
                                TextFormField(
                                  controller: nameController,
                                  textCapitalization:
                                  TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration: decoration(
                                    'Enter your full name',
                                    Icons.person_outline,
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().length < 3) {
                                      return 'Please enter your full name';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 18),

                                inputLabel('Email Address'),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: decoration(
                                    'teacher@gmail.com',
                                    Icons.email_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        !RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                        ).hasMatch(value.trim())) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 18),

                                inputLabel('Mobile Number'),
                                TextFormField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  maxLength: 10,
                                  decoration: decoration(
                                    'Enter 10 digit mobile number',
                                    Icons.phone_android_rounded,
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    if (value == null ||
                                        !RegExp(
                                          r'^[6-9][0-9]{9}$',
                                        ).hasMatch(value.trim())) {
                                      return 'Enter a valid 10 digit number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 17),

                          // SCHOOL INFORMATION
                          sectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionTitle(
                                  'School Information',
                                  'Add your school and classroom details',
                                  Icons.account_balance_outlined,
                                ),
                                const SizedBox(height: 22),

                                inputLabel('School Name'),
                                TextFormField(
                                  controller: schoolController,
                                  textCapitalization:
                                  TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration: decoration(
                                    'Enter school name',
                                    Icons.school_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Please enter school name';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 18),

                                inputLabel('Select Class'),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedClass,
                                  isExpanded: true,
                                  decoration: decoration(
                                    'Choose your class',
                                    Icons.class_outlined,
                                  ),
                                  items: classes.map((item) {
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedClass = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 17),

                          // SECURITY INFORMATION
                          sectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionTitle(
                                  'Account Security',
                                  'Create a secure login password',
                                  Icons.shield_outlined,
                                ),
                                const SizedBox(height: 22),

                                inputLabel('Password'),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: hidePassword,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  decoration: decoration(
                                    'Create your password',
                                    Icons.lock_outline,
                                    suffix: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          hidePassword = !hidePassword;
                                        });
                                      },
                                      icon: Icon(
                                        hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.length < 6) {
                                      return 'Minimum 6 characters required';
                                    }
                                    return null;
                                  },
                                ),

                                passwordStrengthWidget(),

                                const SizedBox(height: 20),

                                inputLabel('Confirm Password'),
                                TextFormField(
                                  controller: confirmPasswordController,
                                  obscureText: hideConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  decoration: decoration(
                                    'Re-enter your password',
                                    Icons.lock_person_outlined,
                                    suffix: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          hideConfirmPassword =
                                          !hideConfirmPassword;
                                        });
                                      },
                                      icon: Icon(
                                        hideConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value != passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 17),

                          // TERMS AND CONDITIONS
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: const Color(0xFFE7EEEB),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: agree,
                              activeColor: primary,
                              controlAffinity:
                              ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text(
                                'I agree to the Terms & Conditions and Privacy Policy.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark,
                                  height: 1.5,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  agree = value ?? false;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // REGISTER BUTTON
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : registerTeacher,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFF8ABCB4),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                height: 23,
                                width: 23,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                                  : const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'CREATE TEACHER ACCOUNT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Already have an account? Login',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Center(
                            child: Text(
                              'Little Steps • Teacher Portal',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9AA6A2),
                              ),
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
        ),
      ),
    );
  }
}
