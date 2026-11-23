import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Dashboard: सर्व आकडे Firestore मधल्या खऱ्या data वरून (dummy नाही).
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.onNavigate});

  /// Sidebar tab बदलण्यासाठी (1 Teachers, 2 Students, 3 Classes ...).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = AdminState.instance;
    final today = s.todayKey;
    final todayPct = s.attendancePercent(today);
    final recent = s.circulars.take(5).toList();

    return AdminPage(
      title: 'Welcome, ${s.adminName}',
      subtitle: s.schoolName.isEmpty
          ? 'School overview'
          : '${s.schoolName} · School overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErrorBanner(s.lastError),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              StatCard(
                icon: Icons.badge_rounded,
                label: 'Teachers',
                value: '${s.teachers.length}',
                color: AdminColors.blue,
              ),
              StatCard(
                icon: Icons.child_care_rounded,
                label: 'Students',
                value: '${s.students.length}',
                color: AdminColors.primary,
              ),
              StatCard(
                icon: Icons.class_rounded,
                label: 'Classes',
                value: '${s.classes.length}',
                color: AdminColors.purple,
              ),
              StatCard(
                icon: Icons.family_restroom_rounded,
                label: 'Parents on app',
                value: '${s.parentsJoinedCount}',
                note: 'of ${s.students.length} families',
                color: AdminColors.orange,
              ),
              StatCard(
                icon: Icons.fact_check_rounded,
                label: "Today's attendance",
                value: todayPct == null ? '—' : '$todayPct%',
                note: todayPct == null
                    ? 'Not marked yet'
                    : '${s.todayPresent} present · ${s.todayAbsent} absent',
                color: AdminColors.green,
              ),
              StatCard(
                icon: Icons.payments_rounded,
                label: 'Fees pending',
                value: fmtMoney(s.pendingFeesTotal),
                note: '${s.studentsWithDues} students',
                color: AdminColors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          AdminCard(
            title: 'This week · school attendance',
            child: _WeekChart(state: s),
          ),
          AdminCard(
            title: "Today's attendance by class",
            trailing: TextButton(
              onPressed: () => onNavigate(5),
              child: const Text('Open attendance'),
            ),
            child: AdminTable(
              emptyText: 'No classes yet. Teachers create a class when they '
                  'register, or add one from the Classes tab.',
              columns: const [
                'Class',
                'Teacher',
                'Students',
                'Present',
                'Absent',
                'Status',
              ],
              rows: [
                for (final c in s.classes)
                  _classRow(s, c, today),
              ],
            ),
          ),
          AdminCard(
            title: 'Recent circulars',
            trailing: TextButton(
              onPressed: () => onNavigate(7),
              child: const Text('Manage'),
            ),
            child: recent.isEmpty
                ? const EmptyState('No circulars sent yet.')
                : Column(
              children: [
                for (final c in recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9F2FF),
                      child: Icon(Icons.campaign_rounded,
                          color: AdminColors.blue, size: 20),
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${s.classNameOf(c.classId)} · ${fmtDate(c.sentAt)} · '
                          '${c.readCount}/${c.families} read',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: StatusChip(c.category, AdminColors.blue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _classRow(AdminState s, AdminClass c, String today) {
    final rows = s.attendanceOn(today, classId: c.id);
    final present = rows.where((r) => r.isPresent).length;
    final absent = rows.where((r) => r.status == 'A').length;
    final total = s.studentsOfClass(c.id).length;
    final marked = rows.isNotEmpty;
    return DataRow(cells: [
      cellText(c.className, bold: true),
      cellText(c.teacherName.isEmpty ? 'Not assigned' : c.teacherName),
      cellText('$total'),
      cellText(marked ? '$present' : '—'),
      cellText(marked ? '$absent' : '—'),
      DataCell(marked
          ? const StatusChip('Marked', AdminColors.green)
          : const StatusChip('Pending', AdminColors.orange)),
    ]);
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    const maxBar = 120.0;

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (i) {
          final d = DateTime(monday.year, monday.month, monday.day + i);
          final pct = state.attendancePercent(AppState.dayKey(d));
          final isToday = AppState.sameDay(d, now);
          final color =
          isToday ? AdminColors.primary : const Color(0xFFBFE3DA);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  pct == null ? '—' : '$pct%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isToday ? AdminColors.primary : AdminColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 34,
                  height: pct == null
                      ? 4.0
                      : (maxBar * pct / 100).clamp(4.0, maxBar).toDouble(),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  names[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: AdminColors.dark,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}