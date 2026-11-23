import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

/// Classes: class बनवा, teacher / students ची संख्या आणि आजचा attendance बघा.
class AdminClassesScreen extends StatelessWidget {
  const AdminClassesScreen({super.key});

  Future<void> _addClass(BuildContext context) async {
    final s = AdminState.instance;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
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
              children: [
                dialogField(name, 'Class name', required: true, hint: 'e.g. Nursery A'),
                dialogField(school, 'School name', required: true),
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

    if (ok == true) {
      try {
        await s.addClass(name.text, school.text);
        if (context.mounted) adminSnack(context, 'Class added');
      } catch (e) {
        if (context.mounted) adminSnack(context, AdminState.errorText(e), error: true);
      }
    }
    name.dispose();
    school.dispose();
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
                    'No classes yet. A class is created automatically when a '
                        'teacher registers, or add one with the button above.',
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
    final teacher = c.teacherName.isNotEmpty
        ? c.teacherName
        : (s.teacherOfClass(c.id)?.name ?? '');
    final students = s.studentsOfClass(c.id).length;
    final pct = s.attendancePercent(s.todayKey, classId: c.id);

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
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                teacher.isEmpty ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                size: 14,
                color: teacher.isEmpty ? AdminColors.muted : const Color(0xFF159B83),
              ),
              const SizedBox(width: 7),
              Text(
                teacher.isEmpty ? 'Needs a class teacher' : 'Class teacher assigned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: teacher.isEmpty ? AdminColors.muted : const Color(0xFF159B83),
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
