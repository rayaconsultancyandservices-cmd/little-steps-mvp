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
        if (context.mounted) adminSnack(context, '$e', error: true);
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
    final ok = await adminConfirm(
      context,
      title: 'Delete ${c.className}?',
      message: 'The class record will be removed.',
    );
    if (!ok) return;
    try {
      await s.deleteClass(c.id);
    } catch (e) {
      if (context.mounted) adminSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        return AdminPage(
          title: 'Classes',
          subtitle: '${s.classes.length} classes',
          actions: [
            FilledButton.icon(
              style: adminPrimaryButton(),
              onPressed: () => _addClass(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add class'),
            ),
          ],
          child: Column(
            children: [
              ErrorBanner(s.lastError),
              if (s.classes.isEmpty)
                const AdminCard(
                  child: EmptyState(
                    'No classes yet. A class is created automatically when a '
                        'teacher registers, or add one with the button above.',
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final c in s.classes) _classCard(context, s, c),
                    ],
                  ),
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
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.className,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AdminColors.dark,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete class',
                onPressed: () => _delete(context, c),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AdminColors.red, size: 20),
              ),
            ],
          ),
          Text(
            c.schoolName.isEmpty ? '—' : c.schoolName,
            style: const TextStyle(fontSize: 12, color: AdminColors.muted),
          ),
          const SizedBox(height: 14),
          _line(Icons.badge_rounded, teacher.isEmpty ? 'No teacher assigned' : teacher),
          const SizedBox(height: 8),
          _line(Icons.child_care_rounded, '$students students'),
          const SizedBox(height: 8),
          _line(
            Icons.fact_check_rounded,
            pct == null ? "Today's attendance: not marked" : "Today's attendance: $pct%",
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}