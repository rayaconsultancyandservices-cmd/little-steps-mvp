import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Web app चा पहिला screen: आधी login असेल तर थेट panel, नाहीतर login form.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      // Web वर पहिला auth state येईपर्यंत थांबतो.
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
          : const AdminLoginScreen(),
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AdminState.instance.login(_email.text, _password.text);
    if (!mounted) return;
    // यशस्वी झालं तर AdminGate आपोआप panel उघडतो.
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  Future<void> _forgot() async {
    final mail = _email.text.trim();
    if (mail.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap "Forgot password".');
      return;
    }
    final err = await AuthService.resetPassword(mail);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      adminSnack(context, 'Password reset email sent to $mail');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AdminColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        height: 62,
                        width: 62,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AdminColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Little Steps Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to manage your school',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AdminColors.muted),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Admin email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_hide
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.redLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AdminColors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      style: adminPrimaryButton(),
                      child: _loading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _forgot,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}