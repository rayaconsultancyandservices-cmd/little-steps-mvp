import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

/// Teachers: teacher app मध्ये register झालेले सर्व teachers (खरा data).
class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _assign(AdminTeacher t) async {
    final s = AdminState.instance;
    if (s.classes.isEmpty) {
      adminSnack(context, 'Create a class first (Classes tab).', error: true);
      return;
    }
    String? selected = s.classes.any((c) => c.id == t.classId) ? t.classId : null;

    final chosen = await showDialog<AdminClass>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Assign class to ${t.name}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminDropdown<String>(
                  label: 'Class',
                  width: 380,
                  value: selected,
                  items: [
                    for (final c in s.classes)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.className, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setD(() => selected = v),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The teacher will see this class (students, attendance, '
                      'diary…) the next time they log in.',
                  style: TextStyle(fontSize: 11, color: AdminColors.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: adminPrimaryButton(),
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(
                ctx,
                s.classes.firstWhere((c) => c.id == selected),
              ),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    try {
      await s.assignTeacher(t, chosen);
      if (mounted) adminSnack(context, '${t.name} assigned to ${chosen.className}');
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  Future<void> _remove(AdminTeacher t) async {
    final ok = await adminConfirm(
      context,
      title: 'Remove ${t.name}?',
      message: 'This removes the teacher profile so they can no longer use '
          'the Teacher app. To fully delete the login, also delete the user '
          'in Firebase Console → Authentication.',
      confirmText: 'Remove',
    );
    if (!ok) return;
    try {
      await AdminState.instance.removeTeacher(t);
      if (mounted) adminSnack(context, 'Teacher removed');
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final list = s.teachers.where((t) {
          if (_q.isEmpty) return true;
          return '${t.name} ${t.email} ${t.phone} ${t.employeeId} ${t.className}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        return AdminPage(
          title: 'Teachers',
          subtitle: '${s.teachers.length} registered on the Teacher app',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search name, email, class…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ],
          child: Column(
            children: [
              ErrorBanner(s.lastError),
              AdminCard(
                child: AdminTable(
                  emptyText: s.teachers.isEmpty
                      ? 'No teachers yet. Teachers register themselves in the '
                      'Teacher mobile app.'
                      : 'No teacher matches your search.',
                  columns: const [
                    'Name',
                    'Email',
                    'Phone',
                    'Employee ID',
                    'Class',
                    'School',
                    'Joined',
                    '',
                  ],
                  rows: [
                    for (final t in list)
                      DataRow(cells: [
                        cellText(t.name, bold: true),
                        cellText(t.email),
                        cellText(t.phone),
                        cellText(t.employeeId),
                        DataCell(t.className.isEmpty
                            ? const StatusChip('Not assigned', AdminColors.orange)
                            : StatusChip(t.className, AdminColors.primary)),
                        cellText(t.schoolName),
                        cellText(fmtDate(t.createdAt)),
                        DataCell(PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (v) =>
                          v == 'assign' ? _assign(t) : _remove(t),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'assign', child: Text('Assign class')),
                            PopupMenuItem(
                                value: 'remove', child: Text('Remove teacher')),
                          ],
                        )),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}