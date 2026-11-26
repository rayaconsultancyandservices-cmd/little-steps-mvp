import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'parent_home_screen.dart' show ParentColors, ParentPageBackground;
import 'parent_leave_screen.dart';

/// P9 · Attendance (Parent)
///
/// मुलाची महिन्यानुसार हजेरी — real-life attendance apps सारखी:
///  - लहान summary card (टक्केवारी ring + Present / Late / Absent)
///  - Overall % आणि सलग हजेरीचा streak
///  - 75% पेक्षा कमी असेल तर सूचना
///  - रंगीत महिना calendar (Present / Late / Absent / Leave) — दिवसावर tap
///    केल्यावर details (कारण, रजा)
///  - Present / Late / Absent filter सह दिवसांची यादी
///  - महिना बदलायला arrows किंवा swipe
///  - "Apply for leave" shortcut
/// Data: AppState.attendanceHistory (Firestore `attendance` — real-time).
///
/// Home वरील quick-action मधील "Attendance" tab वरून हा screen उघडतो.
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

  /// याच्या खाली टक्केवारी गेली तर सूचना दाखवतो.
  static const int _lowLimit = 75;

  late DateTime _month;

  /// null = All, नाहीतर 'P' / 'L' / 'A'.
  String? _filter;

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

  void _goToCurrentMonth() {
    final n = DateTime.now();
    setState(() => _month = DateTime(n.year, n.month));
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

  bool _valid(String s) => s == 'P' || s == 'L' || s == 'A';

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _wdLetter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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

              // ----- या महिन्याची हजेरी -----
              final days = s.attendanceHistory
                  .where((d) =>
              d.date.year == _month.year &&
                  d.date.month == _month.month &&
                  _valid(d.status))
                  .toList();
              final present = days.where((d) => d.status == 'P').length;
              final late = days.where((d) => d.status == 'L').length;
              final absent = days.where((d) => d.status == 'A').length;
              final total = days.length;
              final percent =
              total == 0 ? 0 : ((present + late) * 100 ~/ total);

              // ----- आतापर्यंतची एकूण हजेरी + streak -----
              final everything =
              s.attendanceHistory.where((d) => _valid(d.status)).toList();
              final everAttended = everything
                  .where((d) => d.status == 'P' || d.status == 'L')
                  .length;
              final overall = everything.isEmpty
                  ? 0
                  : (everAttended * 100 ~/ everything.length);
              var streak = 0;
              for (final d in s.attendanceHistory) {
                if (d.status == 'P' || d.status == 'L') {
                  streak++;
                } else if (d.status == 'A') {
                  break;
                }
              }

              final byDay = <int, AttendanceDay>{
                for (final d in days) d.date.day: d,
              };
              final shown = _filter == null
                  ? days
                  : days.where((d) => d.status == _filter).toList();

              return GestureDetector(
                // महिना बदलायला swipe: उजवीकडे = मागचा, डावीकडे = पुढचा.
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 350) {
                    _shift(-1);
                  } else if (v < -350 && !_isCurrentMonth) {
                    _shift(1);
                  }
                },
                child: Column(
                  children: [
                    _header(context, s),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          _monthBar(),
                          const SizedBox(height: 12),
                          _summary(percent, present, late, absent, total),
                          if (everything.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _miniStats(overall, streak),
                          ],
                          if (total >= 3 && percent < _lowLimit) ...[
                            const SizedBox(height: 10),
                            _lowBanner(percent),
                          ],
                          const SizedBox(height: 14),
                          _calendar(s, byDay),
                          const SizedBox(height: 8),
                          _legend(),
                          const SizedBox(height: 16),
                          // या महिन्यातील रजेचे अर्ज
                          ..._leaveSection(s),
                          _title('Daily record'),
                          if (days.isNotEmpty) ...[
                            _filters(days.length, present, late, absent),
                            const SizedBox(height: 10),
                          ],
                          if (days.isEmpty)
                            _empty('No attendance marked in this month yet.')
                          else if (shown.isEmpty)
                            _empty(
                                'No ${_label(_filter!).toLowerCase()} days this month.')
                          else
                            for (final d in shown) _dayRow(d),
                          const SizedBox(height: 6),
                          _applyLeave(context),
                        ],
                      ),
                    ),
                  ],
                ),
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
          child: Column(
            children: [
              Text(
                '${AppState.monthName(_month.month)} ${_month.year}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark,
                ),
              ),
              // दुसऱ्या महिन्यात असताना चालू महिन्यावर लगेच परत जायला.
              if (!_isCurrentMonth)
                GestureDetector(
                  onTap: _goToCurrentMonth,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Back to this month',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        arrow(Icons.chevron_right_rounded,
            _isCurrentMonth ? null : () => _shift(1)),
      ],
    );
  }

  // ---------- compact summary card ----------
  Widget _summary(int percent, int present, int late, int absent, int total) {
    Widget chip(String label, int value, Color dot) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332B8FDB),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : percent / 100,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: .25),
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Text(
                  total == 0 ? '—' : '$percent%',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
                  total == 0
                      ? 'No records this month'
                      : 'This month · $total school day${total == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    chip('Present', present, _presentFg),
                    chip('Late', late, _lateFg),
                    chip('Absent', absent, _absentFg),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- overall % + streak ----------
  Widget _miniStats(int overall, int streak) {
    Widget box(IconData icon, Color color, String value, String label) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParentColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: ParentColors.dark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: ParentColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        box(Icons.insights_rounded, ParentColors.primary, '$overall%',
            'Overall attendance'),
        const SizedBox(width: 8),
        box(Icons.local_fire_department_rounded, ParentColors.gold,
            '$streak day${streak == 1 ? '' : 's'}', 'Attendance streak'),
      ],
    );
  }

  // ---------- low attendance warning ----------
  Widget _lowBanner(int percent) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _absentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C2BC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: _absentFg),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Attendance this month is $percent%, below the $_lowLimit% '
                  'expected. Regular attendance helps your child learn better.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A2F20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- month calendar ----------
  /// त्या दिवशी लागू असलेली (declined नसलेली) रजा, नसेल तर null.
  LeaveRequest? _leaveOn(AppState s, DateTime day) {
    for (final l in s.leaves) {
      if (l.isDeclined) continue;
      final f = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
      final t = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
      if (!day.isBefore(f) && !day.isAfter(t)) return l;
    }
    return null;
  }

  Widget _calendar(AppState s, Map<int, AttendanceDay> byDay) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday पासून सुरू
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    final slots = <int?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (slots.length % 7 != 0) {
      slots.add(null);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParentColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _wdLetter[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: i >= 5
                            ? const Color(0xFF9DB6CA)
                            : ParentColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < slots.length; r += 7)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: _dayCell(slots[r + c], s, byDay, today),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
      int? day, AppState s, Map<int, AttendanceDay> byDay, DateTime today) {
    if (day == null) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }
    final date = DateTime(_month.year, _month.month, day);
    final rec = byDay[day];
    final leave = rec == null ? _leaveOn(s, date) : null;
    final weekend = date.weekday >= 6;
    final isToday = date == today;
    final future = date.isAfter(today);

    var bg = Colors.transparent;
    var fg = ParentColors.dark;
    Border? border;
    if (rec != null) {
      bg = _fg(rec.status);
      fg = Colors.white;
    } else if (leave != null) {
      bg = ParentColors.tintStrong;
      fg = ParentColors.primary;
    } else if (weekend) {
      fg = const Color(0xFF9DB6CA);
    } else if (future) {
      fg = const Color(0xFFB8C9D8);
    } else {
      border = Border.all(color: ParentColors.border);
    }
    if (isToday) border = Border.all(color: ParentColors.dark, width: 1.8);

    final cell = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: border,
      ),
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );

    final tappable = rec != null || leave != null;
    return AspectRatio(
      aspectRatio: 1,
      child: tappable
          ? GestureDetector(
        onTap: () => _openDay(date, rec, leave),
        behavior: HitTestBehavior.opaque,
        child: cell,
      )
          : cell,
    );
  }

  Widget _legend() {
    Widget item(Color color, String text, {bool outline = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: outline
                ? Border.all(color: ParentColors.dark, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ParentColors.muted,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(_presentFg, 'Present'),
          item(_lateFg, 'Late'),
          item(_absentFg, 'Absent'),
          item(ParentColors.tintStrong, 'Leave'),
          item(Colors.transparent, 'Today', outline: true),
        ],
      ),
    );
  }

  // ---------- day details (bottom sheet) ----------
  void _openDay(DateTime date, AttendanceDay? rec, LeaveRequest? leave) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ParentColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${_wd[date.weekday - 1]}, ${AppState.shortDate(date)} ${date.year}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              if (rec != null) ...[
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: _bg(rec.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon(rec.status), size: 16, color: _fg(rec.status)),
                      const SizedBox(width: 6),
                      Text(
                        _label(rec.status),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _fg(rec.status),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  rec.reason.trim().isEmpty
                      ? 'No note from the teacher.'
                      : rec.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: ParentColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (leave != null) ...[
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ParentColors.tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.event_busy_rounded,
                          size: 17, color: ParentColors.primary),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave · ${leave.isApproved ? 'Approved' : 'Pending'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: ParentColors.dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              leave.reason,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: ParentColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- section title ----------
  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: ParentColors.dark,
      ),
    ),
  );

  // ---------- filter chips ----------
  Widget _filters(int all, int present, int late, int absent) {
    Widget chip(String label, int count, String? value) {
      final on = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? ParentColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: on ? ParentColors.primary : ParentColors.border,
              ),
            ),
            child: Text(
              '$label · $count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : ParentColors.dark,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', all, null),
          chip('Present', present, 'P'),
          chip('Late', late, 'L'),
          chip('Absent', absent, 'A'),
        ],
      ),
    );
  }

  // ---------- leave applications of this month ----------
  List<Widget> _leaveSection(AppState s) {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 0);
    final items = s.leaves.where((l) {
      if (l.isDeclined) return false;
      final f = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
      final t = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
      return !f.isAfter(end) && !t.isBefore(start);
    }).toList();
    if (items.isEmpty) return const [];

    return [
      _title('Leave this month'),
      for (final l in items)
        Container(
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: l.isApproved ? _presentBg : _lateBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  l.isApproved
                      ? Icons.event_available_rounded
                      : Icons.hourglass_top_rounded,
                  size: 17,
                  color: l.isApproved ? _presentFg : _lateFg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppState.shortDate(l.fromDate)}'
                          '${l.days > 1 ? ' – ${AppState.shortDate(l.toDate)}' : ''}'
                          ' · ${l.days} day${l.days == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ParentColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l.isApproved ? 'Approved' : 'Pending',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: l.isApproved ? _presentFg : _lateFg,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
    ];
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

  // ---------- apply for leave shortcut ----------
  Widget _applyLeave(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ParentLeaveScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ParentColors.tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParentColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 17, color: ParentColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apply for leave',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ParentColors.dark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Child will be absent? Let the teacher know in advance.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: ParentColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: ParentColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        const Icon(Icons.event_available_rounded,
            size: 38, color: Color(0xFF9DB6CA)),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: ParentColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}