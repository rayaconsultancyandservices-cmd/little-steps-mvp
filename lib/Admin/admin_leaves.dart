import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

/// Leave Requests (रजेचे अर्ज): Parent app मधून आलेले सर्व classes चे अर्ज.
///
/// आधी Admin ला फक्त Dashboard वर pending संख्या दिसत होती; आता इथे
///  - सर्व अर्ज (Student, Class, Parent, dates, days, reason, status, note)
///  - Class / Status filter + search
///  - Approve / Decline (note सहित), Reopen (पुन्हा pending), Delete
/// करता येतं. Class teacher ने दिलेला निर्णय आणि Admin चा निर्णय दोन्ही
/// Parent app मध्ये लगेच दिसतात (Firestore: classes/{classId}/leaves).
class AdminLeavesScreen extends StatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  State<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends State<AdminLeavesScreen> {
  final TextEditingController _search = TextEditingController();
  String _q = '';
  String? _classFilter;
  String? _statusFilter; // null = सर्व, 'pending' / 'approved' / 'declined'

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------
  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AdminColors.green;
      case 'declined':
        return AdminColors.red;
      default:
        return AdminColors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      default:
        return 'Pending';
    }
  }

  int _days(AdminLeave l) {
    if (l.fromDate == null || l.toDate == null) return 0;
    final f = DateTime(l.fromDate!.year, l.fromDate!.month, l.fromDate!.day);
    final t = DateTime(l.toDate!.year, l.toDate!.month, l.toDate!.day);
    return t.difference(f).inDays + 1;
  }

  String _range(AdminLeave l) {
    if (l.fromDate == null && l.toDate == null) return '—';
    final a = fmtDate(l.fromDate);
    final b = fmtDate(l.toDate);
    return a == b ? a : '$a – $b';
  }

  String _name(AdminLeave l) {
    if (l.studentName.trim().isNotEmpty) return l.studentName;
    return AdminState.instance.studentName(l.studentId);
  }

  // ------------------------------------------------------------------
  // actions
  // ------------------------------------------------------------------
  Future<void> _decide(AdminLeave l, {required bool approve}) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _DecisionDialog(
        approve: approve,
        studentName: _name(l),
        range: _range(l),
      ),
    );
    if (note == null || !mounted) return;

    try {
      await AdminState.instance.decideLeave(l, approved: approve, note: note);
      if (mounted) {
        adminSnack(
          context,
          approve ? 'Leave approved' : 'Leave declined',
        );
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _reopen(AdminLeave l) async {
    final ok = await adminConfirm(
      context,
      title: 'Reopen this application?',
      message: 'The application of ${_name(l)} will go back to Pending and '
          'the previous decision note will be cleared.',
      confirmText: 'Reopen',
      danger: false,
    );
    if (!ok) return;
    try {
      await AdminState.instance.reopenLeave(l);
      if (mounted) adminSnack(context, 'Application moved back to pending');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _delete(AdminLeave l) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete this application?',
      message: 'The leave application of ${_name(l)} '
          '(${_range(l)}) will be removed from the Parent and Teacher apps too.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteLeave(l);
      if (mounted) adminSnack(context, 'Application deleted');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _view(AdminLeave l) async {
    final s = AdminState.instance;

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AdminColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v.trim().isEmpty ? '—' : v,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.dark,
              ),
            ),
          ),
        ],
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Leave · ${_name(l)}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    _statusLabel(l.status),
                    _statusColor(l.status),
                  ),
                ),
                const SizedBox(height: 10),
                row('Class', s.classNameOf(l.classId)),
                row('Class teacher', s.teacherOfClass(l.classId)?.name ?? ''),
                row('Parent', l.parentName),
                row('Leave dates', _range(l)),
                row('Total days', '${_days(l)}'),
                row('Applied on', fmtDate(l.createdAt)),
                row('Reason', l.reason),
                if (l.status != 'pending') ...[
                  row('Decided on', fmtDate(l.decidedAt)),
                  row('Note', l.teacherNote),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final all = s.leaves;
        final q = _q.trim().toLowerCase();

        final list = all.where((l) {
          if (_classFilter != null && l.classId != _classFilter) return false;
          if (_statusFilter != null && l.status != _statusFilter) return false;
          if (q.isNotEmpty) {
            final hay = '${_name(l)} ${l.parentName} ${l.reason} '
                '${s.classNameOf(l.classId)}'
                .toLowerCase();
            if (!hay.contains(q)) return false;
          }
          return true;
        }).toList();

        final pending = all.where((l) => l.status == 'pending').length;
        final approved = all.where((l) => l.status == 'approved').length;
        final declined = all.where((l) => l.status == 'declined').length;
        final onLeaveToday = s.onLeaveStudentIds.length;

        return AdminPage(
          title: 'Leave Requests',
          subtitle: 'Leave applications sent by parents (all classes)',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search student, parent, reason',
              onChanged: (v) => setState(() => _q = v),
            ),
            AdminDropdown<String?>(
              label: 'Class',
              width: 200,
              value: _classFilter,
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All classes')),
                for (final c in s.classes)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.className)),
              ],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
            AdminDropdown<String?>(
              label: 'Status',
              width: 180,
              value: _statusFilter,
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All')),
                DropdownMenuItem<String?>(
                    value: 'pending', child: Text('Pending')),
                DropdownMenuItem<String?>(
                    value: 'approved', child: Text('Approved')),
                DropdownMenuItem<String?>(
                    value: 'declined', child: Text('Declined')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  StatCard(
                    icon: Icons.event_note_rounded,
                    label: 'Total applications',
                    value: '${all.length}',
                    color: AdminColors.primary,
                  ),
                  StatCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    value: '$pending',
                    note: 'awaiting decision',
                    color: AdminColors.orange,
                  ),
                  StatCard(
                    icon: Icons.check_circle_rounded,
                    label: 'Approved',
                    value: '$approved',
                    color: AdminColors.green,
                  ),
                  StatCard(
                    icon: Icons.cancel_rounded,
                    label: 'Declined',
                    value: '$declined',
                    color: AdminColors.red,
                  ),
                  StatCard(
                    icon: Icons.beach_access_rounded,
                    label: 'On leave today',
                    value: '$onLeaveToday',
                    note: 'approved leave',
                    color: AdminColors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AdminCard(
                title: 'Applications (${list.length})',
                child: AdminTable(
                  emptyText: all.isEmpty
                      ? 'No leave application has been sent yet.'
                      : 'No application matches the filters.',
                  columns: const [
                    'Student',
                    'Class',
                    'Parent',
                    'Leave dates',
                    'Days',
                    'Reason',
                    'Applied',
                    'Status',
                    '',
                  ],
                  rows: [
                    for (final l in list)
                      DataRow(cells: [
                        cellText(_name(l), bold: true),
                        cellText(s.classNameOf(l.classId)),
                        cellText(l.parentName),
                        cellText(_range(l)),
                        cellText('${_days(l)}'),
                        cellText(l.reason),
                        cellText(fmtDate(l.createdAt)),
                        DataCell(StatusChip(
                          _statusLabel(l.status),
                          _statusColor(l.status),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (l.status == 'pending') ...[
                              IconButton(
                                tooltip: 'Approve',
                                icon: const Icon(Icons.check_circle_outline_rounded,
                                    size: 20, color: AdminColors.green),
                                onPressed: () => _decide(l, approve: true),
                              ),
                              IconButton(
                                tooltip: 'Decline',
                                icon: const Icon(Icons.highlight_off_rounded,
                                    size: 20, color: AdminColors.red),
                                onPressed: () => _decide(l, approve: false),
                              ),
                            ] else
                              IconButton(
                                tooltip: 'Reopen (back to pending)',
                                icon: const Icon(Icons.undo_rounded, size: 19),
                                onPressed: () => _reopen(l),
                              ),
                            IconButton(
                              tooltip: 'View',
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 19),
                              onPressed: () => _view(l),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 19, color: AdminColors.red),
                              onPressed: () => _delete(l),
                            ),
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

/// Approve / Decline साठी note घेणारा dialog. Controller स्वतः dispose करतो.
class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({
    required this.approve,
    required this.studentName,
    required this.range,
  });

  final bool approve;
  final String studentName;
  final String range;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.approve ? AdminColors.green : AdminColors.red;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.approve ? 'Approve leave?' : 'Decline leave?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.studentName}  •  ${widget.range}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.dark,
              ),
            ),
            const SizedBox(height: 14),
            dialogField(
              _note,
              'Note for parent (optional)',
              maxLines: 3,
              hint: widget.approve
                  ? 'e.g. Get well soon'
                  : 'e.g. Exam on these days',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(widget.approve ? 'Approve' : 'Decline'),
        ),
      ],
    );
  }
}