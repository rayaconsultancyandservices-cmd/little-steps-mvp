import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Attendance: कोणत्याही दिवसाचा / class चा खरा attendance (teacher ने mark केलेला).
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  DateTime _date = DateTime.now();
  String? _classFilter;
  String? _statusFilter; // P, L, A, or N (not marked)

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: AdminState.attendanceWindowDays)),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  /// Admin कडून attendance दुरुस्त / नवीन mark (Teacher + Parent ला लगेच दिसतो).
  Future<void> _edit({
    required String classId,
    required String studentId,
    required String current,
    required String currentReason,
  }) async {
    final s = AdminState.instance;
    final day = AppState.dayKey(_date);
    String status = current.isEmpty ? 'P' : current;
    final reason = TextEditingController(text: currentReason);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Attendance · ${s.studentName(studentId)}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmtDate(_date)} · ${s.classNameOf(classId)}',
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.muted)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final o in const [
                      ['P', 'Present'],
                      ['L', 'Late'],
                      ['A', 'Absent'],
                    ])
                      ChoiceChip(
                        label: Text(o[1]),
                        selected: status == o[0],
                        onSelected: (_) => setD(() => status = o[0]),
                      ),
                  ],
                ),
                if (status != 'P') ...[
                  const SizedBox(height: 14),
                  dialogField(reason, 'Reason (optional)'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: adminPrimaryButton(),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await s.setAttendance(
        classId: classId,
        studentId: studentId,
        day: day,
        status: status,
        reason: reason.text,
      );
      if (mounted) adminSnack(context, 'Attendance saved');
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
        final day = AppState.dayKey(_date);
        final recs = s.attendanceOn(day, classId: _classFilter);
        final studentsInScope = _classFilter == null
            ? s.students
            : s.studentsOfClass(_classFilter!);

        final present = recs.where((r) => r.status == 'P').length;
        final lateCount = recs.where((r) => r.status == 'L').length;
        final absent = recs.where((r) => r.status == 'A').length;
        final markedIds = recs.map((r) => r.studentId).toSet();
        final notMarked =
        studentsInScope.where((c) => !markedIds.contains(c.id)).toList();

        // Absent आधी, मग late, मग present.
        int order(String st) => st == 'A' ? 0 : (st == 'L' ? 1 : 2);
        final sorted = [...recs]
          ..sort((a, b) => order(a.status).compareTo(order(b.status)));
        final visibleRecords = sorted
            .where((r) => _statusFilter == null || (_statusFilter != 'N' && r.status == _statusFilter))
            .toList();

        return AdminPage(
          title: 'Attendance',
          subtitle: 'Marked by teachers (you can correct it) · last ${AdminState.attendanceWindowDays} days available',
          actions: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(fmtDate(_date)),
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
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _AttendanceMetricCard(
                    icon: Icons.check_circle_rounded, label: 'Present', value: '$present',
                    color: AdminColors.green, selected: _statusFilter == 'P',
                    onTap: () => setState(() => _statusFilter = _statusFilter == 'P' ? null : 'P'),
                  ),
                  _AttendanceMetricCard(
                    icon: Icons.schedule_rounded, label: 'Late', value: '$lateCount',
                    color: AdminColors.orange, selected: _statusFilter == 'L',
                    onTap: () => setState(() => _statusFilter = _statusFilter == 'L' ? null : 'L'),
                  ),
                  _AttendanceMetricCard(
                    icon: Icons.cancel_rounded, label: 'Absent', value: '$absent',
                    color: AdminColors.red, selected: _statusFilter == 'A',
                    onTap: () => setState(() => _statusFilter = _statusFilter == 'A' ? null : 'A'),
                  ),
                  _AttendanceMetricCard(
                    icon: Icons.help_outline_rounded, label: 'Not marked', value: '${notMarked.length}',
                    color: AdminColors.muted, selected: _statusFilter == 'N',
                    onTap: () => setState(() => _statusFilter = _statusFilter == 'N' ? null : 'N'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AdminCard(
                title: 'Records for ${fmtDate(_date)}${_statusFilter == null ? '' : ' · ${_statusLabel(_statusFilter!)}'}',
                child: AdminTable(
                  emptyText: 'No attendance has been marked for this day.',
                  columns: const ['Student', 'Class', 'Status', 'Reason', ''],
                  rows: [
                    for (final r in visibleRecords)
                      DataRow(cells: [
                        cellText(s.studentName(r.studentId), bold: true),
                        cellText(s.classNameOf(r.classId)),
                        DataCell(_statusChip(r.status)),
                        cellText(r.reason),
                        DataCell(IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _edit(
                            classId: r.classId,
                            studentId: r.studentId,
                            current: r.status,
                            currentReason: r.reason,
                          ),
                        )),
                      ]),
                  ],
                ),
              ),
              if (notMarked.isNotEmpty && (_statusFilter == null || _statusFilter == 'N'))
                AdminCard(
                  title: 'Not marked (${notMarked.length}) · tap a name to mark',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in notMarked)
                        ActionChip(
                          label: Text('${c.name} · ${c.className}',
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () => _edit(
                            classId: c.classId,
                            studentId: c.id,
                            current: '',
                            currentReason: '',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'P': return 'Present';
      case 'L': return 'Late';
      case 'A': return 'Absent';
      case 'N': return 'Not marked';
      default: return 'All';
    }
  }

  Widget _statusChip(String st) {
    switch (st) {
      case 'P':
        return const StatusChip('Present', AdminColors.green);
      case 'L':
        return const StatusChip('Late', AdminColors.orange);
      case 'A':
        return const StatusChip('Absent', AdminColors.red);
    }
    return StatusChip(st, AdminColors.muted);
  }
}

/// Compact, clickable attendance summary tile.
class _AttendanceMetricCard extends StatelessWidget {
  const _AttendanceMetricCard({
    required this.icon, required this.label, required this.value,
    required this.color, required this.selected, required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(.09) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : const Color(0xFFE7EAF0), width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
