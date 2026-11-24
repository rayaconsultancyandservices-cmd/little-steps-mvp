import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Students: सर्व classes चे students – add / edit / delete.
class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _classFilter; // null = सर्व classes
  String? _genderFilter; // null = सर्व gender
  String? _parentFilter; // null = सर्व parent-app statuses
  String _sortBy = 'Class & roll';
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({ChildInfo? existing}) async {
    final s = AdminState.instance;
    if (s.classes.isEmpty) {
      adminSnack(context, 'Create a class first (Classes tab).', error: true);
      return;
    }
    final result = await showDialog<ChildInfo>(
      context: context,
      builder: (_) => _StudentForm(existing: existing, defaultClassId: _classFilter),
    );
    if (result == null) return;
    try {
      await s.saveStudent(result, isNew: existing == null, previous: existing);
      if (mounted) {
        adminSnack(context, existing == null ? 'Student added' : 'Student updated');
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _delete(ChildInfo c) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${c.name}?',
      message: 'The student and everything linked to this child (fees, '
          'receipts, attendance, chat, leave requests and the parent login '
          'profile) will be removed permanently. This cannot be undone.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteStudent(c.id);
      if (mounted) adminSnack(context, 'Student deleted');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  /// Parent email मध्ये काही अडचण असेल तर त्याचा मजकूर (नाहीतर null).
  String? _emailIssue(ChildInfo c, Map<String, int> counts) {
    final m = c.parentEmail.trim().toLowerCase();
    if (m.isEmpty) return 'No parent email';
    if ((counts[m] ?? 0) > 1) return 'Email used by ${counts[m]} students';
    return null;
  }

  Future<void> _showProfile(ChildInfo c) async {
    final s = AdminState.instance;
    final att = s.attendance.where((r) => r.studentId == c.id).toList();
    final present = att.where((r) => r.isPresent).length;
    final absent = att.where((r) => r.status == 'A').length;
    final pct = att.isEmpty ? null : (present * 100 / att.length).round();
    final dues = s.fees
        .where((f) => f.studentId == c.id && f.status == FeeStatus.due)
        .toList();
    final dueTotal = dues.fold<int>(0, (a, f) => a + f.amount);
    final paid = s.receipts
        .where((r) => r.studentId == c.id)
        .fold<int>(0, (a, r) => a + r.amount);
    final leaves = s.leaves.where((l) => l.studentId == c.id).toList();
    final joined = s.parentJoined(c);

    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k,
                style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(v.isEmpty ? '—' : v,
                style: const TextStyle(
                    color: AdminColors.dark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    Widget head(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(t,
          style: const TextStyle(
              color: AdminColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4)),
    );

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            AdminAvatar(name: c.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${c.className}  •  Roll ${c.rollNo}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.muted,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head('STUDENT'),
                kv('Gender', c.gender),
                kv('Date of birth',
                    '${fmtDate(c.dob)}  (${c.ageLabel(DateTime.now())})'),
                kv('Blood group', c.bloodGroup),
                kv('Allergy / medical', c.allergyNote),
                kv('Pickup note', c.pickupNote),
                head('PARENT / GUARDIAN'),
                kv('Name', c.parentName),
                kv('Email', c.parentEmail),
                kv('Parent app', joined ? 'Joined' : 'Not joined yet'),
                for (final x in c.contacts)
                  kv(x.relation.isEmpty ? 'Contact' : x.relation,
                      '${x.name}  ${x.phone}'.trim()),
                head('ATTENDANCE (LAST ${AdminState.attendanceWindowDays} DAYS)'),
                kv('Attendance',
                    pct == null ? 'Not marked yet' : '$pct%  ($present present · $absent absent · ${att.length} days marked)'),
                head('FEES'),
                kv('Pending',
                    dues.isEmpty ? 'No pending fees' : '${fmtMoney(dueTotal)}  (${dues.length} item(s))'),
                kv('Paid so far', fmtMoney(paid)),
                head('LEAVE REQUESTS'),
                kv('Total',
                    leaves.isEmpty
                        ? 'None'
                        : '${leaves.length}  (${leaves.where((l) => l.status == 'pending').length} pending · ${leaves.where((l) => l.status == 'approved').length} approved)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: adminPrimaryButton(),
            onPressed: () => Navigator.pop(ctx, 'edit'),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
    if (action == 'edit') _openForm(existing: c);
  }

  Future<void> _bulkMove(List<ChildInfo> chosen) async {
    final s = AdminState.instance;
    if (s.classes.isEmpty || chosen.isEmpty) return;
    String? selected;

    final target = await showDialog<AdminClass>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Move ${chosen.length} student(s)'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminDropdown<String>(
                  label: 'Move to class',
                  width: 380,
                  value: selected,
                  items: [
                    for (final c in s.classes)
                      DropdownMenuItem(value: c.id, child: Text(c.className)),
                  ],
                  onChanged: (v) => setD(() => selected = v),
                ),
                const SizedBox(height: 10),
                const Text(
                  'New roll numbers are given automatically. Parents and '
                      'chat are moved to the new class too.',
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
                  ctx, s.classes.firstWhere((c) => c.id == selected)),
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
    if (target == null) return;

    try {
      var roll = s.nextRollFor(target.id);
      var moved = 0;
      final ordered = [...chosen]
        ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
      for (final c in ordered) {
        if (c.classId == target.id) continue;
        final updated = ChildInfo(
          id: c.id,
          name: c.name,
          className: target.className,
          classId: target.id,
          rollNo: roll++,
          dob: c.dob,
          bloodGroup: c.bloodGroup,
          gender: c.gender,
          allergyNote: c.allergyNote,
          parentName: c.parentName,
          parentEmail: c.parentEmail,
          pickupNote: c.pickupNote,
          contacts: c.contacts,
        );
        await s.saveStudent(updated, previous: c);
        moved++;
      }
      if (mounted) {
        setState(_selected.clear);
        adminSnack(context, '$moved student(s) moved to ${target.className}');
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _bulkDelete(List<ChildInfo> chosen) async {
    if (chosen.isEmpty) return;
    final ok = await adminConfirm(
      context,
      title: 'Delete ${chosen.length} student(s)?',
      message: 'All selected students and everything linked to them (fees, '
          'receipts, attendance, chat, leave requests and parent login '
          'profiles) will be removed permanently. This cannot be undone.',
      confirmText: 'Delete ${chosen.length}',
    );
    if (!ok) return;
    try {
      for (final c in chosen) {
        await AdminState.instance.deleteStudent(c.id);
      }
      if (mounted) {
        setState(_selected.clear);
        adminSnack(context, '${chosen.length} student(s) deleted');
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _copyCsv(List<ChildInfo> list) async {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final buf = StringBuffer(
        'Name,Class,Roll,Gender,Date of birth,Blood group,Parent,Parent email,Parent phone\n');
    for (final c in list) {
      buf.writeln([
        c.name,
        c.className,
        '${c.rollNo}',
        c.gender,
        fmtDate(c.dob),
        c.bloodGroup,
        c.parentName,
        c.parentEmail,
        c.contacts.isNotEmpty ? c.contacts.first.phone : '',
      ].map(esc).join(','));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      adminSnack(context, '${list.length} students copied as CSV (paste in Excel)');
    }
  }

  Widget _bulkBar(List<ChildInfo> shown) {
    final chosen =
    AdminState.instance.students.where((c) => _selected.contains(c.id)).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.greenLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${chosen.length} selected',
              style: const TextStyle(
                  color: AdminColors.dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          OutlinedButton.icon(
            style: adminSecondaryButton(),
            onPressed: () => _bulkMove(chosen),
            icon: const Icon(Icons.drive_file_move_outlined, size: 16),
            label: const Text('Move to class'),
          ),
          OutlinedButton.icon(
            style: adminSecondaryButton(),
            onPressed: () => _bulkDelete(chosen),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: AdminColors.red),
            label: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('Clear selection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final boys = s.students.where((c) => c.gender == 'Boy').length;
        final girls = s.students.where((c) => c.gender == 'Girl').length;
        final joined = s.students.where(s.parentJoined).length;

        // --- per-student helpers (email issues, attendance %, fees due) ---
        final emailCounts = <String, int>{};
        for (final c in s.students) {
          final m = c.parentEmail.trim().toLowerCase();
          if (m.isNotEmpty) emailCounts[m] = (emailCounts[m] ?? 0) + 1;
        }
        final emailIssues =
            s.students.where((c) => _emailIssue(c, emailCounts) != null).length;
        final attMap = <String, List<int>>{}; // [present, marked]
        for (final r in s.attendance) {
          final v = attMap.putIfAbsent(r.studentId, () => [0, 0]);
          v[1]++;
          if (r.isPresent) v[0]++;
        }
        final dueMap = <String, int>{};
        for (final f in s.fees) {
          if (f.status == FeeStatus.due) {
            dueMap[f.studentId] = (dueMap[f.studentId] ?? 0) + f.amount;
          }
        }
        final list = s.students.where((c) {
          if (_classFilter != null && c.classId != _classFilter) return false;
          if (_genderFilter != null && c.gender != _genderFilter) return false;
          if (_parentFilter == 'joined' && !s.parentJoined(c)) return false;
          if (_parentFilter == 'not_joined' && s.parentJoined(c)) return false;
          if (_parentFilter == 'issues' &&
              _emailIssue(c, emailCounts) == null) {
            return false;
          }
          if (_q.isEmpty) return true;
          return '${c.name} ${c.parentName} ${c.parentEmail} '
              '${c.rollNo} ${c.className} '
              '${c.contacts.map((x) => x.phone).join(' ')}'
              .toLowerCase()
              .contains(_q);
        }).toList()
          ..sort((a, b) {
            switch (_sortBy) {
              case 'Name A–Z':
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              case 'Name Z–A':
                return b.name.toLowerCase().compareTo(a.name.toLowerCase());
              case 'Age: youngest':
                return b.dob.compareTo(a.dob);
              case 'Class & roll':
              default:
                final byClass = a.className.compareTo(b.className);
                return byClass != 0 ? byClass : a.rollNo.compareTo(b.rollNo);
            }
          });

        return AdminPage(
          title: 'Student management',
          subtitle: 'Manage enrolments, class placement and parent or guardian contacts.',
          actions: [
            SizedBox(
              width: 275,
              child: AdminSearchField(
                controller: _search,
                hint: 'Search name, roll, parent or phone...',
                onChanged: (v) =>
                    setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            AdminDropdown<String?>(
              label: 'Class',
              width: 175,
              value: _classFilter,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All classes'),
                ),
                for (final c in s.classes)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.className),
                  ),
              ],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
            AdminDropdown<String?>(
              label: 'Gender',
              width: 135,
              value: _genderFilter,
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All genders')),
                DropdownMenuItem<String?>(value: 'Boy', child: Text('Boys')),
                DropdownMenuItem<String?>(value: 'Girl', child: Text('Girls')),
              ],
              onChanged: (v) => setState(() => _genderFilter = v),
            ),
            AdminDropdown<String?>(
              label: 'Parent app',
              width: 155,
              value: _parentFilter,
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All parents')),
                DropdownMenuItem<String?>(value: 'joined', child: Text('Joined')),
                DropdownMenuItem<String?>(value: 'not_joined', child: Text('Not joined')),
                DropdownMenuItem<String?>(value: 'issues', child: Text('Email issues')),
              ],
              onChanged: (v) => setState(() => _parentFilter = v),
            ),
            AdminDropdown<String>(
              label: 'Sort by',
              width: 155,
              value: _sortBy,
              items: const [
                DropdownMenuItem(value: 'Class & roll', child: Text('Class & roll')),
                DropdownMenuItem(value: 'Name A–Z', child: Text('Name A–Z')),
                DropdownMenuItem(value: 'Name Z–A', child: Text('Name Z–A')),
                DropdownMenuItem(value: 'Age: youngest', child: Text('Age: youngest')),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'Class & roll'),
            ),
            FilledButton.icon(
              style: adminPrimaryButton(),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
              label: const Text('Add student'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              AdminResponsiveGrid(
                minItemWidth: 185,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StudentMetricCard(
                    icon: Icons.groups_rounded,
                    label: 'Total students',
                    value: '${s.students.length}',
                    note: '${s.classes.length} classes in school',
                    color: AdminColors.primary,
                    onTap: () => setState(() {
                      _classFilter = null;
                      _genderFilter = null;
                      _parentFilter = null;
                    }),
                  ),
                  _StudentMetricCard(
                    icon: Icons.male_rounded,
                    label: 'Boys',
                    value: '$boys',
                    note: 'View boys only',
                    color: AdminColors.blue,
                    onTap: () => setState(() => _genderFilter = 'Boy'),
                  ),
                  _StudentMetricCard(
                    icon: Icons.female_rounded,
                    label: 'Girls',
                    value: '$girls',
                    note: 'View girls only',
                    color: AdminColors.purple,
                    onTap: () => setState(() => _genderFilter = 'Girl'),
                  ),
                  _StudentMetricCard(
                    icon: Icons.family_restroom_rounded,
                    label: 'Parents joined',
                    value: '$joined',
                    note: '${s.students.length - joined} not connected yet',
                    color: AdminColors.orange,
                    onTap: () => setState(() => _parentFilter = 'joined'),
                  ),
                  _StudentMetricCard(
                    icon: Icons.alternate_email_rounded,
                    label: 'Parent email issues',
                    value: '$emailIssues',
                    note: emailIssues == 0
                        ? 'All emails look good'
                        : 'Missing or duplicate email',
                    color: emailIssues == 0
                        ? AdminColors.green
                        : AdminColors.red,
                    onTap: () => setState(() => _parentFilter = 'issues'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AdminCard(
                padding: const EdgeInsets.all(16),
                title: 'Student directory',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip('${list.length} shown', AdminColors.blue),
                    TextButton.icon(
                      onPressed: list.isEmpty
                          ? null
                          : () => setState(() {
                        final ids = list.map((c) => c.id).toSet();
                        if (_selected.containsAll(ids)) {
                          _selected.removeAll(ids);
                        } else {
                          _selected.addAll(ids);
                        }
                      }),
                      icon: const Icon(Icons.checklist_rounded, size: 15),
                      label: const Text('Select all shown'),
                    ),
                    TextButton.icon(
                      onPressed: list.isEmpty ? null : () => _copyCsv(list),
                      icon: const Icon(Icons.copy_all_rounded, size: 15),
                      label: const Text('Copy CSV'),
                    ),
                    if (_classFilter != null || _genderFilter != null ||
                        _parentFilter != null || _q.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _classFilter = null;
                          _genderFilter = null;
                          _parentFilter = null;
                          _q = '';
                          _search.clear();
                        }),
                        icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                        label: const Text('Clear filters'),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(
                      title: 'Enrolled students',
                      subtitle:
                      'Showing ${list.length} of ${s.students.length} records',
                      icon: Icons.school_rounded,
                    ),
                    if (_selected.isNotEmpty) _bulkBar(list),
                    if (s.students.isEmpty)
                      const EmptyState(
                        'No students yet. Add a student profile or ask a '
                            'teacher to register students from the Teacher app.',
                        icon: Icons.child_care_rounded,
                      )
                    else if (list.isEmpty)
                      const EmptyState(
                        'No students match the selected search or class filter.',
                        icon: Icons.search_off_rounded,
                      )
                    else
                      AdminTable(
                        emptyText: 'No student records found.',
                        columns: const [
                          '', 'Student', 'Roll', 'Class', 'Gender', 'Age',
                          'Attendance', 'Fees due',
                          'Parent / guardian', 'Parent contact', 'Parent app',
                          'Actions',
                        ],
                        rows: [
                          for (final c in list)
                            DataRow(
                              selected: _selected.contains(c.id),
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: _selected.contains(c.id),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selected.add(c.id);
                                      } else {
                                        _selected.remove(c.id);
                                      }
                                    }),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 165,
                                    child: Row(
                                      children: [
                                        AdminAvatar(
                                          name: c.name,
                                          size: 36,
                                          backgroundColor: c.gender == 'Girl'
                                              ? const Color(0xFFF4E9FF)
                                              : AdminColors.greenLight,
                                          foregroundColor: c.gender == 'Girl'
                                              ? AdminColors.purple
                                              : AdminColors.primary,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            maxLines: 1,
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
                                cellText('${c.rollNo}', bold: true),
                                cellText(c.className),
                                cellText(c.gender),
                                cellText(c.ageLabel(DateTime.now())),
                                cellText(
                                  (attMap[c.id]?[1] ?? 0) == 0
                                      ? '—'
                                      : '${((attMap[c.id]![0] * 100) / attMap[c.id]![1]).round()}%',
                                ),
                                cellText(
                                  (dueMap[c.id] ?? 0) == 0
                                      ? '—'
                                      : fmtMoney(dueMap[c.id]!),
                                  color: (dueMap[c.id] ?? 0) == 0
                                      ? null
                                      : AdminColors.red,
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 145,
                                    child: Text(
                                      c.parentName.isEmpty
                                          ? 'Not provided'
                                          : c.parentName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AdminColors.dark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                          c.parentEmail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AdminColors.dark,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (c.contacts.isNotEmpty &&
                                            c.contacts.first.phone.isNotEmpty)
                                          Text(
                                            c.contacts.first.phone,
                                            style: const TextStyle(
                                              color: AdminColors.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (_emailIssue(c, emailCounts) != null)
                                          Text(
                                            _emailIssue(c, emailCounts)!,
                                            style: const TextStyle(
                                              color: AdminColors.red,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  StatusChip(
                                    s.parentJoined(c) ? 'Joined' : 'Not joined',
                                    s.parentJoined(c)
                                        ? AdminColors.green
                                        : AdminColors.orange,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AdminIconAction(
                                        icon: Icons.visibility_outlined,
                                        tooltip: 'View profile',
                                        onPressed: () => _showProfile(c),
                                      ),
                                      const SizedBox(width: 6),
                                      AdminIconAction(
                                        icon: Icons.edit_outlined,
                                        tooltip: 'Edit student',
                                        onPressed: () => _openForm(existing: c),
                                      ),
                                      const SizedBox(width: 6),
                                      AdminIconAction(
                                        icon: Icons.delete_outline_rounded,
                                        tooltip: 'Delete student',
                                        color: AdminColors.red,
                                        onPressed: () => _delete(c),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AdminColors.muted, size: 15),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Deleting a student permanently removes linked records '
                          'according to the existing AdminState delete operation. '
                          'Review the confirmation carefully before proceeding.',
                      style: TextStyle(
                        color: AdminColors.muted,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({this.existing, this.defaultClassId});

  final ChildInfo? existing;
  final String? defaultClassId;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _roll;
  late final TextEditingController _parent;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _allergy;
  late final TextEditingController _pickup;

  String? _classId;
  String _gender = 'Boy';
  String? _blood;
  DateTime? _dob;
  String? _dobError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final s = AdminState.instance;
    _name = TextEditingController(text: e?.name ?? '');
    _parent = TextEditingController(text: e?.parentName ?? '');
    _email = TextEditingController(text: e?.parentEmail ?? '');
    _phone = TextEditingController(
      text: (e != null && e.contacts.isNotEmpty) ? e.contacts.first.phone : '',
    );
    _allergy = TextEditingController(text: e?.allergyNote ?? '');
    _pickup = TextEditingController(text: e?.pickupNote ?? '');

    _classId = e?.classId ?? widget.defaultClassId;
    if (_classId != null && !s.classes.any((c) => c.id == _classId)) {
      _classId = null;
    }
    _classId ??= s.classes.isNotEmpty ? s.classes.first.id : null;

    _roll = TextEditingController(
      text: e != null
          ? '${e.rollNo}'
          : '${_classId == null ? 1 : s.nextRollFor(_classId!)}',
    );
    if (e != null) {
      _gender = (e.gender == 'Girl') ? 'Girl' : 'Boy';
      _blood = _bloodGroups.contains(e.bloodGroup) ? e.bloodGroup : null;
      _dob = e.dob;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    _parent.dispose();
    _email.dispose();
    _phone.dispose();
    _allergy.dispose();
    _pickup.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 3, 1, 1),
      firstDate: DateTime(now.year - 12),
      lastDate: now,
    );
    if (d != null) {
      setState(() {
        _dob = d;
        _dobError = null;
      });
    }
  }

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    if (_dob == null) {
      setState(() => _dobError = 'Select the date of birth');
      return;
    }
    if (!formOk || _classId == null) return;
    final s = AdminState.instance;
    final cls = s.classes.firstWhere((c) => c.id == _classId);
    final phone = _phone.text.trim();
    final e = widget.existing;

    // Teacher ने जोडलेले इतर contacts (आई/बाबा/आजी...) पुसले जाऊ नयेत.
    final contacts = <ParentContact>[...(e?.contacts ?? const <ParentContact>[])];
    if (phone.isNotEmpty) {
      if (contacts.isEmpty) {
        contacts.add(ParentContact(_parent.text.trim(), 'Parent', phone));
      } else {
        final c0 = contacts.first;
        contacts[0] = ParentContact(
          c0.name.isEmpty ? _parent.text.trim() : c0.name,
          c0.relation.isEmpty ? 'Parent' : c0.relation,
          phone,
        );
      }
    } else if (contacts.isNotEmpty) {
      contacts.removeAt(0);
    }

    Navigator.pop(
      context,
      ChildInfo(
        id: e?.id ?? '',
        name: _name.text.trim(),
        className: cls.className,
        classId: cls.id,
        rollNo: int.tryParse(_roll.text.trim()) ?? s.nextRollFor(cls.id),
        dob: _dob!,
        bloodGroup: _blood ?? '',
        gender: _gender,
        allergyNote: _allergy.text.trim(),
        parentName: _parent.text.trim(),
        parentEmail: _email.text.trim().toLowerCase(),
        pickupNote: _pickup.text.trim(),
        contacts: contacts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminState.instance;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(isEdit ? 'Edit student' : 'Add student'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogField(_name, 'Student name', required: true),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _classId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: [
                            for (final c in s.classes)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.className),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _classId = v;
                            if (!isEdit && v != null) {
                              _roll.text = '${s.nextRollFor(v)}';
                            }
                          }),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: dialogField(
                        _roll,
                        'Roll no',
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 1) return 'Enter valid roll';
                          final dup = s.students.any((x) =>
                          x.classId == _classId &&
                              x.rollNo == n &&
                              x.id != (widget.existing?.id ?? ''));
                          return dup ? 'Taken' : null;
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (final g in const ['Boy', 'Girl']) ...[
                      ChoiceChip(
                        label: Text(g),
                        selected: _gender == g,
                        onSelected: (_) => setState(() => _gender = g),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _pickDob,
                      icon: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(_dob == null ? 'Date of birth' : fmtDate(_dob)),
                    ),
                  ],
                ),
                if (_dobError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_dobError!,
                        style: const TextStyle(
                            color: AdminColors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _blood,
                    decoration: const InputDecoration(labelText: 'Blood group'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Not set')),
                      for (final b in _bloodGroups)
                        DropdownMenuItem<String?>(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => _blood = v),
                  ),
                ),
                dialogField(_allergy, 'Allergy / medical note'),
                const Divider(),
                const SizedBox(height: 8),
                dialogField(_parent, 'Parent name', required: true),
                dialogField(
                  _email,
                  'Parent email (used for Parent app login)',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Required';
                    return t.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                dialogField(
                  _phone,
                  'Parent phone',
                  keyboard: TextInputType.phone,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    return digits.length >= 7 && digits.length <= 15
                        ? null
                        : 'Enter a valid phone number';
                  },
                ),
                dialogField(_pickup, 'Pickup note', maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: adminPrimaryButton(),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add student'),
        ),
      ],
    );
  }
}

/// Compact, tappable overview card for the Students screen.
class _StudentMetricCard extends StatelessWidget {
  const _StudentMetricCard({
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
          constraints: const BoxConstraints(minHeight: 90),
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
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AdminColors.dark,
                        fontSize: 21,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AdminColors.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}