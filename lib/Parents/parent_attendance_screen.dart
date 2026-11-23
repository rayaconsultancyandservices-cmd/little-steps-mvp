import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'parent_home_screen.dart' show ParentColors, ParentPageBackground;

/// P9 · Attendance history (नवीन screen)
///
/// Parent ला आधी फक्त "आज" चा status दिसत होता. आता मुलाची महिन्यानुसार
/// पूर्ण हजेरी (Present / Late / Absent + कारण) आणि टक्केवारी दिसते.
/// Data: AppState.attendanceHistory (Firestore `attendance` — real-time).
///
/// Home वरील child card वर tap केल्यावर हा screen उघडतो.
class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  static const _presentFg = Color(0xFF22A06B);
  static const _presentBg = Color(0xFFE3F6EC);
  static const _lateFg = Color(0xFFE5A100);
  static const _lateBg = Color(0xFFFFF3D6);
  static const _absentFg = Color(0xFFE0533D);
  static const _absentBg = Color(0xFFFFE7E5);

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Color _fg(String s) =>
      s == 'P' ? _presentFg : (s == 'L' ? _lateFg : _absentFg);

  Color _bg(String s) =>
      s == 'P' ? _presentBg : (s == 'L' ? _lateBg : _absentBg);

  String _label(String s) =>
      s == 'P' ? 'Present' : (s == 'L' ? 'Late' : 'Absent');

  IconData _icon(String s) => s == 'P'
      ? Icons.check_circle_rounded
      : (s == 'L' ? Icons.access_time_filled_rounded : Icons.cancel_rounded);

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return ParentPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) {
              final s = AppState.instance;
              final days = s.attendanceHistory
                  .where((d) =>
              d.date.year == _month.year &&
                  d.date.month == _month.month &&
                  (d.status == 'P' || d.status == 'L' || d.status == 'A'))
                  .toList();
              final present = days.where((d) => d.status == 'P').length;
              final late = days.where((d) => d.status == 'L').length;
              final absent = days.where((d) => d.status == 'A').length;
              final total = days.length;
              final percent = total == 0 ? 0 : ((present + late) * 100 ~/ total);

              return Column(
                children: [
                  _header(context, s),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _monthBar(),
                        const SizedBox(height: 12),
                        _summary(percent, present, late, absent, total),
                        const SizedBox(height: 16),
                        if (days.isEmpty)
                          _empty()
                        else
                          for (final d in days) _dayRow(d),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- header ----------
  Widget _header(BuildContext context, AppState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ParentColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x142B8FDB),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: ParentColors.dark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.child.name.isEmpty
                      ? 'Daily record'
                      : '${s.child.name} · ${s.child.className}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ParentColors.muted,
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

  // ---------- month switcher ----------
  Widget _monthBar() {
    Widget arrow(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? .35 : 1,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ParentColors.border),
          ),
          child: Icon(icon, size: 20, color: ParentColors.dark),
        ),
      ),
    );

    return Row(
      children: [
        arrow(Icons.chevron_left_rounded, () => _shift(-1)),
        Expanded(
          child: Center(
            child: Text(
              '${AppState.monthName(_month.month)} ${_month.year}',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: ParentColors.dark,
              ),
            ),
          ),
        ),
        arrow(Icons.chevron_right_rounded,
            _isCurrentMonth ? null : () => _shift(1)),
      ],
    );
  }

  // ---------- summary card ----------
  Widget _summary(int percent, int present, int late, int absent, int total) {
    Widget stat(String label, int value, Color fg) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x552B8FDB),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total == 0 ? '—' : '$percent%',
                style: const TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  total == 0
                      ? 'No records this month'
                      : 'attendance · $total school day${total == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .92),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Present', present, _presentFg),
              const SizedBox(width: 8),
              stat('Late', late, _lateFg),
              const SizedBox(width: 8),
              stat('Absent', absent, _absentFg),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- one day ----------
  Widget _dayRow(AttendanceDay d) {
    final fg = _fg(d.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParentColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: ParentColors.tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(
                  '${d.date.day}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.primary,
                  ),
                ),
                Text(
                  _wd[d.date.weekday - 1],
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppState.relativeDay(d.date) == 'Today' ||
                      AppState.relativeDay(d.date) == 'Yesterday'
                      ? AppState.relativeDay(d.date)
                      : AppState.dateLabel(d.date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
                if (d.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    d.reason,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ParentColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _bg(d.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(d.status), size: 13, color: fg),
                const SizedBox(width: 4),
                Text(
                  _label(d.status),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: const [
        Icon(Icons.event_available_rounded,
            size: 38, color: Color(0xFF9DB6CA)),
        SizedBox(height: 10),
        Text(
          'No attendance marked in this month yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: ParentColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}