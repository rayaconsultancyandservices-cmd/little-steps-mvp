import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Classes: Admin आधी class बनवतो आणि teacher चा email देतो.
///  - Teacher आधीच registered असेल तर लगेच approve + class assign.
///  - Registered नसेल तर email class वर "pending" म्हणून साठवतो; teacher त्याच
///    email ने Teacher app मध्ये register झाला की आपोआप approve + class assign.
class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// classId -> pending teacher email (teacher अजून जोडला गेलेला नाही)
  Map<String, String> _pending = {};

  /// एकाच class चं auto-link दोनदा चालू होऊ नये म्हणून.
  final Set<String> _linking = {};

  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // -------------------------------------------------------------------
  // life-cycle
  // -------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    // classes चे pending teacherEmail live ऐकतो.
    _sub = _db.collection('classes').snapshots().listen(
          (snap) {
        final m = <String, String>{};
        for (final d in snap.docs) {
          final x = d.data();
          final mail =
          (x['teacherEmail'] ?? '').toString().trim().toLowerCase();
          final uid = (x['teacherUid'] ?? '').toString();
          if (mail.isNotEmpty && uid.isEmpty) m[d.id] = mail;
        }
        if (!mounted) return;
        setState(() => _pending = m);
        _tryAutoLink();
      },
      onError: (_) {},
    );
    // नवीन teacher register झाला (teachers list बदलली) की पुन्हा तपासतो.
    AdminState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    AdminState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    _tryAutoLink();
  }

  // -------------------------------------------------------------------
  // helpers
  // -------------------------------------------------------------------
  /// Registered teachers मधून email ने teacher शोधतो (lowercase तुलना).
  static AdminTeacher? _findTeacherByEmail(AdminState s, String email) {
    final mail = email.trim().toLowerCase();
    if (mail.isEmpty) return null;
    for (final t in s.teachers) {
      if (t.email.trim().toLowerCase() == mail) return t;
    }
    return null;
  }

  /// Pending email असलेल्या class साठी teacher register झाला असेल तर
  /// त्याला approve करून class देतो.
  Future<void> _tryAutoLink() async {
    if (_pending.isEmpty) return;
    final s = AdminState.instance;

    for (final e in _pending.entries.toList()) {
      final classId = e.key;
      if (_linking.contains(classId)) continue;

      final t = _findTeacherByEmail(s, e.value);
      if (t == null) continue; // अजून register झालेला नाही

      final matches = s.classes.where((c) => c.id == classId).toList();
      if (matches.isEmpty) continue;
      final cls = matches.first;

      // Teacher आधीच दुसऱ्या class ला असेल किंवा या class ला दुसरा teacher असेल तर थांबतो.
      if (t.classId.isNotEmpty && t.classId != classId) continue;
      if (s.otherTeacherOfClass(classId, t.uid) != null) continue;

      _linking.add(classId);
      try {
        await s.approveAndAssign(t, cls);
        await _db
            .collection('classes')
            .doc(classId)
            .update({'teacherEmail': FieldValue.delete()});
        if (mounted) {
          adminSnack(context, '${t.name} is now the class teacher of ${cls.className}');
        }
      } catch (_) {
        // पुढच्या वेळी (snapshot / state बदलल्यावर) पुन्हा प्रयत्न होईल.
      } finally {
        _linking.remove(classId);
      }
    }
  }

  /// "Class teacher email" field चं validation.
  String? _teacherEmailError(
      AdminState s,
      String? value,
      String className,
      String school,
      ) {
    final mail = (value ?? '').trim().toLowerCase();
    if (mail.isEmpty) return null; // optional

    if (!_emailRe.hasMatch(mail)) {
      return 'Enter a valid email address.';
    }

    final newId = (className.trim().isNotEmpty && school.trim().isNotEmpty)
        ? AuthService.classIdFor(school, className)
        : '';

    final t = _findTeacherByEmail(s, mail);

    // Teacher अजून registered नाही -> pending म्हणून चालतो,
    // फक्त हाच email दुसऱ्या class साठी आधीच pending नसावा.
    if (t == null) {
      final dup = _pending.entries.any((e) => e.value == mail && e.key != newId);
      if (dup) return 'This email is already waiting for another class.';
      return null;
    }

    // Teacher registered आहे: आधीच दुसऱ्या class ला असेल तर नको.
    if (t.classId.isNotEmpty && t.classId != newId) {
      final where = t.className.isEmpty ? 'another class' : t.className;
      return '${t.name} is already assigned to $where. '
          'Unassign from the Teachers page first.';
    }

    // या class ला आधीच दुसरा teacher आहे का.
    if (newId.isNotEmpty) {
      final other = s.otherTeacherOfClass(newId, t.uid);
      if (other != null) {
        return 'This class already has a class teacher (${other.name}).';
      }
    }
    return null;
  }

  Future<void> _addClass(BuildContext context) async {
    final s = AdminState.instance;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final teacherEmail = TextEditingController();
    final school = TextEditingController(
      text: s.schoolName.isNotEmpty
          ? s.schoolName
          : (s.classes.isNotEmpty ? s.classes.first.schoolName : ''),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Add class'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogField(name, 'Class name', required: true, hint: 'e.g. Nursery A'),
                dialogField(school, 'School name', required: true),
                dialogField(
                  teacherEmail,
                  'Class teacher email (optional)',
                  keyboard: TextInputType.emailAddress,
                  hint: 'teacher@school.com',
                  validator: (v) =>
                      _teacherEmailError(s, v, name.text, school.text),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    'The teacher logs in with this email. If the teacher has '
                        'not registered yet, the class stays "pending" and is '
                        'linked automatically after the teacher registers in the '
                        'Teacher app with this same email.',
                    style: TextStyle(fontSize: 11, color: AdminColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: adminPrimaryButton(),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );


    // Dialog बंद झाल्यावर values आधी वाचतो.
    final className = name.text.trim();
    final schoolName = school.text.trim();
    final mail = teacherEmail.text.trim().toLowerCase();

    // Dialog चं बंद होण्याचं animation संपल्यावरच controllers dispose करतो,
    // नाहीतर TextFormField अजून वापरत असताना dispose होऊन error येतो.
    Future.delayed(const Duration(milliseconds: 500), () {
      name.dispose();
      school.dispose();
      teacherEmail.dispose();
    });

    if (ok != true) return;

    // पायरी 1: Class बनवतो
    String classId;
    try {
      classId = await s.addClass(className, schoolName);
    } catch (e) {
      if (context.mounted) adminSnack(context, AdminState.errorText(e), error: true);
      return;
    }

    if (mail.isEmpty) {
      if (context.mounted) adminSnack(context, 'Class added');
      return;
    }

    // पायरी 2: Teacher ला class देतो
    try {
      final t = _findTeacherByEmail(s, mail);
      if (t != null) {
        // Registered आहे -> लगेच approve + assign.
        final cls = AdminClass(
          id: classId,
          className: className,
          schoolName: schoolName,
          teacherName: '',
          teacherUid: '',
        );
        await s.approveAndAssign(t, cls);
        if (context.mounted) {
          adminSnack(context, 'Class added and ${t.name} assigned as class teacher');
        }
      } else {
        // Registered नाही -> email class वर pending म्हणून साठवतो.
        await _db
            .collection('classes')
            .doc(classId)
            .set({'teacherEmail': mail}, SetOptions(merge: true));
        if (context.mounted) {
          adminSnack(
            context,
            'Class added. $mail will be linked automatically after registering '
                'in the Teacher app.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        adminSnack(
          context,
          'Class was added, but the teacher could not be assigned: '
              '${AdminState.errorText(e)}',
          error: true,
        );
      }
    }
  }

  Future<void> _cancelPending(BuildContext context, AdminClass c) async {
    try {
      await _db
          .collection('classes')
          .doc(c.id)
          .update({'teacherEmail': FieldValue.delete()});
      if (context.mounted) adminSnack(context, 'Pending teacher removed');
    } catch (e) {
      if (context.mounted) {
        adminSnack(context, AdminState.errorText(e), error: true);
      }
    }
  }

  Future<void> _delete(BuildContext context, AdminClass c) async {
    final s = AdminState.instance;
    if (s.studentsOfClass(c.id).isNotEmpty) {
      adminSnack(
        context,
        'Move or delete the students of ${c.className} first.',
        error: true,
      );
      return;
    }
    final hasTeacher = c.teacherUid.isNotEmpty || s.teacherOfClass(c.id) != null;
    if (hasTeacher) {
      adminSnack(
        context,
        'Assign ${c.className}\'s teacher to another class (or remove the '
            'teacher) before deleting this class.',
        error: true,
      );
      return;
    }
    final ok = await adminConfirm(
      context,
      title: 'Delete ${c.className}?',
      message: 'The class and its diary, photos, circulars and events will '
          'be removed permanently.',
    );
    if (!ok) return;
    try {
      await s.deleteClass(c.id);
      if (context.mounted) adminSnack(context, 'Class deleted');
    } catch (e) {
      if (context.mounted) {
        adminSnack(context, AdminState.errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final totalStudents = s.classes.fold<int>(
          0,
              (total, c) => total + s.studentsOfClass(c.id).length,
        );
        final assignedTeachers = s.classes.where((c) =>
        c.teacherUid.isNotEmpty || s.teacherOfClass(c.id) != null).length;
        final schools = s.classes
            .map((c) => c.schoolName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .length;

        return AdminPage(
          title: 'Classes',
          subtitle: '${s.classes.length} classes across $schools schools',
          actions: [
            FilledButton.icon(
              style: adminPrimaryButton(),
              onPressed: () => _addClass(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add class'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              if (s.classes.isNotEmpty) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ClassMetric(
                      label: 'Total classes',
                      value: '${s.classes.length}',
                      icon: Icons.meeting_room_rounded,
                      tint: AdminColors.primary,
                    ),
                    _ClassMetric(
                      label: 'Total students',
                      value: '$totalStudents',
                      icon: Icons.child_care_rounded,
                      tint: const Color(0xFF159B83),
                    ),
                    _ClassMetric(
                      label: 'Teacher assigned',
                      value: '$assignedTeachers / ${s.classes.length}',
                      icon: Icons.badge_rounded,
                      tint: const Color(0xFF8B68C8),
                    ),
                    _ClassMetric(
                      label: 'Schools',
                      value: '$schools',
                      icon: Icons.account_balance_rounded,
                      tint: const Color(0xFFE39A35),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All classes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.dark,
                        ),
                      ),
                    ),
                    Text(
                      'Updated live',
                      style: TextStyle(
                        fontSize: 11,
                        color: AdminColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (s.classes.isEmpty)
                const AdminCard(
                  child: EmptyState(
                    'No classes yet. Add one with the button above and '
                        'optionally assign a teacher by email.',
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cardWidth = width >= 1100
                        ? (width - 32) / 3
                        : width >= 700
                        ? (width - 16) / 2
                        : width;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final c in s.classes)
                          SizedBox(
                            width: cardWidth.clamp(260.0, 420.0).toDouble(),
                            child: _classCard(context, s, c),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _classCard(BuildContext context, AdminState s, AdminClass c) {
    final teacherObj = s.teacherOfClass(c.id);
    final teacher = c.teacherName.isNotEmpty
        ? c.teacherName
        : (teacherObj?.name ?? '');
    final teacherMail = teacherObj?.email ?? '';
    final pendingMail = _pending[c.id] ?? '';
    final isPending = teacher.isEmpty && pendingMail.isNotEmpty;
    final students = s.studentsOfClass(c.id).length;
    final pct = s.attendancePercent(s.todayKey, classId: c.id);

    final Color statusColor = teacher.isNotEmpty
        ? const Color(0xFF159B83)
        : (isPending ? const Color(0xFFE39A35) : AdminColors.muted);
    final IconData statusIcon = teacher.isNotEmpty
        ? Icons.check_circle_outline_rounded
        : (isPending ? Icons.hourglass_bottom_rounded : Icons.info_outline_rounded);
    final String statusText = teacher.isNotEmpty
        ? 'Class teacher assigned'
        : (isPending ? 'Waiting for teacher to register' : 'Needs a class teacher');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D2340),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AdminColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.schoolName.isEmpty ? 'School not set' : c.schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete class',
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(context, c),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AdminColors.red,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ClassStat(
                    label: 'STUDENTS',
                    value: '$students',
                    icon: Icons.groups_rounded,
                  ),
                ),
                Container(width: 1, height: 34, color: AdminColors.border),
                Expanded(
                  child: _ClassStat(
                    label: 'ATTENDANCE',
                    value: pct == null ? '—' : '$pct%',
                    icon: Icons.fact_check_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _line(
            Icons.badge_rounded,
            teacher.isEmpty ? 'No teacher assigned' : teacher,
          ),
          if (teacherMail.isNotEmpty) ...[
            const SizedBox(height: 7),
            _line(Icons.email_outlined, teacherMail),
          ],
          if (isPending) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _line(Icons.email_outlined, pendingMail)),
                TextButton(
                  onPressed: () => _cancelPending(context, c),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 16, color: AdminColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _ClassMetric extends StatelessWidget {
  const _ClassMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 175, maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: AdminColors.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AdminColors.muted,
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
}

class _ClassStat extends StatelessWidget {
  const _ClassStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AdminColors.primary),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AdminColors.dark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: .5,
                fontWeight: FontWeight.w700,
                color: AdminColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}