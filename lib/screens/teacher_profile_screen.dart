import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/page_app_bar.dart';
import 'login_screen.dart';

/// Teacher चा "My Profile" screen (नवीन).
///  - स्वतःची माहिती (email, phone, employee id, school, class, students)
///  - mobile number बदलणे
///  - password बदलणे (जुना password verify करून)
///  - Logout
/// Home च्या header मधील avatar किंवा "My Profile" tile वरून उघडतो.
class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  static const Color primary = Color(0xFF168C80);
  static const Color primaryDark = Color(0xFF105F59);
  static const Color dark = Color(0xFF183B45);
  static const Color muted = Color(0xFF82918D);
  static const Color red = Color(0xFFE36B61);

  static const List<Color> headerColors = [
    Color(0xFF104F58),
    Color(0xFF087F79),
    Color(0xFF27B69B),
  ];

  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AuthService.myProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  String _text(String key) => (_profile?[key] ?? '').toString().trim();

  String _initial(String name) {
    final clean = name.replaceFirst(RegExp(r'^(Ms|Mrs|Mr)\.?\s*'), '').trim();
    return clean.isEmpty ? 'T' : clean[0].toUpperCase();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  Future<void> _editPhone() async {
    final phone = await showDialog<String>(
      context: context,
      builder: (_) => _EditPhoneDialog(initial: _text('phone')),
    );
    if (phone == null || !mounted) return;

    final err = await AuthService.updateMyPhone(phone);
    if (!mounted) return;
    if (err != null) {
      _snack(err);
      return;
    }
    await _load();
    if (!mounted) return;
    _snack('Mobile number updated.');
  }

  Future<void> _changePassword() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (ok == true && mounted) _snack('Password changed successfully.');
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: dark,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your teacher account?',
          style: TextStyle(fontSize: 13, height: 1.5, color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;

    // Firebase session + live streams बंद करून Login screen वर.
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildPageAppBar(
        title: 'My Profile',
        subtitle: 'Your account and settings',
        onBack: widget.onBack,
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(s),
                        const SizedBox(height: 18),
                        _sectionTitle('Details'),
                        const SizedBox(height: 8),
                        _buildDetailsCard(s),
                        const SizedBox(height: 18),
                        _sectionTitle('Account'),
                        const SizedBox(height: 8),
                        _buildAccountCard(),
                        const SizedBox(height: 22),
                        const Center(
                          child: Text(
                            'Little Steps Teacher',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: dark,
      ),
    ),
  );

  Widget _buildHeaderCard(AppState s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: headerColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: Text(
              _initial(s.teacherName),
              style: const TextStyle(
                color: primaryDark,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Class Teacher  •  ${s.className}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (s.schoolName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    s.schoolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: children),
  );

  Widget _divider() => const Divider(
    height: 1,
    thickness: 1,
    indent: 56,
    color: Color(0xFFF0F3F1),
  );

  Widget _buildDetailsCard(AppState s) {
    if (_loading) {
      return _card(const [
        Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      ]);
    }

    String orDash(String v) => v.isEmpty ? '—' : v;
    final phone = _text('phone');

    return _card([
      _infoRow(Icons.email_rounded, 'Email', orDash(_text('email'))),
      _divider(),
      _infoRow(
        Icons.phone_android_rounded,
        'Mobile number',
        phone.isEmpty ? '—' : '+91 $phone',
        onTap: _editPhone,
        trailing: const Icon(Icons.edit_rounded, size: 17, color: primary),
      ),
      _divider(),
      _infoRow(Icons.badge_rounded, 'Employee ID', orDash(_text('employeeId'))),
      _divider(),
      _infoRow(
        Icons.school_rounded,
        'School',
        orDash(s.schoolName.isNotEmpty ? s.schoolName : _text('schoolName')),
      ),
      _divider(),
      _infoRow(Icons.class_rounded, 'Class', orDash(s.className)),
      _divider(),
      _infoRow(Icons.groups_rounded, 'Students in class', '${s.totalChildren}'),
    ]);
  }

  Widget _infoRow(
      IconData icon,
      String label,
      String value, {
        VoidCallback? onTap,
        Widget? trailing,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F5F0),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10.5, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return _card([
      _actionRow(
        icon: Icons.lock_reset_rounded,
        label: 'Change password',
        color: primary,
        onTap: _changePassword,
      ),
      _divider(),
      _actionRow(
        icon: Icons.logout_rounded,
        label: 'Logout',
        color: red,
        onTap: _confirmLogout,
      ),
    ]);
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color == red ? red : dark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Mobile number बदलण्याचा dialog
// =====================================================================
class _EditPhoneDialog extends StatefulWidget {
  const _EditPhoneDialog({required this.initial});

  final String initial;

  @override
  State<_EditPhoneDialog> createState() => _EditPhoneDialogState();
}

class _EditPhoneDialogState extends State<_EditPhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
  TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Edit mobile number',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            prefixText: '+91 ',
            border: OutlineInputBorder(),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF168C80),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// =====================================================================
// Password बदलण्याचा bottom sheet
// =====================================================================
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  static const Color dark = Color(0xFF183B45);
  static const Color primary = Color(0xFF168C80);
  static const Color muted = Color(0xFF84918D);

  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, bool visible, VoidCallback toggle) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF4F9F8),
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4E5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4E5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 19,
            color: muted,
          ),
        ),
      );

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final err = await AuthService.changePassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );
    if (!mounted) return;

    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE5E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Enter your current password, then choose a new one.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _current,
                  obscureText: !_showCurrent,
                  decoration: _dec(
                    'Current password',
                    _showCurrent,
                        () => setState(() => _showCurrent = !_showCurrent),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _new,
                  obscureText: !_showNew,
                  decoration: _dec(
                    'New password',
                    _showNew,
                        () => setState(() => _showNew = !_showNew),
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
                    if (v == _current.text) {
                      return 'New password must be different';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showNew,
                  decoration: _dec(
                    'Confirm new password',
                    _showNew,
                        () => setState(() => _showNew = !_showNew),
                  ),
                  validator: (v) =>
                  v != _new.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE36B61),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Change password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}