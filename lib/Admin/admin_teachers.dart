import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String _statusFilter = 'All';

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
                Builder(builder: (_) {
                  final c = s.classes.where((x) => x.id == selected).toList();
                  final other = (c.isNotEmpty &&
                      c.first.teacherUid.isNotEmpty &&
                      c.first.teacherUid != t.uid)
                      ? c.first.teacherName
                      : '';
                  return Text(
                    other.isEmpty
                        ? 'The teacher will see this class (students, attendance, '
                        'diary…) the next time they log in.'
                        : 'Note: $other is already the teacher of this class. '
                        'Both teachers will see the class, but the class '
                        'card will show ${t.name}.',
                    style: TextStyle(
                      fontSize: 11,
                      color: other.isEmpty ? AdminColors.muted : AdminColors.orange,
                    ),
                  );
                }),
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
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _edit(AdminTeacher t) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: t.name);
    final phone = TextEditingController(text: t.phone);
    final emp = TextEditingController(text: t.employeeId);
    final school = TextEditingController(text: t.schoolName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit teacher'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogField(name, 'Name', required: true),
                dialogField(phone, 'Phone', keyboard: TextInputType.phone),
                dialogField(emp, 'Employee ID'),
                dialogField(school, 'School name'),
                Text(
                  'Email (${t.email}) cannot be changed here.',
                  style: const TextStyle(fontSize: 11, color: AdminColors.muted),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) {
      name.dispose();
      phone.dispose();
      emp.dispose();
      school.dispose();
      return;
    }
    try {
      await AdminState.instance.updateTeacher(
        t,
        name: name.text,
        phone: phone.text,
        employeeId: emp.text,
        schoolName: school.text,
      );
      if (mounted) adminSnack(context, 'Teacher updated');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    } finally {
      name.dispose();
      phone.dispose();
      emp.dispose();
      school.dispose();
    }
  }

  Future<void> _toggleApproval(AdminTeacher t) async {
    final approve = !t.approved;
    final ok = await adminConfirm(
      context,
      title: approve ? 'Approve ${t.name}?' : 'Revoke access for ${t.name}?',
      message: approve
          ? 'The teacher will be able to open the Teacher app and see the '
          'assigned class.'
          : 'The teacher will no longer be able to read or change any school '
          'data until you approve again.',
      confirmText: approve ? 'Approve' : 'Revoke',
      danger: !approve,
    );
    if (!ok) return;
    try {
      await AdminState.instance.setTeacherApproved(t, approve);
      if (mounted) {
        adminSnack(context, approve ? '${t.name} approved' : 'Access revoked');
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
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
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _unassign(AdminTeacher t) async {
    final ok = await adminConfirm(
      context,
      title: 'Remove ${t.name} from ${t.className}?',
      message: 'The teacher will keep their login but will no longer see this '
          'class. The class will show "Not assigned" until you assign a '
          'teacher again.',
      confirmText: 'Unassign',
      danger: true,
    );
    if (!ok) return;
    try {
      await AdminState.instance.unassignTeacher(t);
      if (mounted) adminSnack(context, '${t.name} unassigned');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _copyEmail(AdminTeacher t) async {
    await Clipboard.setData(ClipboardData(text: t.email));
    if (mounted) adminSnack(context, 'Email copied');
  }

  Future<void> _resetPassword(AdminTeacher t) async {
    final ok = await adminConfirm(
      context,
      title: 'Send password reset email?',
      message: 'A password reset link will be emailed to ${t.email}.',
      confirmText: 'Send email',
    );
    if (!ok) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: t.email);
      if (mounted) adminSnack(context, 'Reset email sent to ${t.email}');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        adminSnack(context, e.message ?? 'Could not send email', error: true);
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _approveAllPending() async {
    final s = AdminState.instance;
    final pending = s.teachers.where((t) => !t.approved).toList();
    if (pending.isEmpty) return;
    final ok = await adminConfirm(
      context,
      title: 'Approve all ${pending.length} pending teachers?',
      message: 'All pending teachers will be able to open the Teacher app.',
      confirmText: 'Approve all',
    );
    if (!ok) return;
    try {
      for (final t in pending) {
        await s.setTeacherApproved(t, true);
      }
      if (mounted) adminSnack(context, '${pending.length} teachers approved');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final pending = s.teachers.where((t) => !t.approved).length;
        final approved = s.teachers.where((t) => t.approved).length;
        final assigned = s.teachers.where((t) => t.className.isNotEmpty).length;

        final list = s.teachers.where((t) {
          final matchesStatus = _statusFilter == 'All' ||
              (_statusFilter == 'Approved' && t.approved) ||
              (_statusFilter == 'Pending' && !t.approved) ||
              (_statusFilter == 'Unassigned' && t.classId.isEmpty);
          final matchesSearch = _q.isEmpty ||
              '${t.name} ${t.email} ${t.phone} ${t.employeeId} ${t.className}'
                  .toLowerCase()
                  .contains(_q);
          return matchesStatus && matchesSearch;
        }).toList()
        // Pending teachers first, then A–Z.
          ..sort((a, b) {
            if (a.approved != b.approved) return a.approved ? 1 : -1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

        final noTeacherClasses =
            s.classes.where((c) => c.teacherName.trim().isEmpty).length;

        return AdminPage(
          title: 'Teacher management',
          subtitle: 'Review registrations, manage access and assign classroom responsibilities.',
          actions: [
            SizedBox(
              width: 300,
              child: AdminSearchField(
                controller: _search,
                hint: 'Search name, email, phone or class...',
                onChanged: (v) =>
                    setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Filter teachers by access status',
              initialValue: _statusFilter,
              onSelected: (value) => setState(() => _statusFilter = value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'All', child: Text('All teachers')),
                PopupMenuItem(value: 'Approved', child: Text('Approved only')),
                PopupMenuItem(value: 'Pending', child: Text('Pending only')),
                PopupMenuItem(
                    value: 'Unassigned', child: Text('No class assigned')),
              ],
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 17, color: AdminColors.primary),
                    const SizedBox(width: 7),
                    Text(_statusFilter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.dark)),
                    const SizedBox(width: 5),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: AdminColors.muted),
                  ],
                ),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              if (pending > 0) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AdminColors.orange.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AdminColors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const Icon(Icons.pending_actions_rounded,
                          color: AdminColors.orange, size: 20),
                      Text(
                        '$pending teacher account(s) are waiting for your approval.',
                        style: const TextStyle(
                          color: AdminColors.dark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      FilledButton.icon(
                        style: adminPrimaryButton(),
                        onPressed: _approveAllPending,
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Approve all'),
                      ),
                    ],
                  ),
                ),
              ],
              AdminResponsiveGrid(
                minItemWidth: 190,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _TeacherMetricCard(
                    icon: Icons.groups_rounded,
                    label: 'Total teachers',
                    value: '${s.teachers.length}',
                    note: 'Registered accounts',
                    color: AdminColors.blue,
                    onTap: () => setState(() => _statusFilter = 'All'),
                  ),
                  _TeacherMetricCard(
                    icon: Icons.verified_rounded,
                    label: 'Approved',
                    value: '$approved',
                    note: 'Access enabled',
                    color: AdminColors.green,
                    onTap: () => setState(() => _statusFilter = 'Approved'),
                  ),
                  _TeacherMetricCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending review',
                    value: '$pending',
                    note: 'Need your approval',
                    color: AdminColors.orange,
                    onTap: () => setState(() => _statusFilter = 'Pending'),
                  ),
                  _TeacherMetricCard(
                    icon: Icons.class_rounded,
                    label: 'Class assigned',
                    value: '$assigned',
                    note: 'Linked to a class',
                    color: AdminColors.purple,
                    onTap: () => setState(() {
                      _statusFilter = 'All';
                      _search.clear();
                      _q = '';
                    }),
                  ),
                  _TeacherMetricCard(
                    icon: Icons.person_search_rounded,
                    label: 'Classes without teacher',
                    value: '$noTeacherClasses',
                    note: 'of ${s.classes.length} classes',
                    color: noTeacherClasses > 0
                        ? AdminColors.red
                        : AdminColors.green,
                    onTap: () => setState(() => _statusFilter = 'Unassigned'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AdminCard(
                title: 'Teacher directory',
                padding: const EdgeInsets.all(16),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    StatusChip('$approved approved', AdminColors.green),
                    StatusChip('$pending pending', AdminColors.orange),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(
                      title: 'Registered teachers',
                      subtitle:
                      'Showing ${list.length} of ${s.teachers.length} accounts · $_statusFilter',
                      icon: Icons.groups_2_rounded,
                    ),
                    if (s.teachers.isEmpty)
                      const EmptyState(
                        'No teachers have registered yet. Teachers can create '
                            'their accounts from the Teacher app.',
                        icon: Icons.person_add_alt_1_rounded,
                      )
                    else if (list.isEmpty)
                      const EmptyState(
                        'No teachers match your search. Try another search.',
                        icon: Icons.search_off_rounded,
                      )
                    else
                      AdminTable(
                        columns: const [
                          'Teacher', 'Contact', 'Employee ID', 'Class',
                          'Students', 'Access', 'School', 'Joined', 'Actions',
                        ],
                        rows: [
                          for (final t in list)
                            DataRow(cells: [
                              DataCell(
                                SizedBox(
                                  width: 155,
                                  child: Row(
                                    children: [
                                      AdminAvatar(
                                        name: t.name.isEmpty ? t.email : t.name,
                                        size: 34,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          t.name.isEmpty ? 'Unnamed' : t.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AdminColors.dark,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 175,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AdminColors.dark,
                                        ),
                                      ),
                                      if (t.phone.isNotEmpty)
                                        Text(
                                          t.phone,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AdminColors.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              cellText(t.employeeId),
                              DataCell(StatusChip(
                                t.className.isEmpty ? 'Not assigned' : t.className,
                                t.className.isEmpty
                                    ? AdminColors.orange
                                    : AdminColors.primary,
                              )),
                              cellText(t.classId.isEmpty
                                  ? '—'
                                  : '${s.studentsOfClass(t.classId).length}'),
                              DataCell(StatusChip(
                                t.approved ? 'Approved' : 'Pending',
                                t.approved
                                    ? AdminColors.green
                                    : AdminColors.orange,
                              )),
                              cellText(t.schoolName),
                              cellText(fmtDate(t.createdAt)),
                              DataCell(PopupMenuButton<String>(
                                tooltip: 'Teacher actions',
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: AdminColors.muted,
                                ),
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _edit(t);
                                  } else if (v == 'assign') {
                                    _assign(t);
                                  } else if (v == 'approve') {
                                    _toggleApproval(t);
                                  } else if (v == 'unassign') {
                                    _unassign(t);
                                  } else if (v == 'copy') {
                                    _copyEmail(t);
                                  } else if (v == 'reset') {
                                    _resetPassword(t);
                                  } else if (v == 'remove') {
                                    _remove(t);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit details'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'assign',
                                    child: Text('Assign class'),
                                  ),
                                  PopupMenuItem(
                                    value: 'approve',
                                    child: Text(t.approved
                                        ? 'Revoke access'
                                        : 'Approve teacher'),
                                  ),
                                  if (t.classId.isNotEmpty)
                                    const PopupMenuItem(
                                      value: 'unassign',
                                      child: Text('Unassign class'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'copy',
                                    child: Text('Copy email'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'reset',
                                    child: Text('Send password reset'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove teacher'),
                                  ),
                                ],
                              )),
                            ]),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Removing a teacher profile does not delete the Firebase '
                    'Authentication account. Use Firebase Console → Authentication '
                    'for full login deletion.',
                style: TextStyle(
                  color: AdminColors.muted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Compact metric card used only on the Teachers screen.
class _TeacherMetricCard extends StatelessWidget {
  const _TeacherMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 91),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.border),
            boxShadow: [
              BoxShadow(
                color: AdminColors.dark.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 39,
                width: 39,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AdminColors.muted,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(value, maxLines: 1,
                        style: const TextStyle(color: AdminColors.dark,
                            fontSize: 21, height: 1.1,
                            fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 17,
                  color: AdminColors.muted.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}