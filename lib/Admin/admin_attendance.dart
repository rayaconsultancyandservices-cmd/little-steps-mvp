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

        return AdminPage(
          title: 'Attendance',
          subtitle: 'Marked by teachers · last ${AdminState.attendanceWindowDays} days available',
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
                  StatCard(
                    icon: Icons.check_circle_rounded,
                    label: 'Present',
                    value: '$present',
                    color: AdminColors.green,
                  ),
                  StatCard(
                    icon: Icons.schedule_rounded,
                    label: 'Late',
                    value: '$lateCount',
                    color: AdminColors.orange,
                  ),
                  StatCard(
                    icon: Icons.cancel_rounded,
                    label: 'Absent',
                    value: '$absent',
                    color: AdminColors.red,
                  ),
                  StatCard(
                    icon: Icons.help_outline_rounded,
                    label: 'Not marked',
                    value: '${notMarked.length}',
                    color: AdminColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AdminCard(
                title: 'Records for ${fmtDate(_date)}',
                child: AdminTable(
                  emptyText: 'No attendance has been marked for this day.',
                  columns: const ['Student', 'Class', 'Status', 'Reason'],
                  rows: [
                    for (final r in sorted)
                      DataRow(cells: [
                        cellText(s.studentName(r.studentId), bold: true),
                        cellText(s.classNameOf(r.classId)),
                        DataCell(_statusChip(r.status)),
                        cellText(r.reason),
                      ]),
                  ],
                ),
              ),
              if (notMarked.isNotEmpty && recs.isNotEmpty)
                AdminCard(
                  title: 'Not marked (${notMarked.length})',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in notMarked)
                        Chip(
                          label: Text('${c.name} · ${c.className}',
                              style: const TextStyle(fontSize: 12)),
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