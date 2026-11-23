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
    final err = await AdminState.instance.login(_email.text.trim(), _password.text);
    if (!mounted) return;
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AdminColors.pageBg,
                        AppColors.primaryLight.withOpacity(.55),
                        const Color(0xFFF8FAFC),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 500 ? 18 : 32,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1000 : 460),
                    child: wide
                        ? _wideLayout()
                        : _loginCard(compact: constraints.maxWidth < 500),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _wideLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: AdminColors.dark.withOpacity(.08),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(flex: 11, child: _welcomePanel()),
            Expanded(flex: 9, child: Padding(
              padding: const EdgeInsets.all(42),
              child: _loginForm(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _welcomePanel() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminColors.primary, Color(0xFF263D78)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(height: 30),
          const Text(
            'Little Steps',
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'A smarter space to manage your school.',
            style: TextStyle(color: Colors.white.withOpacity(.82), fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 42),
          _feature(Icons.dashboard_customize_rounded, 'One clear view', 'Stay on top of daily school activity.'),
          const SizedBox(height: 22),
          _feature(Icons.groups_rounded, 'People & classes', 'Manage teachers, students and families.'),
          const SizedBox(height: 22),
          _feature(Icons.event_available_rounded, 'Everyday operations', 'Keep attendance, fees and updates organised.'),
          const SizedBox(height: 52),
          Text(
            'SIMPLE • SECURE • CONNECTED',
            style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 10, letterSpacing: 1.7, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withOpacity(.95), size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(color: AdminColors.dark.withOpacity(.07), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: _loginForm(),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: AdminColors.primary, size: 32),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AdminColors.dark),
          ),
          const SizedBox(height: 7),
          const Text(
            'Sign in to your Little Steps admin account',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AdminColors.muted, height: 1.45),
          ),
          const SizedBox(height: 30),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Admin email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.red.withOpacity(.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AdminColors.red, size: 18),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AdminColors.red, fontSize: 12, height: 1.4))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _login,
              style: adminPrimaryButton(),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sign in', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(width: 9),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading ? null : _forgot,
            child: const Text('Forgot password?'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: AdminColors.muted.withOpacity(.8)),
              const SizedBox(width: 6),
              const Text('Secure admin access', style: TextStyle(color: AdminColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
