import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Admin dashboard: all figures are calculated from live AdminState data.
/// No demo or hard-coded school statistics are used.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.onNavigate});

  /// Sidebar indexes: 1 Teachers, 2 Students, 3 Classes, 4 Parents,
  /// 5 Attendance, 6 Fees, 7 Circulars & Events, 8 Diary,
  /// 9 Photos, 10 Messages.
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = AdminState.instance;
    final today = s.todayKey;
    final todayPct = s.attendancePercent(today);

    final recentCirculars = s.circulars.take(5).toList();
    final pendingTeachers = s.teachers.where((t) => !t.approved).toList();

    return AdminPage(
      title: 'Welcome, ${s.adminName}',
      subtitle: s.schoolName.isEmpty
          ? 'Here is what is happening at your school today.'
          : '${s.schoolName}  •  School overview',
      actions: [
        OutlinedButton.icon(
          style: adminSecondaryButton(),
          onPressed: () => onNavigate(5),
          icon: const Icon(Icons.fact_check_outlined, size: 17),
          label: const Text('Attendance'),
        ),
        FilledButton.icon(
          style: adminPrimaryButton(),
          onPressed: () => onNavigate(2),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
          label: const Text('Students'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErrorBanner(s.lastError),
          _WelcomePanel(
            schoolName: s.schoolName,
            teacherCount: s.teachers.length,
            studentCount: s.students.length,
            attendancePercent: todayPct,
          ),
          const SizedBox(height: 23),

          const AdminSectionHeader(
            title: 'School at a glance',
            subtitle: 'Live summary from your school records',
            icon: Icons.space_dashboard_rounded,
          ),
          AdminResponsiveGrid(
            minItemWidth: 166,
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardStatCard(
                icon: Icons.badge_rounded,
                label: 'Teachers',
                value: '${s.teachers.length}',
                note: '${s.pendingTeachersCount} awaiting approval',
                color: AdminColors.blue,
                onTap: () => onNavigate(1),
              ),
              _DashboardStatCard(
                icon: Icons.child_care_rounded,
                label: 'Students',
                value: '${s.students.length}',
                note: '${s.classes.length} active classes',
                color: AdminColors.primary,
                onTap: () => onNavigate(2),
              ),
              _DashboardStatCard(
                icon: Icons.meeting_room_rounded,
                label: 'Classes',
                value: '${s.classes.length}',
                note: 'School sections',
                color: AdminColors.purple,
                onTap: () => onNavigate(3),
              ),
              _DashboardStatCard(
                icon: Icons.family_restroom_rounded,
                label: 'Parents on app',
                value: '${s.parentsJoinedCount}',
                note: 'of ${s.students.length} families',
                color: AdminColors.orange,
                onTap: () => onNavigate(4),
              ),
              _DashboardStatCard(
                icon: Icons.fact_check_rounded,
                label: "Today's attendance",
                value: todayPct == null ? '—' : '$todayPct%',
                note: todayPct == null
                    ? 'Attendance not marked yet'
                    : '${s.todayPresent} present · ${s.todayAbsent} absent',
                color: AdminColors.green,
                onTap: () => onNavigate(5),
              ),
              _DashboardStatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Fees collected',
                value: fmtMoney(s.collectedFeesTotal),
                note: '${s.receipts.length} receipts',
                color: AdminColors.green,
                onTap: () => onNavigate(6),
              ),
              _DashboardStatCard(
                icon: Icons.payments_rounded,
                label: 'Fees pending',
                value: fmtMoney(s.pendingFeesTotal),
                note: '${s.studentsWithDues} students with dues',
                color: AdminColors.red,
                onTap: () => onNavigate(6),
              ),
              _DashboardStatCard(
                icon: Icons.menu_book_rounded,
                label: "Today's diary",
                value:
                '${s.classesWithDiaryToday.length}/${s.classes.length}',
                note: 'classes published',
                color: AdminColors.purple,
                onTap: () => onNavigate(8),
              ),
              _DashboardStatCard(
                icon: Icons.photo_library_rounded,
                label: 'Photos today',
                value: '${s.photosTodayCount}',
                note: '${s.photos.length} photos in total',
                color: AdminColors.blue,
                onTap: () => onNavigate(9),
              ),
              _DashboardStatCard(
                icon: Icons.forum_rounded,
                label: 'Conversations',
                value: '${s.threads.length}',
                note: '${s.teacherUnreadTotal} unread by teachers',
                color: AdminColors.orange,
                onTap: () => onNavigate(10),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (pendingTeachers.isNotEmpty) ...[
            _PendingApprovals(
              teachers: pendingTeachers,
              onOpenAll: () => onNavigate(1),
            ),
            const SizedBox(height: 20),
          ],

          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              final chart = AdminCard(
                title: 'Weekly attendance',
                trailing: TextButton(
                  onPressed: () => onNavigate(5),
                  child: const Text('View report'),
                ),
                child: _WeekChart(state: s),
              );
              final feeSummary = _FeeSummary(
                collected: s.collectedFeesTotal,
                pending: s.pendingFeesTotal,
                onOpen: () => onNavigate(6),
              );

              if (!wide) {
                return Column(
                  children: [
                    chart,
                    feeSummary,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chart),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: feeSummary),
                ],
              );
            },
          ),

          AdminCard(
            title: "Today's attendance by class",
            trailing: TextButton.icon(
              onPressed: () => onNavigate(5),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('Open attendance'),
            ),
            child: AdminTable(
              emptyText: 'No classes found. Add a class to start managing '
                  'students and attendance.',
              columns: const [
                'Class',
                'Teacher',
                'Students',
                'Present',
                'Absent',
                'Status',
              ],
              rows: [
                for (final c in s.classes) _classRow(s, c, today),
              ],
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              final circularCard = AdminCard(
                title: 'Recent circulars',
                trailing: TextButton(
                  onPressed: () => onNavigate(7),
                  child: const Text('View all'),
                ),
                child: recentCirculars.isEmpty
                    ? const EmptyState(
                  'No circulars have been published yet.',
                  icon: Icons.campaign_outlined,
                )
                    : Column(
                  children: [
                    for (final c in recentCirculars)
                      _ActivityTile(
                        icon: Icons.campaign_rounded,
                        iconColor: AdminColors.blue,
                        title: c.title,
                        subtitle:
                        '${s.classNameOf(c.classId)}  •  '
                            '${fmtDate(c.sentAt)}',
                        trailing: StatusChip(
                          c.category,
                          AdminColors.blue,
                        ),
                      ),
                  ],
                ),
              );

              final eventCard = AdminCard(
                title: 'Upcoming events & holidays',
                trailing: TextButton(
                  onPressed: () => onNavigate(7),
                  child: const Text('Manage'),
                ),
                child: _UpcomingEvents(state: s),
              );

              if (!wide) {
                return Column(
                  children: [circularCard, eventCard],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: circularCard),
                  const SizedBox(width: 16),
                  Expanded(child: eventCard),
                ],
              );
            },
          ),

          const SizedBox(height: 5),
          _QuickActions(onNavigate: onNavigate),
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

    return DataRow(
      cells: [
        cellText(c.className, bold: true),
        cellText(c.teacherName.isEmpty ? 'Not assigned' : c.teacherName),
        cellText('$total'),
        cellText(marked ? '$present' : '—', color: AdminColors.green),
        cellText(marked ? '$absent' : '—', color: AdminColors.red),
        DataCell(
          StatusChip(
            marked ? 'Marked' : 'Pending',
            marked ? AdminColors.green : AdminColors.orange,
          ),
        ),
      ],
    );
  }
}

/// Dashboard-only compact statistic card.
/// Kept local to this file so other Admin screens retain their existing StatCard UI.
class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.note,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.border),
            boxShadow: [
              BoxShadow(
                color: AdminColors.dark.withValues(alpha: 0.035),
                blurRadius: 11,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: color.withValues(alpha: 0.65),
                    size: 15,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AdminColors.dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.muted,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.schoolName,
    required this.teacherCount,
    required this.studentCount,
    required this.attendancePercent,
  });

  final String schoolName;
  final int teacherCount;
  final int studentCount;
  final int? attendancePercent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_month(now.month)} ${now.day}, ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF183A40), Color(0xFF246B65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183A40).withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final summary = Wrap(
            spacing: 22,
            runSpacing: 14,
            children: [
              _WelcomeMetric(
                icon: Icons.people_alt_rounded,
                value: '$studentCount',
                label: 'Students',
              ),
              _WelcomeMetric(
                icon: Icons.badge_rounded,
                value: '$teacherCount',
                label: 'Teachers',
              ),
              _WelcomeMetric(
                icon: Icons.fact_check_rounded,
                value: attendancePercent == null
                    ? '—'
                    : '$attendancePercent%',
                label: 'Attendance today',
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 39,
                    width: 39,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: Color(0xFFFFD58A),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      schoolName.isEmpty ? 'Your school, at a glance' : schoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!compact)
                    Text(
                      date,
                      style: const TextStyle(
                        color: Color(0xFFC4DEDA),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                'A quick look at your school’s activity and performance.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Divider(
                color: Colors.white.withValues(alpha: 0.17),
                height: 1,
              ),
              const SizedBox(height: 18),
              summary,
              if (compact) ...[
                const SizedBox(height: 13),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFFC4DEDA),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _month(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }
}

class _WelcomeMetric extends StatelessWidget {
  const _WelcomeMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF9DE0C9), size: 19),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC4DEDA),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingApprovals extends StatelessWidget {
  const _PendingApprovals({
    required this.teachers,
    required this.onOpenAll,
  });

  final List<AdminTeacher> teachers;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final s = AdminState.instance;

    return AdminCard(
      title: 'Teacher approvals',
      trailing: TextButton(
        onPressed: onOpenAll,
        child: const Text('Manage teachers'),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AdminColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  color: AdminColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${teachers.length} teacher account(s) need your review.',
                  style: const TextStyle(
                    color: AdminColors.dark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip('${teachers.length} pending', AdminColors.orange),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AdminColors.border, height: 1),
          for (final t in teachers.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AdminAvatar(
                name: t.name.isEmpty ? t.email : t.name,
                backgroundColor: const Color(0xFFFFF0D9),
                foregroundColor: AdminColors.orange,
              ),
              title: Text(
                t.name.isEmpty ? t.email : t.name,
                style: const TextStyle(
                  color: AdminColors.dark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              subtitle: Text(
                '${t.email}  •  '
                    '${t.className.isEmpty ? 'No class assigned' : t.className}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.muted,
                  fontSize: 10,
                ),
              ),
              trailing: FilledButton(
                style: adminPrimaryButton(),
                onPressed: () async {
                  try {
                    await s.setTeacherApproved(t, true);
                    if (context.mounted) {
                      adminSnack(
                        context,
                        '${t.name.isEmpty ? t.email : t.name} approved',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      adminSnack(
                        context,
                        AdminState.errorText(e),
                        error: true,
                      );
                    }
                  }
                },
                child: const Text('Approve'),
              ),
            ),
          if (teachers.length > 4)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpenAll,
                child: Text('View ${teachers.length - 4} more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeeSummary extends StatelessWidget {
  const _FeeSummary({
    required this.collected,
    required this.pending,
    required this.onOpen,
  });

  final int collected;
  final int pending;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final total = collected + pending;
    final collectedRatio = total <= 0 ? 0.0 : collected / total;

    return AdminCard(
      title: 'Fee collection',
      trailing: AdminIconAction(
        icon: Icons.arrow_forward_rounded,
        tooltip: 'Open fees',
        onPressed: onOpen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmtMoney(collected),
            style: const TextStyle(
              color: AdminColors.dark,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Total fees collected',
            style: TextStyle(
              color: AdminColors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: collectedRatio,
              minHeight: 9,
              backgroundColor: AdminColors.redLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AdminColors.green,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FeeLegend(
            color: AdminColors.green,
            label: 'Collected',
            amount: fmtMoney(collected),
          ),
          const SizedBox(height: 10),
          _FeeLegend(
            color: AdminColors.red,
            label: 'Pending',
            amount: fmtMoney(pending),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: adminSecondaryButton(),
              onPressed: onOpen,
              child: const Text('View fee details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeLegend extends StatelessWidget {
  const _FeeLegend({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 9,
          width: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AdminColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: AdminColors.dark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        height: 39,
        width: 39,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AdminColors.dark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AdminColors.muted,
          fontSize: 10,
        ),
      ),
      trailing: trailing,
    );
  }
}

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final seen = <String>{};

    final upcoming = state.events
        .where((e) => !e.date.isBefore(start))
        .where((e) => seen.add('${e.title}|${e.date}'))
        .take(5)
        .toList();

    if (upcoming.isEmpty) {
      return const EmptyState(
        'No upcoming events have been added.',
        icon: Icons.event_available_rounded,
      );
    }

    return Column(
      children: [
        for (final event in upcoming)
          _ActivityTile(
            icon: Icons.event_rounded,
            iconColor: AdminColors.purple,
            title: event.title,
            subtitle: fmtDate(event.date),
            trailing: StatusChip(event.category, AdminColors.purple),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.person_add_alt_1_rounded, 'Students', 2),
      (Icons.badge_rounded, 'Teachers', 1),
      (Icons.class_rounded, 'Classes', 3),
      (Icons.payments_rounded, 'Fees', 6),
      (Icons.campaign_rounded, 'Circulars', 7),
      (Icons.photo_library_rounded, 'Photos', 9),
    ];

    return AdminCard(
      title: 'Quick access',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final action in actions)
            OutlinedButton.icon(
              style: adminSecondaryButton(),
              onPressed: () => onNavigate(action.$3),
              icon: Icon(action.$1, size: 16),
              label: Text(action.$2),
            ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );

    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    const maxBar = 112.0;

    return SizedBox(
      height: 166,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (i) {
          final day = DateTime(
            monday.year,
            monday.month,
            monday.day + i,
          );
          final pct = state.attendancePercent(AppState.dayKey(day));
          final isToday = AppState.sameDay(day, now);
          final barColor = isToday
              ? AdminColors.primary
              : const Color(0xFFBFE3DA);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  pct == null ? '—' : '$pct%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isToday ? AdminColors.primary : AdminColors.muted,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  height: maxBar,
                  width: 35,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6F5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    height: pct == null
                        ? 4
                        : (maxBar * pct / 100).clamp(4.0, maxBar),
                    width: 35,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  names[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
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
